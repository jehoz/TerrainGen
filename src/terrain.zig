const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

pub const Terrain = struct {
    elevation: [][]f32,
    arena_allocator: std.heap.ArenaAllocator,

    pub fn init(width: usize, height: usize, child_allocator: std.mem.Allocator) !Terrain {
        var t = Terrain{
            .elevation = undefined,
            .arena_allocator = std.heap.ArenaAllocator.init(child_allocator),
        };

        const allocator = t.arena_allocator.allocator();

        t.elevation = try allocator.alloc([]f32, height);
        for (t.elevation) |*row| {
            row.* = try allocator.alloc(f32, width);
        }

        return t;
    }

    pub fn deinit(self: Terrain) void {
        self.arena_allocator.deinit();
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
};
