const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    const screenWidth: c_int = 640;
    const screenHeight: c_int = 480;

    raylib.InitWindow(screenWidth, screenHeight, "raylib example window");
    defer raylib.CloseWindow();

    raylib.SetTargetFPS(60);

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.RAYWHITE);
        raylib.DrawText("Hello world", 190, 200, 20, raylib.LIGHTGRAY);
    }
}
