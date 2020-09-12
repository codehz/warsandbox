const std = @import("std");
const C = @import("./components.zig");
const I = @import("./item.zig");
const control = @import("./control.zig");
const utils = @import("../utils/utils.zig");
const ecs = @import("../utils/ecs.zig");
usingnamespace @import("../utils/utils.zig");
usingnamespace @import("../utils/updater.zig");
usingnamespace @import("../utils/math.zig");

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
            try self.registry.add(player, C.Inventory{
                .container = I.Container.init(self.allocator, 8),
            });
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

        fn defaultBound() Bound3D {
            return comptime Bound3D.initBase(0, MapType.width * MapType.ChunkType.width, 0, MapType.length * MapType.ChunkType.width, 0, MapType.ChunkType.height);
        }

        fn updateControl(self: *@This(), flag: *bool) void {
            while (true) {
                suspend;
                if (flag.*) return;
                // TODO: detect mid-air
                // TODO: add max spped prop
                const maxspeed = 0.2;
                const maxboostspeed = 0.3;
                const maxboostshiftspeed = 0.15;
                const changerate = 0.2;
                const boostchangerate = 0.1;
                var iter = self.registry.view(struct { control: *C.ControlByPlayer, pos: *C.Position, vel: *C.Velocity, faced: *C.Faced });
                if (iter.next()) |str| {
                    str.faced.yaw += control.info.rotate[0];
                    if (str.faced.yaw < 0) {
                        str.faced.yaw += std.math.pi * 2.0;
                    } else if (str.faced.yaw > std.math.pi * 2.0) {
                        str.faced.yaw -= std.math.pi * 2.0;
                    }
                    str.faced.pitch = minmax(str.faced.pitch + control.info.rotate[1], std.math.pi / -2.0, std.math.pi / 2.0);
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
                    str.vel.value = morph3d(str.vel.value, target, if (control.info.boost) boostchangerate else changerate);
                    if (control.info.jump) {
                        str.vel.value[2] = 0.2;
                    }
                    // FIXME: use correct height
                    const sp = std.math.sin(str.faced.pitch);
                    const cp = std.math.cos(str.faced.pitch);
                    const ray: Ray3D = .{
                        .origin = add3d(str.pos.value, Vector3D{ 0, 0, 1.7 }),
                        .direction = Vector3D{ -s * cp, c * cp, sp },
                    };
                    const bound = defaultBound();
                    str.control.selected = null;
                    var riter = ray.iterator();
                    while (riter.next()) |blk| {
                        // FIXME: use config value
                        if (riter.time > 5) break;
                        if (!bound.inbound(blk)) break;
                        // FIXME: also check entity
                        if (self.map.accessBlock(blk[0], blk[1], @intCast(u8, blk[2])).solid()) {
                            str.control.selected = C.ControlByPlayer.Selected{
                                .pos = blk,
                                .direction = riter.face,
                            };
                            break;
                        }
                    }
                    if (str.control.selected) |selected| {
                        if (control.info.use1) {
                            // FIXME: add break time
                            // FIXME: check game mode, only builder mode can break block directly
                            const x = selected.pos[0];
                            const y = selected.pos[1];
                            const z = @intCast(u8, selected.pos[2]);
                            const proxy = self.map.accessChunk(x, y);
                            proxy.chunk.access(proxy.mx, proxy.my, z).setAir();
                            proxy.chunk.dirty = true;
                            str.control.selected = null;
                            control.info.use1 = false;
                        } else if (control.info.use3) {
                            // FIXME: check game mode
                            // FIXME: check and use selected block
                            const x = @intCast(u16, @intCast(i32, selected.pos[0]) + @intCast(i32, selected.direction[0]));
                            const y = @intCast(u16, @intCast(i32, selected.pos[1]) + @intCast(i32, selected.direction[1]));
                            const z = @intCast(u8, @intCast(i16, selected.pos[2]) + @intCast(i16, selected.direction[2]));
                            const proxy = self.map.accessChunk(x, y);
                            proxy.chunk.access(proxy.mx, proxy.my, z).setBlock();
                            proxy.chunk.dirty = true;
                            str.control.selected = null;
                            control.info.use3 = false;
                        }
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
                    str.vel.value[2] -= 0.02;
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
                    var bound = defaultBound();
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
