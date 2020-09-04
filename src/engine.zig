const std = @import("std");
const C = @import("./components.zig");
const control = @import("./control.zig");
const utils = @import("./utils.zig");
usingnamespace @import("./ecs/ecs.zig");
usingnamespace @import("./utils.zig");
usingnamespace @import("./updater.zig");
usingnamespace @import("./math.zig");

pub const PlayerInitData = struct {
    pos: C.Position,
    faced: C.Faced = .{ .yaw = 0, .pitch = 0 },
    health: C.Health = .{ .max = 100, .value = 100 },
    energy: C.Energy = .{ .max = 100, .value = 100 },
    label: C.Label = C.Label.init("player"),
    box: C.BoundingBox = .{ .radius = 0.32, .height = 1.9 },
};

pub fn Engine(comptime MapType: type) type {
    return struct {
        allocator: *std.mem.Allocator,
        map: *MapType,
        registry: Registry,
        updater: UpdateManager,

        pub fn init(allocator: *std.mem.Allocator, map: *MapType) @This() {
            return .{
                .allocator = allocator,
                .map = map,
                .registry = Registry.init(allocator),
                .updater = UpdateManager.init(allocator),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.registry.deinit();
        }

        pub fn initPlayer(self: *@This(), data: PlayerInitData) Entity {
            var player = self.registry.create();
            self.registry.add(player, C.ControlByPlayer{});
            self.registry.add(player, C.Renderable{});
            self.registry.add(player, data.pos);
            self.registry.add(player, C.Velocity{ .value = .{ 0, 0, 0 } });
            self.registry.add(player, data.faced);
            self.registry.add(player, data.box);
            self.registry.add(player, data.health);
            self.registry.add(player, data.energy);
            self.registry.add(player, data.label);
            return player;
        }

        pub fn initSystem(self: *@This()) !void {
            try self.updater.addFn(updateControl, self);
            try self.updater.addFn(updatePosition, self);
            try self.updater.addFn(fixCollisionWithMap, self);
        }

        pub fn update(self: *@This()) void {
            self.updater.update();
        }

        fn updateControl(self: *@This(), flag: *bool) void {
            var group = self.registry.group(.{C.ControlByPlayer}, .{ C.Velocity, C.Position, C.Faced }, .{});
            while (true) {
                suspend;
                if (flag.*) return;
                // FIXME: use faced
                var iter = group.iterator(struct { pos: *C.Position, vel: *C.Velocity, faced: *C.Faced });
                if (iter.next()) |str| {
                    if (control.keyboard.up) {
                        str.vel.value[1] += 0.01;
                    }
                    if (control.keyboard.down) {
                        str.vel.value[1] -= 0.01;
                    }
                    if (control.keyboard.left) {
                        str.vel.value[0] -= 0.01;
                    }
                    if (control.keyboard.right) {
                        str.vel.value[0] += 0.01;
                    }
                    if (control.keyboard.space) {
                        str.pos.value[2] += 5;
                    }
                }
            }
        }

        fn updatePosition(self: *@This(), flag: *bool) void {
            var group = self.registry.group(.{ C.Position, C.Velocity }, .{}, .{});
            while (true) {
                suspend;
                if (flag.*) break;
                var iter = group.iterator(struct { pos: *C.Position, vel: *C.Velocity });

                while (iter.next()) |str| {
                    const e = iter.entity();
                    str.vel.value[2] -= 0.01;
                    str.pos.* = C.Position{ .value = add3d(str.pos.value, str.vel.value) };
                }
            }
        }

        fn fixCollisionWithMap(self: *@This(), flag: *bool) void {
            var group = self.registry.group(.{C.BoundingBox}, .{ C.Position, C.Velocity }, .{});
            while (true) {
                suspend;
                if (flag.*) break;
                var iter = group.iterator(struct { box: *C.BoundingBox, pos: *C.Position, vel: *C.Velocity });

                while (iter.next()) |str| {
                    var collided = false;
                    const dir = toDir3D(str.vel.value);
                    var idir = invertDir3D(dir);
                    const fxmin = str.pos.value[0] - str.box.radius;
                    const xmin = @floatToInt(u16, fxmin);
                    const fxmax = str.pos.value[0] + str.box.radius;
                    const xmax = @floatToInt(u16, fxmax);
                    const fymin = str.pos.value[1] - str.box.radius;
                    const ymin = @floatToInt(u16, fymin);
                    const fymax = str.pos.value[1] + str.box.radius;
                    const ymax = @floatToInt(u16, fymax);
                    const fzmin = str.pos.value[2];
                    const zmin = @floatToInt(u8, fzmin);
                    const fzmax = str.pos.value[2] + str.box.height;
                    const zmax = @floatToInt(u8, fzmax);
                    const center = add3d(str.pos.value, [3]f32{ 0, 0, str.box.height / 2 });
                    var x = xmin;
                    var y = ymin;
                    var z = zmin;
                    while (x <= xmax) : (x += 1) {
                        y = ymin;
                        while (y <= ymax) : (y += 1) {
                            z = zmin;
                            while (z <= zmax) : (z += 1) {
                                const isBlock = self.map.accessBlock(x, y, z).solid();
                                if (isBlock) {
                                    collided = true;
                                    var fdir = idir;
                                    self.map.checkBlockFace(x, y, z, &fdir);
                                    var lastpower = std.math.inf_f32;
                                    var pdir: usize = 3; // invalid
                                    inline for (comptime utils.range(usize, 3)) |i| {
                                        if (fdir[i] != 0) {
                                            const p = dir[i] > 0;
                                            const power: f32 = switch (i) {
                                                0 => blk: {
                                                    if (p) {
                                                        break :blk fxmax - @intToFloat(f32, x);
                                                    } else {
                                                        break :blk @intToFloat(f32, x) - fxmin;
                                                    }
                                                },
                                                1 => blk: {
                                                    if (p) {
                                                        break :blk fymax - @intToFloat(f32, y);
                                                    } else {
                                                        break :blk @intToFloat(f32, y) - fymin;
                                                    }
                                                },
                                                2 => blk: {
                                                    if (p) {
                                                        break :blk fzmax - @intToFloat(f32, z);
                                                    } else {
                                                        break :blk @intToFloat(f32, z) - fzmin;
                                                    }
                                                },
                                                else => unreachable,
                                            };
                                            if (lastpower > power) {
                                                lastpower = power;
                                                pdir = i;
                                            }
                                        }
                                    }
                                    std.log.info("({} {} {})last: {d:.3} pdir: {}", .{ x, y, z, lastpower, pdir });
                                    if (lastpower <= 1) {
                                        idir[pdir] = 0;
                                    }
                                }
                            }
                        }
                    }
                    if (collided) {
                        std.log.info("! ({} {} {})", .{ idir[0], idir[1], idir[2] });
                        inline for (comptime utils.range(usize, 3)) |i| {
                            const v = str.vel.value[i];
                            if (idir[i] == 0 and dir[i] != 0) {
                                if (i != 2) {
                                    if (dir[i] > 0) {
                                        str.pos.value[i] = std.math.ceil(str.pos.value[i] - v) - str.box.radius;
                                    } else {
                                        str.pos.value[i] = std.math.floor(str.pos.value[i] - v) + str.box.radius;
                                    }
                                } else {
                                    if (dir[i] > 0) {
                                        str.pos.value[i] = std.math.ceil(str.pos.value[i] - v) - str.box.height;
                                    } else {
                                        str.pos.value[i] = std.math.floor(str.pos.value[i] - v);
                                    }
                                }
                                str.vel.value[i] = 0;
                            }
                        }
                    }
                }
            }
        }
    };
}
