const std = @import("std");
const C = @import("./components.zig");
const control = @import("./control.zig");
const utils = @import("./utils.zig");
const ecs = @import("./ecs.zig");
usingnamespace @import("./utils.zig");
usingnamespace @import("./updater.zig");
usingnamespace @import("./math.zig");

pub const Entity = usize;
const Registry = ecs.Registry(C, Entity);

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

        pub fn initPlayer(self: *@This(), data: PlayerInitData) !Entity {
            var player = self.registry.create();
            try self.registry.add(player, C.ControlByPlayer{});
            try self.registry.add(player, C.Renderable{});
            try self.registry.add(player, data.pos);
            try self.registry.add(player, C.Velocity{ .value = .{ 0, 0, 0 } });
            try self.registry.add(player, data.faced);
            try self.registry.add(player, data.box);
            try self.registry.add(player, data.health);
            try self.registry.add(player, data.energy);
            try self.registry.add(player, data.label);
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
            while (true) {
                suspend;
                if (flag.*) return;
                // FIXME: use faced
                // TODO: detect mid-air
                // TODO: add max spped prop
                const maxspeed = 0.1;
                const maxboostspeed = 0.3;
                const maxboostshiftspeed = 0.05;
                const changerate = 0.2;
                var iter = self.registry.view(struct { control: *C.ControlByPlayer, pos: *C.Position, vel: *C.Velocity, faced: *C.Faced });
                if (iter.next()) |str| {
                    str.faced.yaw += control.info.rotate[0];
                    str.faced.pitch += control.info.rotate[1];
                    control.info.rotate = [2]f32{ 0, 0 };
                    const c = std.math.cos(str.faced.yaw);
                    const s = std.math.sin(str.faced.yaw);
                    const speedY: f32 = if (control.info.boost) maxboostspeed else maxspeed;
                    const speedX: f32 = if (control.info.boost) maxboostshiftspeed else maxspeed;
                    const target = Vector3D{
                        c * speedX * control.info.move[0] - s * speedY * control.info.move[1],
                        s * speedX * control.info.move[0] + c * speedY * control.info.move[1],
                        str.vel.value[2],
                    };
                    str.vel.value = morph3d(str.vel.value, target, changerate);
                    if (control.info.jump) {
                        str.vel.value[2] = 0.2;
                    }
                }
            }
        }

        fn updatePosition(self: *@This(), flag: *bool) void {
            while (true) {
                suspend;
                if (flag.*) break;
                var iter = self.registry.view(struct { pos: *C.Position, vel: *C.Velocity });

                while (iter.next()) |str| {
                    const e = iter.entity;
                    str.vel.value[2] -= 0.01;
                    str.pos.* = C.Position{ .value = add3d(str.pos.value, str.vel.value) };
                }
            }
        }

        fn fixCollisionWithMap(self: *@This(), flag: *bool) void {
            while (true) {
                suspend;
                if (flag.*) break;
                var iter = self.registry.view(struct { box: *C.BoundingBox, pos: *C.Position, vel: *C.Velocity });

                while (iter.next()) |str| {
                    const dir = toDir3D(str.vel.value);
                    var idir = invertDir3D(dir);
                    var bound = Bound3D.initBase(0, MapType.width * MapType.ChunkType.width, 0, MapType.length * MapType.ChunkType.width, 0, MapType.ChunkType.height);
                    const aabb = AABB.fromEntityPosBox(str.pos.value, .{ str.box.radius, str.box.height }, bound);
                    var aabbiter = aabb.iterator();
                    while (aabbiter.next()) |it| {
                        if (!self.map.accessBlock(it.x, it.y, it.z).solid()) continue;
                        var lastpower = std.math.inf_f32;
                        var pdir: usize = 3;
                        var p: bool = undefined;
                        var localbound = Bound3D.init();
                        const connected = self.map.getConnectedFace(it.x, it.y, it.z);
                        inline for (comptime utils.range(usize, 3)) |i| {
                            for (connected[i]) |pos, ip| {
                                const power: f32 = blk: {
                                    if (ip == 0) {
                                        localbound.limit(i, true, it.get(i));
                                        break :blk aabb.float[i][1] - @intToFloat(f32, it.get(i));
                                    } else {
                                        localbound.limit(i, false, it.get(i) + 1);
                                        break :blk @intToFloat(f32, it.get(i)) - aabb.float[i][0] + 1;
                                    }
                                };

                                if (lastpower > power) {
                                    lastpower = power;
                                    const xdir: i2 = if (ip != 0) -1 else 1;
                                    if (power > 0 and !pos) {
                                        pdir = i;
                                        p = ip == 0;
                                    } else {
                                        pdir = 3;
                                    }
                                }
                            }
                        }

                        if (pdir != 3 and lastpower > 0) {
                            bound.mergeDirection(pdir, p, &localbound);
                        }
                    }
                    bound.applyAABB([3]f32{ str.box.radius, str.box.radius, str.box.height }, &str.pos.value, &str.vel.value);
                }
            }
        }
    };
}
