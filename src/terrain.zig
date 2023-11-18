const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

const vectors = @import("vectors.zig");
const Vector2 = vectors.Vector2;

const fields = @import("fields.zig");
const ScalarField = fields.ScalarField;

pub const Terrain = struct {
    elevation: ScalarField,
    moisture: ScalarField,
    width: usize,
    height: usize,
    erosion_iters: i32 = 0,

    allocator: std.mem.Allocator,

    pub fn init(
        width: usize,
        height: usize,
        noise: *fnl.fnl_state,
        allocator: std.mem.Allocator,
    ) !Terrain {
        var t = .{
            .elevation = try ScalarField.init(width, height, allocator),
            .moisture = try ScalarField.init(width, height, allocator),
            .width = width,
            .height = height,
            .allocator = allocator,
        };

        for (0..height) |y| {
            for (0..width) |x| {
                const noise_val = fnl.fnlGetNoise2D(
                    noise,
                    @floatFromInt(x),
                    @floatFromInt(y),
                );
                // remap range from [-1, 1] to [0, 1]
                t.elevation.setCell(x, y, (noise_val + 1) / 2);
            }
        }
        @memset(t.moisture.data, 0);

        return t;
    }

    pub fn deinit(self: *Terrain) void {
        self.elevation.deinit();
        self.moisture.deinit();
        self.* = undefined;
    }

    pub fn erode(self: *Terrain, opts: ErosionOptions) void {
        var prng = std.rand.DefaultPrng.init(0);
        var random = prng.random();

        // cache the float version of these because type conversions are super clunky
        const width_f = @as(f32, @floatFromInt(self.width));
        const height_f = @as(f32, @floatFromInt(self.height));

        for (0..@intCast(opts.iterations)) |_| {
            var drop = WaterParticle.init(.{
                .x = random.float(f32) * width_f,
                .y = random.float(f32) * height_f,
            });

            while (drop.volume > opts.min_volume) {
                const initial_position = drop.position;
                const initial_speed = drop.velocity.length();

                const gradient = self.elevation.gradient(drop.position);
                drop.velocity = drop.velocity.scale(1 - opts.friction)
                    .subtract(gradient.scale(opts.gravity * drop.volume));

                drop.position = drop.position.add(drop.velocity.normalize());

                if (drop.position.x < 0 or drop.position.x >= width_f or
                    drop.position.y < 0 or drop.position.y >= height_f)
                {
                    break;
                }

                self.moisture.modify(
                    drop.position,
                    @max(0, initial_speed - drop.velocity.length()) * drop.volume,
                );

                const delta_elev = self.elevation.get(drop.position) - self.elevation.get(initial_position);
                const max_sediment = @max(
                    drop.velocity.length() * drop.volume * -delta_elev * opts.sediment_capacity,
                    0,
                );

                const delta_sed = ret: {
                    if (delta_elev > 0) {
                        break :ret @min(delta_elev, drop.sediment);
                    } else {
                        break :ret (drop.sediment - max_sediment) * opts.mass_transfer_rate;
                    }
                };

                drop.sediment -= delta_sed;
                self.elevation.modify(initial_position, delta_sed);

                drop.volume *= 1 - opts.evaporation_rate;
            }
            self.erosion_iters += 1;
        }
    }
};

const WaterParticle = struct {
    position: Vector2,
    velocity: Vector2 = .{ .x = 0, .y = 0 },
    volume: f32 = 1,
    sediment: f32 = 0,

    pub fn init(pos: Vector2) WaterParticle {
        return .{ .position = pos };
    }
};

pub const ErosionOptions = struct {
    iterations: i32 = 50_000,
    min_volume: f32 = 0.01,
    mass_transfer_rate: f32 = 0.1,
    sediment_capacity: f32 = 10,
    evaporation_rate: f32 = 0.01,
    friction: f32 = 0.01,
    gravity: f32 = 8,
};
