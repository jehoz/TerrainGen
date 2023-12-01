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

const vec3 COLOR_FOLIAGE_0 = vec3(0.055,0.095,0.056);
const vec3 COLOR_FOLIAGE_1 = vec3(0.124,0.140,0.035);
const vec3 COLOR_FOLIAGE_2 = vec3(0.095,0.105,0.040);

const vec3 COLOR_WATER_SHALLOW = vec3(0.03,0.09,0.11) * 0.75;
const vec3 COLOR_WATER_DEEP = vec3(0.025,0.063,0.11) * 0.75;

const vec3 SUN_POSITION = vec3(12, 50, -12);
const vec3 SUN_COLOR = vec3(1.2, 1.1, 1.0) * 0.99;

const float AMBIENT_STRENGTH = 0.33;
const vec3 AMBIENT_COLOR = vec3(0.886, 0.937, 1.0);

const float WATER_THRESHOLD = 0.85;


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
    float noise512 = voronoise(vec2(f_UV) * 512, 1., 1.);

    float height = decodeTexVal(texture0, f_UV);

    // distort moisture texture a little bit to reduce pixel artifacting
    float wetness = decodeTexVal(texture1, f_UV + vec2(noise512) * 0.0075);
    bool isWater = wetness > WATER_THRESHOLD;
    float soilMoisture = smoothstep(0, WATER_THRESHOLD, wetness);
    float ambientOcclusion = 0;

    if (f_instanceOffset == 0) { // base instance (terrain)
        if (isWater) {
            color = vec4(mix(
                COLOR_WATER_SHALLOW,
                COLOR_WATER_DEEP,
                smoothstep(WATER_THRESHOLD, 1., wetness)
            ), 1.);
        } else {
            vec3 rock_color = mix(
                COLOR_ROCK_LIGHT,
                COLOR_ROCK_DARK,
                pow(wetness, 0.75)
            );
            rock_color -= voronoise(vec2(height, wetness) * 32, 1., 1.) * 0.1;

            vec3 soil_color = mix(
                mix(
                    COLOR_ROCK_DARK, 
                    COLOR_FOLIAGE_1, 
                    pow(soilMoisture, 0.125)
                ),
                mix(
                    COLOR_FOLIAGE_0,
                    mix(COLOR_FOLIAGE_2, COLOR_WATER_SHALLOW, pow(soilMoisture, 32.)),
                    pow(soilMoisture, 8.)
                ),
                soilMoisture
            );

            color = vec4(mix(
                rock_color,
                soil_color,
                smoothstep(0.1, 0.9, pow(f_normal.y, 0.75))
            ), 1.);
        }

    } else {  // shells (trees)
        if (isWater) discard;

        float noise128 = voronoise(vec2(f_UV) * 128, 1., 1.);
        float noise256 = voronoise(vec2(f_UV) * 256, 1., 1.);
        float noise1024 = voronoise(vec2(f_UV) * 1024, 1., 1.);

        float foliageHeight = mix(
            noise512 * ((noise128 + noise256 + noise1024) / 3.),
            noise1024 * ((noise128 + noise256 + noise512) / 3.),
            noise128
        );

        foliageHeight *= ((2. * wetness) / WATER_THRESHOLD) * (1. - pow(wetness / WATER_THRESHOLD, 4.));
        foliageHeight *= smoothstep(0.4, 0.7, pow(f_normal.y, 0.75));

        if (foliageHeight < f_instanceOffset) discard;

        color = vec4(mix(
            COLOR_FOLIAGE_1,
            COLOR_FOLIAGE_0,
            soilMoisture
        ), 1.);
        color = mix(color, vec4(COLOR_FOLIAGE_2, 1), noise1024 * 0.5);

        ambientOcclusion = -foliageHeight;
    }

    // Ambient
    vec3 ambient = AMBIENT_COLOR * AMBIENT_STRENGTH;

    // Diffuse
    vec3 lightDir = normalize(SUN_POSITION - f_position);
    float litAmt = max(0.0, dot(f_normal, lightDir) - ambientOcclusion);
    vec3 diffuse = SUN_COLOR * litAmt;

    // lit surface color
    color = vec4((ambient + diffuse) * color.rgb, 1.0);

    // gamma correction
    color.rgb = pow(color.rgb, vec3(1.0 / 2.2));

    // add a little contrast
    color.rgb = ((color.rgb - 0.5) * 1.3) + 0.5;
}
