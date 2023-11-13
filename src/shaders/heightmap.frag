#version 330

in vec2 f_UV;
in vec3 normal;

uniform sampler2D texture0;

out vec4 color;

void main()
{
    vec4 tex_color = texture(texture0, f_UV);
    // float flatness = dot(normal, vec3(0, 1, 0));

    color = vec4(tex_color.r * normal, 1.0);
}
