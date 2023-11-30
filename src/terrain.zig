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

        var timer = std.time.Timer.start() catch null;
        for (0..@intCast(opts.iterations)) |_| {
            var drop = WaterDroplet.init(.{
                .x = random.float(f32) * width_f,
                .y = random.float(f32) * height_f,
            });

            while (drop.volume > opts.min_volume) {
                const init_pos = drop.position;

                // Movement
                const grav_force = self.elevation.gradient(drop.position).scale(opts.gravity);
                drop.velocity = drop.velocity.scale(1 - opts.friction).subtract(grav_force);

                drop.position = drop.position.add(drop.velocity.normalize());
                if (drop.position.x < 0 or drop.position.x >= width_f or
                    drop.position.y < 0 or drop.position.y >= height_f)
                {
                    break;
                }

                // Sediment transfer
                const delta_elev = self.elevation.get(drop.position) - self.elevation.get(init_pos);
                var delta_sed = delta_elev * opts.sediment_transfer_rate;
                if (delta_sed < 0) {
                    delta_sed *= std.math.pow(f32, self.moisture.get(init_pos), opts.rock_hardness);
                }

                if (delta_sed > 0) delta_sed *= opts.sediment_ratio;
                self.elevation.modify(init_pos, delta_sed);

                // Soil moisture
                self.moisture.modify(drop.position, delta_moist: {
                    const inv_speed = @max(0, 1 - drop.velocity.length());
                    var inv_saturation = @max(0, 1 - self.moisture.get(drop.position));
                    inv_saturation *= inv_saturation;
                    break :delta_moist inv_speed * inv_saturation * opts.soil_absorption;
                });

                // Evaporate
                drop.volume *= 1 - opts.droplet_evaporation;
            }

            // Soil evaporation
            for (self.moisture.data, 0..) |_, i| {
                self.moisture.data[i] *= 1 - opts.soil_evaporation;
            }

            self.erosion_iters += 1;
        }

        if (timer) |*t| {
            std.debug.print("Completed {} iterations in {} seconds.\n", .{
                self.erosion_iters,
                @as(f64, @floatFromInt(t.read())) / 1e9,
            });
        }
    }
};

const WaterDroplet = struct {
    position: Vector2,
    velocity: Vector2 = .{ .x = 0, .y = 0 },
    volume: f32 = 1,

    pub fn init(pos: Vector2) WaterDroplet {
        return .{ .position = pos };
    }
};

pub const ErosionOptions = struct {
    /// Number of water droplets to spawn and simulate
    iterations: i32 = 50_000,

    /// Minimum volume of a water droplet before it is culled
    min_volume: f32 = 0.01,
    /// Scale factor for how much sediment is eroded/deposited at each time step
    sediment_transfer_rate: f32 = 0.5,
    /// Percent volume reduction of water droplet each time step
    droplet_evaporation: f32 = 0.01,
    /// Amount of sediment that is deposited relative to how much is eroded
    /// by the water droplet
    sediment_ratio: f32 = 3,

    /// Percent speed reduction of water droplet each time step
    friction: f32 = 0.05,
    /// Scale factor for how much slope affects droplet velocity
    gravity: f32 = 12,

    /// Percent moisture reduction of terrain each time step
    soil_evaporation: f32 = 0.00025,
    /// Scale factor for how much moisture a droplet adds to the ground
    soil_absorption: f32 = 0.5,
    /// Exponent controlling how much lack of moisture reduces erosion amount
    rock_hardness: f32 = 0.25,
};

