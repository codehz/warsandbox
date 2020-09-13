const std = @import("std");
const srb = @import("../utils/srb.zig");
const engine = @import("./engine.zig");
const C = @import("./components.zig");
usingnamespace @import("../utils/math.zig");

pub const UseResult = union(enum) {
    None,
    Consumed,
};

pub const Item = union(enum) {
    BlockItem: u16,
    SimpleWeapon: struct {
        bulletColor: u32,
        bulletSize: f32,
        velocity: f32,
    },
    // TODO: add more types

    pub fn maxStackSize(self: *const @This()) u16 {
        return switch (self) {
            .BlockItem => 64,
            .SimpleWeapon => 256,
        };
    }

    pub fn createForBlock(allocator: *std.mem.Allocator, id: u16) !*@This() {
        var ret = try allocator.create(@This());
        ret.* = @This(){ .BlockItem = id };
        return ret;
    }

    pub fn createSimpleWeapon(allocator: *std.mem.Allocator, color: u32, size: f32, velocity: f32) !*@This() {
        var ret = try allocator.create(@This());
        ret.* = @This(){ .SimpleWeapon = .{
            .bulletColor = color,
            .bulletSize = size,
            .velocity = velocity,
        } };
        return ret;
    }

    pub fn destroy(self: *@This(), allocator: *std.mem.Allocator) void {
        allocator.destroy(self);
        // PLACEHOLDER
    }

    pub fn use(self: *@This(), registry: *engine.Registry, pos: Vector3D, dir: Vector3D) !UseResult {
        switch (self.*) {
            .BlockItem => return UseResult.None,
            .SimpleWeapon => |weapon| {
                const bullet = registry.create();
                try registry.add(bullet, C.SimpleBullet{});
                try registry.add(bullet, C.Position{ .value = add3d(pos, Vector3D{ 0, 0, weapon.bulletSize / 2 }) });
                try registry.add(bullet, C.Velocity{ .value = setDistance3d(dir, weapon.velocity) });
                try registry.add(bullet, C.BoundingBox{ .radius = weapon.bulletSize, .height = weapon.bulletSize });
                return UseResult.Consumed;
            },
        }
    }

    pub fn useOnBlock(self: *@This(), map: anytype, pos: BlockPos, direction: Dir3D) !UseResult {
        // TODO: process another type of items
        switch (self.*) {
            .BlockItem => |blockId| {
                const x = @intCast(u16, @intCast(i32, pos[0]) + @intCast(i32, direction[0]));
                const y = @intCast(u16, @intCast(i32, pos[1]) + @intCast(i32, direction[1]));
                const z = @intCast(u8, @intCast(i16, pos[2]) + @intCast(i16, direction[2]));

                const proxy = map.accessChunk(x, y);
                proxy.chunk.access(proxy.mx, proxy.my, z).setBlock(blockId);
                proxy.chunk.dirty = true;
                return UseResult.Consumed;
            },
            else => return UseResult.None,
        }
    }
};

pub const ItemStack = struct {
    allocator: *std.mem.Allocator,
    item: *Item,
    count: u16,

    pub fn init(allocator: *std.mem.Allocator, item: *Item, count: u16) @This() {
        return .{
            .allocator = allocator,
            .item = item,
            .count = count,
        };
    }

    pub fn add(self: *@This(), addcount: u16) bool {
        const newcount = self.count +% addcount;
        if (newcount < self.count) return false; // overflow
        if (newcount > self.items.maxStackSize()) return false;
        self.count = newcount;
        return true;
    }

    pub fn del(self: *@This(), delcount: u16) bool {
        if (self.count < delcount) return false;
        self.count -= delcount;
        return true;
    }

    pub fn use(self: *@This(), registry: *engine.Registry, pos: Vector3D, dir: Vector3D) !?UseResult {
        if (self.count == 0) return null;
        const ret = try self.item.use(registry, pos, dir);
        switch (ret) {
            .Consumed => {
                _ = self.del(1);
            },
            else => {},
        }
        return ret;
    }

    pub fn useOnBlock(self: *@This(), map: anytype, pos: BlockPos, direction: Dir3D) !?UseResult {
        if (self.count == 0) return null;
        const ret = try self.item.useOnBlock(map, pos, direction);
        switch (ret) {
            .Consumed => {
                _ = self.del(1);
            },
            else => {},
        }
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        self.item.destroy(self.allocator);
    }
};

pub const Container = struct {
    pub const Storage = srb.AutoTreeMap(u16, ItemStack);
    size: u16,
    data: Storage,

    pub fn init(allocator: *std.mem.Allocator, size: u16) @This() {
        return .{
            .size = size,
            .data = Storage.init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.data.deinit();
    }
};
