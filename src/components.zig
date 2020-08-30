const std = @import("std");

pub const Position = struct { x: f32, y: f32, z: f32 };
pub const Velocity = struct { x: f32, y: f32, z: f32 };
pub const Faced = struct { yaw: f32, pitch: f32 };
pub const Renderable = struct {};
pub const Physics = struct { gravity: f32 };
pub const Health = struct { max: f32, value: f32 };
pub const Energy = struct { max: f32, value: f32 };
pub const Targetable = struct {};
pub const Hostility = struct {};
pub const Died = struct {};
pub const ControlByPlayer = struct {};

pub const Label = struct {
    name: [64]u8,
    len: u8,
    pub fn init(name: []const u8) @This() {
        std.debug.assert(name.len <= 64);
        var ret: @This() = .{
            .name = undefined,
            .len = @intCast(u8, name.len),
        };
        @memcpy(&ret.name, name.ptr, name.len);
        return ret;
    }

    pub fn text(self: @This()) []const u8 {
        return self.name[0..self.len];
    }
};
