const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const rm = @cImport({
    @cInclude("raymath.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

const Terrain = @import("terrain.zig").Terrain;

pub fn main() !void {
    const screen_width: c_int = 800;
    const screen_height: c_int = 600;

    rl.InitWindow(screen_width, screen_height, "Terrain Generator");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    var camera: rl.Camera = .{
        .position = .{ .x = 20, .y = 30, .z = 20 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 30,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var scene = try TerrainScene.init(256, 256, allocator);
    defer scene.deinit();

    rl.SetTraceLogLevel(rl.LOG_WARNING);
    var frame: u32 = 0;
    while (!rl.WindowShouldClose()) {
        rl.UpdateCamera(&camera, rl.CAMERA_THIRD_PERSON);
        scene.update();

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);
        scene.render();
        rl.EndMode3D();

        // const fpath = try std.fmt.allocPrintZ(allocator, "screenshots/{d}.png", .{frame});
        // rl.TakeScreenshot(fpath.ptr);

        rl.DrawText(
            rl.TextFormat("Erosion Iterations: %d", scene.terrain.erosion_iters),
            20,
            20,
            20,
            rl.LIGHTGRAY,
        );
        rl.DrawFPS(20, 40);
        frame += 1;
    }
}

const TerrainScene = struct {
    terrain: *Terrain,

    heightmap_texture: rl.Texture,
    wetmap_texture: rl.Texture,

    model: rl.Model,
    instance_transforms: []rm.Matrix,
    shader: rl.Shader,

    allocator: std.mem.Allocator,

    pub fn init(
        width: usize,
        height: usize,
        allocator: std.mem.Allocator,
    ) !TerrainScene {
        var noise = fnl.fnlCreateState();
        noise.noise_type = fnl.FNL_NOISE_OPENSIMPLEX2S;
        noise.fractal_type = fnl.FNL_FRACTAL_RIDGED;
        noise.gain = 0.5;
        noise.octaves = 6;
        noise.frequency = 0.0075 / (@as(f32, @floatFromInt(width)) / 128);

        var terrain = try allocator.create(Terrain);
        terrain.* = try Terrain.init(
            width,
            height,
            &noise,
            allocator,
        );

        var heightmap =
            rl.GenImageColor(@intCast(width), @intCast(height), rl.BLACK);
        defer rl.UnloadImage(heightmap);

        const wetmap =
            rl.GenImageColor(@intCast(width), @intCast(height), rl.BLACK);
        defer rl.UnloadImage(wetmap);

        var heightmap_tex = rl.LoadTextureFromImage(heightmap);
        var wetmap_tex = rl.LoadTextureFromImage(wetmap);
        // generating the mesh this way because GenMeshPlane adds weird extra
        // geometry... might be a bug
        var mesh = rl.GenMeshHeightmap(
            rl.GenImageColor(@intCast(width), @intCast(height), rl.BLACK),
            .{ .x = 16, .y = 0, .z = 16 },
        );
        var model = rl.LoadModelFromMesh(mesh);

        var instance_transforms: []rm.Matrix = try allocator.alloc(rm.Matrix, 32);
        for (instance_transforms, 0..) |_, i| {
            const z_offset = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(instance_transforms.len));
            instance_transforms[i] = rm.MatrixTranslate(-8, z_offset, -8);
        }
        std.debug.print("{}\n", .{instance_transforms[0]});

        var shader = rl.LoadShader(
            "src/shaders/heightmap.vert",
            "src/shaders/heightmap.frag",
        );
        shader.locs[rl.SHADER_LOC_MATRIX_MODEL] = rl.GetShaderLocationAttrib(shader, "instanceTransform");
        model.materials[0].shader = shader;
        model.materials[0].maps[0].texture = heightmap_tex;
        model.materials[0].maps[1].texture = wetmap_tex;

        var scn = .{
            .terrain = terrain,
            .heightmap_texture = heightmap_tex,
            .wetmap_texture = wetmap_tex,
            .shader = shader,
            .model = model,
            .instance_transforms = instance_transforms,
            .allocator = allocator,
        };

        var hnd = try std.Thread.spawn(
            .{ .allocator = allocator },
            Terrain.erode,
            .{ scn.terrain, .{} },
        );
        hnd.detach();

        return scn;
    }

    pub fn deinit(self: *TerrainScene) void {
        std.debug.print("Unloading terrain\n", .{});
        self.terrain.deinit();
        self.allocator.destroy(self.terrain);
        std.debug.print("Unloading model\n", .{});
        rl.UnloadModel(self.model);
        std.debug.print("Unloading shader\n", .{});
        rl.UnloadShader(self.shader);
        std.debug.print("Unloading textures\n", .{});
        rl.UnloadTexture(self.heightmap_texture);
        rl.UnloadTexture(self.wetmap_texture);
    }

    pub fn update(self: *TerrainScene) void {
        const width = self.heightmap_texture.width;
        const height = self.heightmap_texture.height;

        var heightmap = rl.GenImageColor(width, height, rl.BLACK);
        defer rl.UnloadImage(heightmap);
        var wetmap = rl.GenImageColor(width, height, rl.BLACK);
        defer rl.UnloadImage(wetmap);

        for (0..@intCast(height)) |y| {
            for (0..@intCast(width)) |x| {
                // encode the values in all three channels of an RGB pixel so
                // that we get 2^24 discrete values instead of only 256
                const elev = self.terrain.elevation.getCell(x, y);
                const z: u32 = @intFromFloat(std.math.clamp(elev, 0, 1) * 0xFFFFFF);
                const e_col = rl.Color{
                    .r = @truncate(z >> 16),
                    .g = @truncate(z >> 8),
                    .b = @truncate(z),
                    .a = 255,
                };
                rl.ImageDrawPixel(&heightmap, @intCast(x), @intCast(y), e_col);

                var moist = self.terrain.moisture.getCell(x, y);
                const m: u32 = @intFromFloat(std.math.clamp(moist, 0, 1) * 0xFFFFFF);
                const m_col = rl.Color{
                    .r = @truncate(m >> 16),
                    .g = @truncate(m >> 8),
                    .b = @truncate(m),
                    .a = 255,
                };
                rl.ImageDrawPixel(&wetmap, @intCast(x), @intCast(y), m_col);
            }
        }

        rl.UpdateTexture(self.heightmap_texture, heightmap.data);
        rl.UpdateTexture(self.wetmap_texture, wetmap.data);
    }

    pub fn render(self: *TerrainScene) void {
        // rl.DrawModel(self.model, self.model_pos, 1.0, rl.WHITE);
        // rl.DrawGrid(20, 1);
        rl.DrawMeshInstanced(
            self.model.meshes[0],
            self.model.materials[0],
            @ptrCast(self.instance_transforms),
            @intCast(self.instance_transforms.len),
        );
    }
};
