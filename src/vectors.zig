const std = @import("std");

pub const Vector2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    /// Add two vectors (self + v)
    pub fn add(self: Vector2, v: Vector2) Vector2 {
        return .{
            .x = self.x + v.x,
            .y = self.y + v.y,
        };
    }

    /// Subtract two vectors (self - v)
    pub fn subtract(self: Vector2, v: Vector2) Vector2 {
        return .{
            .x = self.x - v.x,
            .y = self.y - v.y,
        };
    }

    /// Scale a vector (multiply each dimention by a scalar)
    pub fn scale(self: Vector2, mag: f32) Vector2 {
        return .{
            .x = self.x * mag,
            .y = self.y * mag,
        };
    }

    /// Calculate the length of a vector
    pub fn length(self: Vector2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    /// Normalize a vector (scale to a length of 1)
    /// Zero-vectors are unaffected.
    pub fn normalize(self: Vector2) Vector2 {
        const len = self.length();
        if (len <= 0) {
            return self;
        } else {
            return self.scale(1 / len);
        }
    }
};
