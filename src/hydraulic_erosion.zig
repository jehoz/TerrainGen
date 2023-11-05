const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const vectors = @import("vectors.zig");
const Vector2 = vectors.Vector2;
const CellOffset2 = vectors.CellOffset2;

const Terrain = @import("terrain.zig").Terrain;

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

pub fn erodeTerrain(t: *Terrain, opts: ErosionOptions) void {
    const height = t.elevation.len;
    const width = t.elevation[0].len;

    var prng = std.rand.DefaultPrng.init(0);
    var random = prng.random();
    for (0..@intCast(opts.iterations)) |_| {
        // spawn water droplet in random location
        const x = random.float(f32) * @as(f32, @floatFromInt(width));
        const y = random.float(f32) * @as(f32, @floatFromInt(height));

        var drop = WaterParticle.init(x, y);

        for (0..@intCast(opts.max_particle_lifetime)) |_| {
            // save initial position for later
            const pos_initial = drop.position;

            const eg_result = elevgrad(t.*, drop.position);
            const initial_elev = eg_result.elevation;
            const gradient = eg_result.gradient;

            drop.direction = drop.direction
                .scale(opts.inertia)
                .subtract(gradient.scale(1 - opts.inertia))
                .normalize();

            // always move droplet one unit forward regardless of speed
            drop.position = drop.position.add(drop.direction);

            // exit early if drop is out of bounds
            if (drop.position.x < 0 or
                drop.position.x >= @as(f32, @floatFromInt(width)) or
                drop.position.y < 0 or
                drop.position.y >= @as(f32, @floatFromInt(height)))
            {
                break;
            }

            // compute change in elevation
            const final_elev = elevgrad(t.*, drop.position).elevation;
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
            modifyElevation(t, pos_initial, delta_sed);

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
    }
}

const elevgrad_result = struct { elevation: f32, gradient: Vector2 };

/// Compute the interpolated elevation and gradient for a point in the terrain
fn elevgrad(t: Terrain, point: Vector2) elevgrad_result {
    const point_co = point.cellOffset();
    const cell = point_co.cell;
    const offset = point_co.offset;

    // do some bounds checking
    const n: usize = @intCast(cell.y);
    const s: usize = if (n + 1 < t.elevation.len) n + 1 else n;
    const w: usize = @intCast(cell.x);
    const e: usize = if (w + 1 < t.elevation[0].len) w + 1 else w;

    const nw = t.elevation[n][w];
    const ne = t.elevation[n][e];
    const sw = t.elevation[s][w];
    const se = t.elevation[s][e];

    // compute interpolated elevation
    const elev = nw * (1 - offset.x) * (1 - offset.y) +
        ne * offset.x * (1 - offset.y) +
        sw * (1 - offset.x) * offset.y +
        se * offset.x * offset.y;

    // compute slope at point (gradient)
    const grad = .{
        .x = (ne - nw) * (1 - offset.y) + (se - sw) * offset.y,
        .y = (sw - nw) * (1 - offset.x) + (se - ne) * offset.x,
    };

    return .{
        .elevation = elev,
        .gradient = grad,
    };
}

fn modifyElevation(t: *Terrain, point: Vector2, delta: f32) void {
    const point_co = point.cellOffset();
    const cell = point_co.cell;
    const offset = point_co.offset;

    // do some bounds checking
    const n: usize = @intCast(cell.y);
    const s: usize = if (n + 1 < t.elevation.len) n + 1 else n;
    const w: usize = @intCast(cell.x);
    const e: usize = if (w + 1 < t.elevation[0].len) w + 1 else w;

    // distribute dH across four cornering cells
    t.elevation[n][w] += delta * (1 - offset.x) * (1 - offset.y);
    t.elevation[n][e] += delta * offset.x * (1 - offset.y);
    t.elevation[s][w] += delta * (1 - offset.x) * offset.y;
    t.elevation[s][e] += delta * offset.x * offset.y;
}
