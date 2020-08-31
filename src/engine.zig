const std = @import("std");
const C = @import("./components.zig");
usingnamespace @import("./ecs/ecs.zig");
usingnamespace @import("./utils.zig");
usingnamespace @import("./scheduler.zig");

pub const PlayerInitData = struct {
    pos: C.Position,
    faced: C.Faced = .{ .yaw = 0, .pitch = 0 },
    phys: C.Physics = .{ .gravity = 0.01 },
    health: C.Health = .{ .max = 100, .value = 100 },
    energy: C.Energy = .{ .max = 100, .value = 100 },
    label: C.Label = C.Label.init("player"),
};

pub fn Engine(comptime MapType: type) type {
    return struct {
        allocator: *std.mem.Allocator,
        map: *MapType,
        registry: Registry,
        scheduler: Scheduler,

        pub fn init(allocator: *std.mem.Allocator, map: *MapType) @This() {
            return .{
                .allocator = allocator,
                .map = map,
                .registry = Registry.init(allocator),
                .scheduler = Scheduler.init(allocator),
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
            self.scheduler.add(GenPhysicsUpdater(@This()).updater, self);
            self.scheduler.add(positionUpdater, self.registry);
        }

        pub fn update(self: *@This()) void {
            self.scheduler.update();
        }
    };
}

fn GenPhysicsUpdater(comptime E: type) type {
    return struct {
        fn updater(proc: *Process, engine: *E) void {
            defer proc.dead = true;

            var view = engine.registry.view(.{ C.Position, C.Velocity, C.Physics });
            var iter = view.iterator();
            while (iter.next()) |e| {
                var vel = view.get(C.Velocity, e);
                const phys = view.get(C.Physics, e);
                vel.z -= phys.gravity;
            }
        }
    };
}

fn positionUpdater(proc: *Process, reg: Registry) void {
    defer proc.dead = true;

    var view = reg.view(.{ C.Position, C.Velocity }, .{});
    var iter = view.iterator();
    while (iter.next()) |e| {
        var pos = view.get(C.Position, e);
        const vel = view.getConst(C.Velocity, e);
        pos.x += vel.x;
        pos.y += vel.y;
        pos.z += vel.z;
    }
}