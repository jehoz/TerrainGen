const std = @import("std");

const vectors = @import("vectors.zig");
const Vector2 = vectors.Vector2;
const Vector3 = vectors.Vector3;

pub const ScalarField = Field(f32);
pub const Vector2Field = Field(Vector2);
pub const Vector3Field = Field(Vector3);

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

            switch (T) {
                f32 => {
                    return nw * (1 - pt.offset.x) * (1 - pt.offset.y) +
                        ne * pt.offset.x * (1 - pt.offset.y) +
                        sw * (1 - pt.offset.x) * pt.offset.y +
                        se * pt.offset.x * pt.offset.y;
                },
                Vector2, Vector3 => {
                    const nw_part = nw.scale((1 - pt.offset.x) * (1 - pt.offset.y));
                    const ne_part = sw.scale(pt.offset.x * (1 - pt.offset.y));
                    const sw_part = ne.scale((1 - pt.offset.x) * pt.offset.y);
                    const se_part = ne.scale(pt.offset.x * pt.offset.y);
                    return nw_part.add(ne_part).add(sw_part).add(se_part);
                },
                else => {
                    @compileError("`get` not implemented for fields of type " ++ @typeName(T));
                },
            }
        }

        pub fn gradient(self: Self, pos: Vector2) Vector2 {
            const pt = FieldPoint.init(self, pos);

            const nw = self.getCell(pt.x0, pt.y0);
            const ne = self.getCell(pt.x1, pt.y0);
            const sw = self.getCell(pt.x0, pt.y1);
            const se = self.getCell(pt.x1, pt.y1);

            switch (T) {
                f32 => {
                    return .{
                        .x = (ne - nw) * (1 - pt.offset.y) + (se - sw) * pt.offset.y,
                        .y = (sw - nw) * (1 - pt.offset.x) + (se - ne) * pt.offset.x,
                    };
                },
                else => {
                    @compileError("`gradient` not implemented for fields of type " ++ @typeName(T));
                },
            }
        }

        pub fn modify(self: *Self, pos: Vector2, delta: T) void {
            const pt = FieldPoint.init(self.*, pos);

            const nw = self.getCell(pt.x0, pt.y0);
            const ne = self.getCell(pt.x1, pt.y0);
            const sw = self.getCell(pt.x0, pt.y1);
            const se = self.getCell(pt.x1, pt.y1);

            switch (T) {
                f32 => {
                    self.setCell(pt.x0, pt.y0, nw + delta * (1 - pt.offset.x) * (1 - pt.offset.y));
                    self.setCell(pt.x1, pt.y0, ne + delta * pt.offset.x * (1 - pt.offset.y));
                    self.setCell(pt.x0, pt.y1, sw + delta * (1 - pt.offset.x) * pt.offset.y);
                    self.setCell(pt.x1, pt.y1, se + delta * pt.offset.x * pt.offset.y);
                },
                Vector2, Vector3 => {
                    const nw_part = delta.scale((1 - pt.offset.x) * (1 - pt.offset.y));
                    const ne_part = delta.scale(pt.offset.x * (1 - pt.offset.y));
                    const sw_part = delta.scale((1 - pt.offset.x) * pt.offset.y);
                    const se_part = delta.scale(pt.offset.x * pt.offset.y);
                    self.setCell(pt.x0, pt.y0, nw.add(nw_part));
                    self.setCell(pt.x1, pt.y0, ne.add(ne_part));
                    self.setCell(pt.x0, pt.y1, sw.add(sw_part));
                    self.setCell(pt.x1, pt.y1, se.add(se_part));
                },
                else => {
                    @compileError("`modify` not implemented for fields of type " ++ @typeName(T));
                },
            }
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
