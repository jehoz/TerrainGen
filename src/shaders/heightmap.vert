#version 330

in vec3 v_position;
in vec2 v_UV;
in vec3 v_normal;
in vec4 v_color;

uniform mat4 mvp;
uniform sampler2D texture0;

out vec2 f_UV;
out vec4 f_color;

void main()
{
    f_UV = v_UV;

    float height = texture(texture0, v_UV).x;
    f_color = vec4(height, height, height, 1.0);

    gl_Position = mvp * vec4(v_position.x, height * 4, v_position.z, 1.0);
}
