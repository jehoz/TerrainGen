const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});
const fnl = @cImport({
    @cInclude("FastNoiseLite.h");
});

const vectors = @import("vectors.zig");
const Vector2 = vectors.Vector2;

const MeshGrid = @import("mesh_grid.zig").MeshGrid;

pub const Terrain = struct {
    elevation: MeshGrid(f32),
    width: usize,
    height: usize,
    erosion_iters: i32 = 0,

    allocator: std.mem.Allocator,

    pub fn init(width: usize, height: usize, allocator: std.mem.Allocator) !Terrain {
        return .{
            .elevation = try MeshGrid(f32).init(width, height, allocator),
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Terrain) void {
        self.elevation.deinit();
        self.* = undefined;
    }

    pub fn fillNoise(self: *Terrain, noise: *fnl.fnl_state) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const noise_val = fnl.fnlGetNoise2D(
                    noise,
                    @floatFromInt(x),
                    @floatFromInt(y),
                );
                // remap range from [-1, 1] to [0, 1]
                self.elevation.setCell(x, y, (noise_val + 1) / 2);
            }
        }
    }

    pub fn renderElevation(self: Terrain) rl.Image {
        var img = rl.GenImageColor(
            @intCast(self.width),
            @intCast(self.height),
            rl.BLACK,
        );

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const raw_elev = self.elevation.getCell(x, y);
                const z: u8 = @intFromFloat(std.math.clamp(raw_elev, 0, 1) * 255);
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

    pub fn erode(self: *Terrain, opts: ErosionOptions) void {
        var prng = std.rand.DefaultPrng.init(0);
        var random = prng.random();

        for (0..@intCast(opts.iterations)) |_| {
            // spawn water droplet in random location
            const x = random.float(f32) * @as(f32, @floatFromInt(self.width));
            const y = random.float(f32) * @as(f32, @floatFromInt(self.height));

            var drop = WaterParticle.init(x, y);

            for (0..@intCast(opts.max_particle_lifetime)) |_| {
                // save initial position for later
                const pos_initial = drop.position;

                const initial_elev = self.elevation.get(drop.position);
                const gradient = self.elevation.gradient(drop.position);

                drop.direction = drop.direction
                    .scale(opts.inertia)
                    .subtract(gradient.scale(1 - opts.inertia))
                    .normalize();

                // always move droplet one unit forward regardless of speed
                drop.position = drop.position.add(drop.direction);

                // exit early if drop is out of bounds
                if (drop.position.x < 0 or
                    drop.position.x >= @as(f32, @floatFromInt(self.width)) or
                    drop.position.y < 0 or
                    drop.position.y >= @as(f32, @floatFromInt(self.height)))
                {
                    break;
                }

                // compute change in elevation
                const final_elev = self.elevation.get(drop.position);
                const delta_elev = final_elev - initial_elev;

                // maximum sediment higher when moving fast downhill or large volume
                const max_sed = @max(
                    -delta_elev * drop.speed * drop.volume * opts.sediment_capacity,
                    opts.min_sediment_capacity,
                );

                var delta_sed: f32 = 0;
                if (delta_elev > 0) {
                    // if moving uphill, try to fill up to current height
                    delta_sed = @min(delta_elev, drop.sediment);
                } else if (drop.sediment > max_sed) {
                    // if too much sediment, deposit as much as possible
                    delta_sed = (drop.sediment - max_sed) * opts.deposition_rate;
                } else {
                    // otherwise erode sediment
                    delta_sed = -@min(
                        (max_sed - drop.sediment) * opts.erosion_rate,
                        -delta_elev,
                    );
                }
                drop.sediment -= delta_sed;
                self.elevation.modify(pos_initial, delta_sed);

                // update water particle's speed and volume
                drop.speed = @sqrt(
                    std.math.clamp(
                        drop.speed * drop.speed + delta_elev * opts.gravity,
                        0,
                        1,
                    ),
                );
                drop.volume *= 1 - opts.evaporation_rate;

                // exit early if stopped moving
                if (drop.speed == 0) {
                    break;
                }
            }
            self.erosion_iters += 1;
        }
    }
};

const WaterParticle = struct {
    position: Vector2,
    direction: Vector2,
    speed: f32,
    volume: f32,
    sediment: f32,

    pub fn init(x: f32, y: f32) WaterParticle {
        return .{
            .position = .{ .x = x, .y = y },
            .direction = .{ .x = 0, .y = 0 },
            .speed = 1,
            .volume = 1,
            .sediment = 0,
        };
    }
};

pub const ErosionOptions = struct {
    iterations: i32 = 10_000,
    max_particle_lifetime: i32 = 64,
    inertia: f32 = 0.05,
    sediment_capacity: f32 = 4,
    min_sediment_capacity: f32 = 0.01,
    erosion_rate: f32 = 0.01,
    deposition_rate: f32 = 0.2,
    evaporation_rate: f32 = 0.02,
    gravity: f32 = 15,
};
