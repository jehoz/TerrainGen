const std = @import("std");
const Vector2 = @import("vectors.zig").Vector2;

pub const ScalarField = Field(f32);

fn Field(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []T,
        width: usize,
        height: usize,
        allocator: std.mem.Allocator,

        pub fn init(width: usize, height: usize, allocator: std.mem.Allocator) !Self {
            return .{
                .width = width,
                .height = height,
                .data = try allocator.alloc(T, width * height),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }

        fn index(self: Self, x: usize, y: usize) usize {
            std.debug.assert(x < self.width);
            std.debug.assert(y < self.height);
            return y * self.width + x;
        }

        pub fn getCell(self: Self, x: usize, y: usize) T {
            const i = self.index(x, y);
            return self.data[i];
        }

        pub fn setCell(self: Self, x: usize, y: usize, val: T) void {
            const i = self.index(x, y);
            self.data[i] = val;
        }

        pub fn get(self: Self, pos: Vector2) T {
            const pt = FieldPoint.init(self, pos);

            const nw = self.getCell(pt.x0, pt.y0);
            const ne = self.getCell(pt.x1, pt.y0);
            const sw = self.getCell(pt.x0, pt.y1);
            const se = self.getCell(pt.x1, pt.y1);

            return nw * (1 - pt.offset.x) * (1 - pt.offset.y) +
                ne * pt.offset.x * (1 - pt.offset.y) +
                sw * (1 - pt.offset.x) * pt.offset.y +
                se * pt.offset.x * pt.offset.y;
        }

        pub fn gradient(self: Self, pos: Vector2) Vector2 {
            const pt = FieldPoint.init(self, pos);

            const nw = self.getCell(pt.x0, pt.y0);
            const ne = self.getCell(pt.x1, pt.y0);
            const sw = self.getCell(pt.x0, pt.y1);
            const se = self.getCell(pt.x1, pt.y1);

            return .{
                .x = (ne - nw) * (1 - pt.offset.y) + (se - sw) * pt.offset.y,
                .y = (sw - nw) * (1 - pt.offset.x) + (se - ne) * pt.offset.x,
            };
        }

        pub fn modify(self: *Self, pos: Vector2, delta: T) void {
            const pt = FieldPoint.init(self.*, pos);

            const nw = self.getCell(pt.x0, pt.y0);
            const ne = self.getCell(pt.x1, pt.y0);
            const sw = self.getCell(pt.x0, pt.y1);
            const se = self.getCell(pt.x1, pt.y1);

            self.setCell(pt.x0, pt.y0, nw + delta * (1 - pt.offset.x) * (1 - pt.offset.y));
            self.setCell(pt.x1, pt.y0, ne + delta * pt.offset.x * (1 - pt.offset.y));
            self.setCell(pt.x0, pt.y1, sw + delta * (1 - pt.offset.x) * pt.offset.y);
            self.setCell(pt.x1, pt.y1, se + delta * pt.offset.x * pt.offset.y);
        }

        const FieldPoint = struct {
            y0: usize,
            y1: usize,
            x0: usize,
            x1: usize,
            offset: Vector2,

            pub fn init(grid: Self, pos: Vector2) @This() {
                const modf_x = std.math.modf(pos.x);
                const modf_y = std.math.modf(pos.y);

                const y0: usize = @intFromFloat(modf_y.ipart);
                const y1: usize = if (y0 + 1 < grid.height) y0 + 1 else y0;
                const x0: usize = @intFromFloat(modf_x.ipart);
                const x1: usize = if (x0 + 1 < grid.width) x0 + 1 else x0;

                return .{
                    .y0 = y0,
                    .y1 = y1,
                    .x0 = x0,
                    .x1 = x1,
                    .offset = .{ .x = modf_x.fpart, .y = modf_y.fpart },
                };
            }
        };
    };
}
