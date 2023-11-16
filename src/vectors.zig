const std = @import("std");

pub const Vector2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub usingnamespace VecOps(Vector2);
};

pub const Vector3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub usingnamespace VecOps(Vector3);
};

fn VecOps(comptime T: type) type {
    const fields = @typeInfo(T).Struct.fields;
    return struct {
        pub inline fn add(self: T, v: T) T {
            var out: T = undefined;
            inline for (fields) |f| {
                @field(out, f.name) = @field(self, f.name) + @field(v, f.name);
            }
            return out;
        }

        pub inline fn subtract(self: T, v: T) T {
            var out: T = undefined;
            inline for (fields) |f| {
                @field(out, f.name) = @field(self, f.name) - @field(v, f.name);
            }
            return out;
        }

        pub inline fn scale(self: T, mag: f32) T {
            var out: T = undefined;
            inline for (fields) |f| {
                @field(out, f.name) = @field(self, f.name) * mag;
            }
            return out;
        }

        pub inline fn lengthSq(self: T) f32 {
            var sum: f32 = 0;
            inline for (fields) |f| {
                sum += @field(self, f.name) * @field(self, f.name);
            }
            return sum;
        }

        pub inline fn length(self: T) f32 {
            return @sqrt(self.lengthSq());
        }

        pub inline fn normalize(self: T) T {
            const len = self.length();

            if (len <= 0) {
                return self;
            } else {
                return self.scale(1 / len);
            }
        }
    };
}

test "Vec2 operations" {
    const u: Vector2 = .{ .x = 7.5, .y = 6.5 };
    const v: Vector2 = .{ .x = 12.5, .y = 33.5 };

    // addition
    try std.testing.expect(u.add(v).x == u.x + v.x);
    try std.testing.expect(u.add(v).y == u.y + v.y);

    // subtraction
    try std.testing.expect(u.subtract(v).x == u.x - v.x);
    try std.testing.expect(u.subtract(v).y == u.y - v.y);

    // scaling
    try std.testing.expect(u.scale(2).x == u.x * 2);
    try std.testing.expect(u.scale(2).y == u.y * 2);

    // length
    try std.testing.expect(u.length() == @sqrt(u.x * u.x + u.y * u.y));

    // normalize
    const norm_len = u.normalize().length();
    try std.testing.expect(norm_len > 0.99 and norm_len < 1.01);
}
