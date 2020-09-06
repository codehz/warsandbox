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
                    str.vel.value[1] = if (control.keyboard.up) @as(f32, 0.05) else if (control.keyboard.down) @as(f32, -0.05) else 0;
                    str.vel.value[0] = if (control.keyboard.right) @as(f32, 0.05) else if (control.keyboard.left) @as(f32, -0.05) else 0;
                    if (control.keyboard.space) {
                        std.log.info("{d:.2} {d:.2} {d:.2}", .{ str.pos.value[0], str.pos.value[1], str.pos.value[2] });
                        str.vel.value[2] = 0.2;
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
                    var bound = Bound3D.initBase(0, MapType.width * MapType.ChunkType.width, 0, MapType.length * MapType.ChunkType.width, 0, MapType.ChunkType.height);
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
                                    var lastpower = std.math.inf_f32;
                                    var pdir: usize = 3;
                                    var p: bool = undefined;
                                    var localbound = Bound3D.init();
                                    const connected = self.map.getConnectedFace(x, y, z);
                                    for (connected) |cdir, i| {
                                        for (cdir) |pos, ip| {
                                            const xlen: f32 = switch (i) {
                                                0 => blk: {
                                                    if (ip == 0) {
                                                        localbound.limit(i, true, x);
                                                        break :blk fxmax - @intToFloat(f32, x);
                                                    } else {
                                                        localbound.limit(i, false, x + 1);
                                                        break :blk @intToFloat(f32, x) - fxmin + 1;
                                                    }
                                                },
                                                1 => blk: {
                                                    if (ip == 0) {
                                                        localbound.limit(i, true, y);
                                                        break :blk fymax - @intToFloat(f32, y);
                                                    } else {
                                                        localbound.limit(i, false, y + 1);
                                                        break :blk @intToFloat(f32, y) - fymin + 1;
                                                    }
                                                },
                                                2 => blk: {
                                                    if (ip == 0) {
                                                        localbound.limit(i, true, z);
                                                        break :blk fzmax - @intToFloat(f32, z);
                                                    } else {
                                                        localbound.limit(i, false, z + 1);
                                                        break :blk @intToFloat(f32, z) - fzmin + 1;
                                                    }
                                                },
                                                else => unreachable,
                                            };
                                            const power = xlen;
                                            if (lastpower > power and xlen < 1) {
                                                lastpower = power;
                                                const xdir: i2 = if (ip != 0) -1 else 1;
                                                if (xdir == dir[i] and power > 0 and !pos) {
                                                    pdir = i;
                                                    p = ip == 0;
                                                } else {
                                                    pdir = 3;
                                                }
                                            } else {
                                            }
                                        }
                                    }
                                    if (pdir != 3 and lastpower > 0) {
                                        bound.mergeDirection(pdir, p, &localbound);
                                    }
                                }
                            }
                        }
                    }
                    bound.applyAABB([3]f32{ str.box.radius, str.box.radius, str.box.height }, &str.pos.value, &str.vel.value);
                }
            }
        }
    };
}
