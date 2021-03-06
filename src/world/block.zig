const std = @import("std");

pub const TestingBlock = struct {
    isAir: bool = true,
    pub fn solid(self: *const @This()) bool {
        return !self.isAir;
    }

    pub fn setAir(self: *@This()) void {
        self.isAir = true;
    }

    pub fn setBlock(self: *@This()) void {
        self.isAir = false;
    }

    pub fn init() @This() {
        return .{};
    }
};

pub const SimpleBlock = struct {
    id: u16 = 0,

    pub fn solid(self: *const @This()) bool {
        return self.id != 0;
    }

    pub fn setAir(self: *@This()) void {
        self.id = 0;
    }

    pub fn setBlock(self: *@This(), id: u16) void {
        self.id = id;
    }

    pub fn init() @This() {
        return .{};
    }
};
