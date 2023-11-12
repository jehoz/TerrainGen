#version 330

in vec2 f_UV;
in vec4 f_color;

uniform sampler2D texture0;

out vec4 color;

void main()
{
    vec4 tex_color = texture(texture0, f_UV);

    vec2 pixel_size = 1.0 / vec2(textureSize(texture0, 0));
    float L = texture(texture0, f_UV - vec2(pixel_size.x, 0)).r;
    float R = texture(texture0, f_UV + vec2(pixel_size.x, 0)).r;
    float U = texture(texture0, f_UV - vec2(0, pixel_size.y)).r;
    float D = texture(texture0, f_UV + vec2(0, pixel_size.y)).r;

    vec3 normal = normalize(vec3(
                (L - R),
                2.0 * pixel_size.x,
                (D - U)
                ));

    // float flatness = dot(normal, vec3(0, 1, 0));
    // color = vec4(tex_color.r, flatness, tex_color.r, tex_color.a);

    color = vec4(tex_color.r * normal, 1.0);
}
