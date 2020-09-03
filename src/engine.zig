const std = @import("std");
const C = @import("./components.zig");
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
    box: C.BoundingBox = .{ .radius = 0.5, .height = 1.9 },
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
            try self.updater.addFn(updatePosition, self);
            try self.updater.addFn(fixCollisionWithMap, self);
        }

        pub fn update(self: *@This()) void {
            self.updater.update();
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
                    var xmin = @floatToInt(u16, str.pos.value[0] - str.box.radius - 0.5);
                    var xmax = @floatToInt(u16, str.pos.value[0] + str.box.radius - 0.5);
                    var ymin = @floatToInt(u16, str.pos.value[1] - str.box.radius - 0.5);
                    var ymax = @floatToInt(u16, str.pos.value[1] + str.box.radius - 0.5);
                    var zmin = @floatToInt(u8, str.pos.value[2] - 0.5);
                    var zmax = @floatToInt(u8, str.pos.value[2] + str.box.height - 0.5);
                    var center = add3d(str.pos.value, [3]f32{ 0, 0, str.box.height / 2 });
                    while (xmin <= xmax) : (xmin += 1) {
                        while (ymin <= ymax) : (ymin += 1) {
                            while (zmin <= zmax) : (zmin += 1) {
                                const isBlock = !self.map.accessBlock(xmin, ymin, zmin).*.isAir;
                                if (isBlock) {
                                    // TODO: use correct alg
                                    str.pos.* = C.Position{ .value = sub3d(str.pos.value, str.vel.value) };
                                    str.vel.value = .{ 0, 0, 0 };
                                }
                            }
                        }
                    }
                }
            }
        }
    };
}
