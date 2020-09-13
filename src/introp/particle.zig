const std = @import("std");
const utils = @import("../utils/utils.zig");
const C = @import("../game/components.zig");
usingnamespace @import("../utils/math.zig");
const root = @import("../main.zig");

pub const ParticleInfo = extern struct {
    size: f32,
    position: Vector3D,
    color: [3]f32,
};

const maxCount = 256;

version: u32,
particles: [maxCount]ParticleInfo,

pub fn init(self: *@This()) void {
    for (self.particles) |*par| {
        par.color = [3]f32{ 0, 0, 0 };
        par.position = [3]f32{ 0, 0, 0 };
        par.size = 0;
    }
}

fn convertColor(rgb: u32) [3]f32 {
    return .{
        @intToFloat(f32, rgb >> 16) / 0xFF,
        @intToFloat(f32, @mod(rgb >> 8, 0xFF)) / 0xFF,
        @intToFloat(f32, @mod(rgb, 0xFF)) / 0xFF,
    };
}

pub fn updateFunction(self: *@This(), stopped: *bool) void {
    while (true) {
        suspend;
        if (stopped.*) return;

        self.version +%= 1;

        var bullets = root.engine.registry.view(struct {
            particle: *C.SimpleBullet,
            pos: *C.Position,
            died: ?*C.Died,
        });
        while (bullets.next()) |str| {
            if (str.particle.particleId) |par| {
                if (str.died != null) {
                    self.destroy(par);
                } else {
                    self.setPosition(par, str.pos.value);
                }
            } else {
                str.particle.particleId = self.createParticle(.{
                    .size = str.particle.size,
                    .color = convertColor(str.particle.color),
                    .position = str.pos.value,
                });
            }
        }
    }
}

pub fn createParticle(self: *@This(), info: ParticleInfo) u32 {
    for (self.particles) |*particle, i| {
        if (particle.size == 0) {
            particle.* = info;
            return @intCast(u32, i);
        }
    }
    @panic("here");
}

pub fn setPosition(self: *@This(), slot: u32, position: Vector3D) void {
    self.particles[slot].position = position;
}

pub fn destroy(self: *@This(), slot: u32) void {
    self.particles[slot].size = 0;
}
