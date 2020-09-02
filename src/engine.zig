const std = @import("std");
const C = @import("./components.zig");
usingnamespace @import("./ecs/ecs.zig");
usingnamespace @import("./utils.zig");
usingnamespace @import("./updater.zig");

pub const PlayerInitData = struct {
    pos: C.Position,
    faced: C.Faced = .{ .yaw = 0, .pitch = 0 },
    phys: C.Gravity = .{ .value = 0.01 },
    health: C.Health = .{ .max = 100, .value = 100 },
    energy: C.Energy = .{ .max = 100, .value = 100 },
    label: C.Label = C.Label.init("player"),
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
            self.registry.add(player, C.Velocity{ .x = 0, .y = 0, .z = 0 });
            self.registry.add(player, data.faced);
            self.registry.add(player, data.phys);
            self.registry.add(player, data.health);
            self.registry.add(player, data.energy);
            self.registry.add(player, data.label);
            return player;
        }

        pub fn initSystem(self: *@This()) !void {
            try self.updater.addFn(updatePosition, self);
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
                    if (self.registry.tryGet(C.Gravity, e)) |g| {
                        str.vel.z += g.value;
                    }
                    str.pos.x += str.vel.x;
                    str.pos.y += str.vel.y;
                    str.pos.z += str.vel.z;
                }
            }
        }
    };
}
