#version 330

in vec3 v_position;
in vec2 v_UV;

in mat4 instanceTransform;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

uniform sampler2D texture0; // elevation
uniform sampler2D texture1; // moisture

out vec2 f_UV;
out vec3 f_position;
out vec3 f_normal;
out float f_instanceOffset;

float decodeTexVal(sampler2D tex, vec2 uv) {
    const float u24_max = pow(2.0, 24.0) - 1.0;
    vec3 val = texture(tex, uv).rgb;
    float result = 255.0 * dot(val, vec3(65536.0, 256.0, 1.0)) / u24_max;
    return result;
}

void main()
{
    f_UV = v_UV;
    f_instanceOffset = instanceTransform[3][1];

    float height = decodeTexVal(texture0, v_UV);
    float wetness = decodeTexVal(texture1, v_UV);

    vec2 pixel_size = 1.0 / vec2(textureSize(texture0, 0));
    float L = decodeTexVal(texture0, v_UV - vec2(pixel_size.x, 0));
    float R = decodeTexVal(texture0, v_UV + vec2(pixel_size.x, 0));
    float U = decodeTexVal(texture0, v_UV - vec2(0, pixel_size.y));
    float D = decodeTexVal(texture0, v_UV + vec2(0, pixel_size.y));

    f_normal = normalize(vec3(
                (L - R),
                2.0 * pixel_size.x,
                (D - U)
                ));

    vec4 position = vec4(
        v_position.x,
        height * 4 + (f_instanceOffset * wetness * 0.5),
        v_position.z, 1.0
    );
    f_position = vec3(matModel * vec4(v_position, 1.0));

    mat4 transform = instanceTransform;
    transform[3][1] = 0;

    gl_Position = (mvp * transform) * position;
}
