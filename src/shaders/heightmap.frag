#version 330

in vec2 f_UV;
in vec3 f_position;
in vec3 f_normal;
in float f_instanceOffset;

uniform sampler2D texture0; // elevation
uniform sampler2D texture1; // moisture

out vec4 color;

const vec3 COLOR_ROCK_LIGHT = vec3(0.230,0.230,0.230);
const vec3 COLOR_ROCK_DARK = vec3(0.125,0.125,0.125);

const vec3 COLOR_GRASS_LIGHT = vec3(0.190,0.259,0.106);
const vec3 COLOR_GRASS_DARK = vec3(0.120,0.215,0.030);
const vec3 COLOR_MUD = vec3(0.125,0.089,0.079);

const vec3 COLOR_FOLIAGE_0 = vec3(0.065,0.170,0.044);
const vec3 COLOR_FOLIAGE_1 = vec3(0.206,0.245,0.068);

const vec3 COLOR_WATER_SHALLOW = vec3(0.073,0.202,0.300);
const vec3 COLOR_WATER_DEEP = vec3(0.040,0.068,0.210);

const vec3 SUN_POSITION = vec3(25, 50, 50);
const vec3 SUN_COLOR = vec3(1.2, 1.1, 1.0) * 0.67;

const float AMBIENT_STRENGTH = 0.33;
const vec3 AMBIENT_COLOR = vec3(0.886, 0.937, 1.0);

const float WATER_THRESHOLD = 0.75;


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
    float noise256 = voronoise(vec2(f_UV) * 256, 1., 1.);
    float noise512 = voronoise(vec2(f_UV) * 512, 1., 1.);

    float height = decodeTexVal(texture0, f_UV);

    // distort moisture texture a little bit to reduce pixel artifacting
    float wetness = decodeTexVal(texture1, f_UV + vec2(noise512) * 0.0075);
    bool isWater = wetness > WATER_THRESHOLD;

    if (f_instanceOffset == 0) { // base instance (terrain)
        vec3 terrainColor = vec3(0);
        if (isWater) {
            terrainColor = mix(
                COLOR_WATER_SHALLOW,
                COLOR_WATER_DEEP,
                pow(smoothstep(WATER_THRESHOLD, 1., wetness), 0.75)
            );
        } else {
            vec3 rock_color = mix(
                COLOR_ROCK_LIGHT,
                COLOR_ROCK_DARK,
                pow(wetness, 0.75)
            );
            rock_color -= voronoise(vec2(height, wetness) * 32, 1., 1.) * 0.1;

            float soilMoisture = smoothstep(0, WATER_THRESHOLD, wetness);
            vec3 soil_color = mix(
                mix(COLOR_GRASS_LIGHT, COLOR_GRASS_DARK, soilMoisture / 0.5),
                mix(COLOR_MUD, COLOR_WATER_SHALLOW, pow(soilMoisture, 32.)),
                soilMoisture
            );

            terrainColor = mix(
                rock_color,
                soil_color,
                smoothstep(0.6, 0.9, f_normal.y)
            );
        }

        // Ambient
        vec3 ambient = AMBIENT_COLOR * AMBIENT_STRENGTH;

        // Diffuse
        vec3 lightDir = normalize(SUN_POSITION - f_position);
        float litAmt = max(0.0, dot(f_normal, lightDir));
        vec3 diffuse = SUN_COLOR * litAmt;

        color = vec4((ambient + diffuse) * terrainColor, 1.0);

    } else {  // shells (trees)
        // discard;
        if (isWater) discard;

        float treeDist = noise512;
        if (wetness < 0.50) {
            treeDist *= voronoise(f_UV * 128, 1., 1.);
        }

        if (treeDist * wetness * (f_normal.y + 0.1) < f_instanceOffset) {
            discard;
        }

        color = mix(
           vec4(COLOR_FOLIAGE_0, 1),
           vec4(COLOR_FOLIAGE_1, 1),
           voronoise(f_UV * 256, 1., 1.)
        );
        color *= pow(f_instanceOffset, 0.5);
    }

    // gamma correction
    color = pow(color, vec4(1.0 / 2.2));
}
