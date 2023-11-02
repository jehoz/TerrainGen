const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

pub fn main() !void {
    const screenWidth: c_int = 800;
    const screenHeight: c_int = 600;

    rl.InitWindow(screenWidth, screenHeight, "raylib example window");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    // Set up 3D camera
    var camera: rl.Camera = .{
        .position = .{ .x = 18.0, .y = 21.0, .z = 18.0 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1.0, .z = 0 },
        .fovy = 45.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    // generate heightmap, load to GPU and generate mesh
    const heightmap = genHeightmap(128, 128);
    defer rl.UnloadImage(heightmap);

    const heightmap_tex = rl.LoadTextureFromImage(heightmap);
    defer rl.UnloadTexture(heightmap_tex);

    const mesh = rl.GenMeshHeightmap(heightmap, .{ .x = 16, .y = 8, .z = 16 });

    var model = rl.LoadModelFromMesh(mesh);
    defer rl.UnloadModel(model);

    model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = heightmap_tex;
    const map_pos: rl.Vector3 = .{ .x = -8.0, .y = 0, .z = -8.0 };

    while (!rl.WindowShouldClose()) {
        rl.UpdateCamera(&camera, rl.CAMERA_ORBITAL);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode3D(camera);
        defer rl.EndMode3D();

        rl.DrawModel(model, map_pos, 1.0, rl.RED);
        rl.DrawGrid(20, 1.0);
    }
}

fn genHeightmap(width: c_int, height: c_int) rl.Image {
    var noise = fnl.fnlCreateState();
    noise.noise_type = fnl.FNL_NOISE_OPENSIMPLEX2;
    noise.fractal_type = fnl.FNL_FRACTAL_RIDGED;

    var heightmap: rl.Image = rl.GenImageColor(width, height, rl.BLACK);

    for (0..@intCast(height)) |y| {
        for (0..@intCast(width)) |x| {
            var x_f: f32 = @floatFromInt(x);
            var y_f: f32 = @floatFromInt(y);
            var noise_val = fnl.fnlGetNoise2D(&noise, x_f, y_f);
            noise_val = (noise_val + 1) / 2; // remap range from [-1,1] to [0,1]
            var z: u8 = @intFromFloat(noise_val * 255);
            rl.ImageDrawPixel(&heightmap, @intCast(x), @intCast(y), rl.Color{ .r = z, .g = z, .b = z, .a = 255 });
        }
    }

    return heightmap;
}
