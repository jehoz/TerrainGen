#version 330

in vec3 v_position;
in vec2 v_UV;

uniform mat4 mvp;
uniform sampler2D texture0;

out vec2 f_UV;
out vec3 normal;

void main()
{
    f_UV = v_UV;

    float height = texture(texture0, v_UV).x;

    vec2 pixel_size = 1.0 / vec2(textureSize(texture0, 0));
    float L = texture(texture0, v_UV - vec2(pixel_size.x, 0)).r;
    float R = texture(texture0, v_UV + vec2(pixel_size.x, 0)).r;
    float U = texture(texture0, v_UV - vec2(0, pixel_size.y)).r;
    float D = texture(texture0, v_UV + vec2(0, pixel_size.y)).r;

    normal = normalize(vec3(
                (L - R),
                2.0 * pixel_size.x,
                (D - U)
                ));

    gl_Position = mvp * vec4(v_position.x, height * 4, v_position.z, 1.0);
}
