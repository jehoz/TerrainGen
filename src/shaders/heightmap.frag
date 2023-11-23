#version 330

in vec2 f_UV;
in vec3 f_position;
in vec3 f_normal;
in float f_instanceOffset;

uniform sampler2D texture0; // elevation
uniform sampler2D texture1; // moisture

out vec4 color;

vec3 LIGHT_ROCK_COLOR = vec3(0.43, 0.43, 0.43);
vec3 DARK_ROCK_COLOR = vec3(0.247,0.133,0.059);
vec3 SAND_COLOR = vec3(0.54, 0.40, 0.30);
vec3 GRASS_COLOR = vec3(0.1, 0.25, 0.0);
vec3 TREE_COLOR = vec3(0.33, 0.49, 0.12);

vec3 LIGHT_POSITION = vec3(0, 100, 0);
vec4 LIGHT_COLOR = vec4(1., 1., 1., 1.);

vec4 ambient = vec4(0.5, 0.5, 0.5, 1);


float decodeTexVal(sampler2D tex, vec2 uv) {
    const float u24_max = pow(2.0, 24.0) - 1.0;
    vec3 val = texture(tex, uv).rgb;
    float result = 255.0 * dot(val, vec3(65536.0, 256.0, 1.0)) / u24_max;
    return result;
}

// Voronoise implementation shamelessly stolen from Inigo Quilez
vec3 hash3( vec2 p )
{
    vec3 q = vec3( dot(p,vec2(127.1,311.7)), 
				   dot(p,vec2(269.5,183.3)), 
				   dot(p,vec2(419.2,371.9)) );
	return fract(sin(q)*43758.5453);
}

float voronoise( in vec2 p, float u, float v )
{
	float k = 1.0+63.0*pow(1.0-v,6.0);

    vec2 i = floor(p);
    vec2 f = fract(p);
    
	vec2 a = vec2(0.0,0.0);
    for( int y=-2; y<=2; y++ )
    for( int x=-2; x<=2; x++ )
    {
        vec2  g = vec2( x, y );
		vec3  o = hash3( i + g )*vec3(u,u,1.0);
		vec2  d = g - f + o.xy;
		float w = pow( 1.0-smoothstep(0.0,1.414,length(d)), k );
		a += vec2(o.z*w,w);
    }
	
    return a.x/a.y;
}

void main()
{
    float height = decodeTexVal(texture0, f_UV);
    float wetness = decodeTexVal(texture1, f_UV);

    float noise512 = voronoise(vec2(f_UV) * 512, 1., 1.);

    if (f_instanceOffset == 0) { // base instance (terrain)  {
        vec3 rock_color = mix(
            LIGHT_ROCK_COLOR,
            mix(LIGHT_ROCK_COLOR, DARK_ROCK_COLOR, noise512),
            (wetness / 2) + 0.5
        );

        vec3 soil_color = mix(
            SAND_COLOR,
            mix(GRASS_COLOR, GRASS_COLOR * 0.5, noise512),
            wetness
        );

        vec4 terrainColor = vec4(
            mix(rock_color,
                soil_color,
            smoothstep(0.6, 0.9, f_normal.y)
            ), 1);

        vec3 lightDir = normalize(LIGHT_POSITION - f_position);
        float litAmt = max(0, dot(f_normal, lightDir));

        color = terrainColor * vec4(LIGHT_COLOR.rgb * litAmt, 1.0);
        // color += terrainColor * (ambient / 10.0);
        color = pow(color, vec4(1.0 / 2.2));

    } else {  // shells (trees)
         if (wetness > 0.75) discard;

         float treeDist = noise512;
         if (wetness < 0.50) {
             treeDist *= voronoise(f_UV * 128, 1., 1.);
         }

         if (treeDist * wetness * (f_normal.y + 0.1) < f_instanceOffset) {
             discard;
         }

         color = mix(
            vec4(GRASS_COLOR, 1),
            vec4(TREE_COLOR, 1),
            voronoise(f_UV * 256, 1., 1.)
        );

         color *= pow(f_instanceOffset, 0.5);
     }

}
