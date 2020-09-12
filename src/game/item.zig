const std = @import("std");
const srb = @import("../utils/srb.zig");

pub const Item = union(enum) {
    BlockItem: u16,
    // TODO: add more types

    pub fn maxStackSize(self: *const @This()) u8 {
        return switch (self) {
            .BlockItem => 16,
        };
    }

    pub fn createForBlock(allocator: *std.mem.Allocator, id: u16) *@This() {
        var ret = allocator.create(@This());
        ret.* = @This(){ .BlockItem = id };
        return ret;
    }

    pub fn destroy(self: *@This(), allocator: *std.mem.Allocator) void {
        allocator.destroy(self);
        // PLACEHOLDER
    }
};

pub const ItemStack = struct {
    allocator: *std.mem.Allocator,
    item: *Item,
    count: u8,

    pub fn init(allocator: *std.mem.Allocator, item: *Item, count: u8) @This() {
        return .{
            .allocator = allocator,
            .items = item,
            .count = count,
        };
    }

    pub fn add(self: *@This(), addcount: u8) bool {
        const newcount = self.count +% addcount;
        if (newcount < self.count) return false; // overflow
        if (newcount > self.items.maxStackSize()) return false;
        self.count = newcount;
        return true;
    }

    pub fn del(self: *@This(), delcount: u8) bool {
        if (self.count < delcount) return false;
        self.count -= delcount;
        return true;
    }

    pub fn deinit(self: *@This()) void {
        self.item.destroy(self.allocator);
    }
};

pub const Container = struct {
    pub const Storage = srb.AutoTreeMap(u16, *ItemStack);
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