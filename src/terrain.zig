const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

pub const Terrain = struct {
    elevation: [][]f32,

    allocator: std.mem.Allocator,

    pub fn init(width: usize, height: usize, allocator: std.mem.Allocator) !Terrain {
        var t = Terrain{
            .elevation = undefined,
            .allocator = allocator,
        };

        t.elevation = try allocator.alloc([]f32, height);
        for (t.elevation) |*row| {
            row.* = try allocator.alloc(f32, width);
        }

        return t;
    }

    pub fn deinit(self: *Terrain) void {
        for (self.elevation) |*row| {
            self.allocator.free(row.*);
        }
        self.allocator.free(self.elevation);
        self.* = undefined;
    }

    pub fn fillNoise(self: *Terrain, noise: *fnl.fnl_state) void {
        for (self.elevation, 0..) |row, y| {
            for (row, 0..) |_, x| {
                const noise_val = fnl.fnlGetNoise2D(noise, @floatFromInt(x), @floatFromInt(y));
                // remap range from [-1, 1] to [0, 1]
                self.elevation[y][x] = (noise_val + 1) / 2;
            }
        }
    }

    pub fn renderElevation(self: Terrain) rl.Image {
        const height: c_int = @intCast(self.elevation.len);
        const width: c_int = @intCast(self.elevation.len);
        var img = rl.GenImageColor(width, height, rl.BLACK);

        for (self.elevation, 0..) |row, y| {
            for (row, 0..) |cell, x| {
                const z: u8 = @intFromFloat(cell * 255);
                const color = rl.Color{
                    .r = z,
                    .g = z,
                    .b = z,
                    .a = 255,
                };
                rl.ImageDrawPixel(&img, @intCast(x), @intCast(y), color);
            }
        }

        return img;
    }
};
