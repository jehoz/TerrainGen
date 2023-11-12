const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const rg = @cImport({
    @cInclude("raygui.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

const Terrain = @import("terrain.zig").Terrain;
const HydraulicErosion = @import("hydraulic_erosion.zig");

pub fn main() !void {
    const screen_width: c_int = 800;
    const screen_height: c_int = 600;

    rl.InitWindow(screen_width, screen_height, "Terrain Generator");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    var camera: rl.Camera = .{
        .position = .{ .x = 18, .y = 21, .z = 18 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var scene = try TerrainScene.init(256, 256, allocator);
    defer scene.deinit();

    while (!rl.WindowShouldClose()) {
        rl.UpdateCamera(&camera, rl.CAMERA_ORBITAL);
        scene.update();

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);
        scene.render();
        rl.EndMode3D();

        rl.DrawText(
            rl.TextFormat("Erosion Iterations: %d", scene.erosion_iters),
            20,
            20,
            20,
            rl.LIGHTGRAY,
        );
    }
}

const TerrainScene = struct {
    terrain: Terrain,
    erosion_iters: u32 = 0,
    max_erosion_iters: u32 = 100_000,

    texture: rl.Texture,
    model: rl.Model,
    model_pos: rl.Vector3,
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
        noise.frequency = 0.01 / (@as(f32, @floatFromInt(width)) / 128);

        var terrain = try Terrain.init(
            width,
            height,
            allocator,
        );
        terrain.fillNoise(&noise);

        const heightmap = terrain.renderElevation();
        defer rl.UnloadImage(heightmap);

        var tex = rl.LoadTextureFromImage(heightmap);
        // generating the mesh this way because GenMeshPlane adds weird extra
        // geometry... might be a bug
        var mesh = rl.GenMeshHeightmap(
            rl.GenImageColor(@intCast(width), @intCast(height), rl.BLACK),
            .{ .x = 16, .y = 1, .z = 16 },
        );
        var model = rl.LoadModelFromMesh(mesh);

        var shader = rl.LoadShader(
            "src/shaders/heightmap.vert",
            "src/shaders/heightmap.frag",
        );
        model.materials[0].shader = shader;
        model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = tex;

        return .{
            .terrain = terrain,
            .texture = tex,
            .shader = shader,
            .model = model,
            .model_pos = .{ .x = -8, .y = 0, .z = -8 },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TerrainScene) void {
        std.debug.print("Unloading terrain\n", .{});
        self.terrain.deinit();
        std.debug.print("Unloading model\n", .{});
        rl.UnloadModel(self.model);
        std.debug.print("Unloading shader\n", .{});
        rl.UnloadShader(self.shader);
        std.debug.print("Unloading texture\n", .{});
        rl.UnloadTexture(self.texture);
    }

    pub fn update(self: *TerrainScene) void {
        if (self.erosion_iters >= self.max_erosion_iters) {
            return;
        }

        HydraulicErosion.erodeTerrain(&self.terrain, .{
            .iterations = 1000,
            .inertia = 0.05,
            .erosion_rate = 0.05,
            .deposition_rate = 0.5,
            .evaporation_rate = 0.02,
            .sediment_capacity = 10,
            .gravity = 10,
        });
        self.erosion_iters += 1000;

        var heightmap = self.terrain.renderElevation();
        rl.ImageBlurGaussian(&heightmap, 1);
        defer rl.UnloadImage(heightmap);

        rl.UnloadTexture(self.texture);
        self.texture = rl.LoadTextureFromImage(heightmap);

        self.model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = self.texture;
    }

    pub fn render(self: *TerrainScene) void {
        rl.DrawModel(self.model, self.model_pos, 1.0, rl.WHITE);
        rl.DrawGrid(20, 1);
    }
};
