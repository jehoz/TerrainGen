#version 330

in vec2 f_UV;
in vec3 f_position;
in vec3 f_normal;

uniform sampler2D texture0;
uniform sampler2D texture1;

out vec4 color;

vec3 BEDROCK_COLOR = vec3(0.43, 0.43, 0.43);
vec3 SEDIMENT_COLOR = vec3(0.64, 0.50, 0.40);
vec3 FOLIAGE_COLOR = vec3(0.1, 0.35, 0.0);

vec3 LIGHT_POSITION = vec3(0, 100, 0);
vec4 LIGHT_COLOR = vec4(1, 1, 1, 1);

vec4 ambient = vec4(0.5, 0.5, 0.5, 1);

float decodeTexVal(sampler2D tex, vec2 uv) {
    const float u24_max = pow(2.0, 24.0) - 1.0;
    vec3 val = texture(tex, uv).rgb;
    float result = 255.0 * dot(val, vec3(65536.0, 256.0, 1.0)) / u24_max;
    return result;
}

void main()
{
    float height = decodeTexVal(texture0, f_UV);
    float wetness = decodeTexVal(texture1, f_UV);

    vec4 terrainColor = vec4(
        mix(BEDROCK_COLOR, mix(SEDIMENT_COLOR, FOLIAGE_COLOR, wetness), 
        smoothstep(0.7, 0.9, f_normal.y)
        ), 1);

    vec3 light = normalize(LIGHT_POSITION - f_position);
    float litAmt = max(dot(f_normal, light), 0.0);

    color = terrainColor * vec4(LIGHT_COLOR.rgb * litAmt, 1.0);
    color += terrainColor * (ambient / 10.0);
    color = pow(color, vec4(1.0/2.2));
}
