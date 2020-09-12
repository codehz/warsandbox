const std = @import("std");

fn SimFn(comptime T: type) type {
    return fn (self: *T) void;
}

pub const Updater = struct {
    mUpdate: SimFn(@This()),
    mDeinit: SimFn(@This()),

    fn update(self: *@This()) void {
        self.mUpdate(self);
    }

    fn deinit(self: *@This()) void {
        self.mDeinit(self);
    }
};

pub fn genUpdaterVT(comptime T: type) Updater {
    return .{
        .mUpdate = @ptrCast(SimFn(Updater), T.update),
        .mDeinit = @ptrCast(SimFn(Updater), T.deinit),
    };
}

pub fn AsyncUpdater(comptime afn: anytype) type {
    return struct {
        vt: Updater,
        allocator: *std.mem.Allocator,
        frame: @Frame(afn),
        flag: bool,

        fn init(param: anytype, allocator: *std.mem.Allocator) !*@This() {
            var ret = try allocator.create(@This());
            ret.vt = genUpdaterVT(@This());
            ret.allocator = allocator;
            ret.flag = false;
            ret.frame = async afn(param, &ret.flag);
            return ret;
        }

        fn update(self: *@This()) void {
            resume self.frame;
        }

        fn deinit(self: *@This()) void {
            self.flag = true;
            resume self.frame;
            self.allocator.destroy(self);
        }
    };
}

pub const UpdateManager = struct {
    allocator: *std.mem.Allocator,
    queues: std.ArrayList(*Updater),

    pub fn init(allocator: *std.mem.Allocator) @This() {
        return .{
            .allocator = allocator,
            .queues = std.ArrayList(*Updater).init(allocator),
        };
    }

    pub fn add(self: *@This(), updater: *Updater) !void {
        try self.queues.append(updater);
    }

    pub fn addFn(self: *@This(), comptime f: anytype, param: anytype) !void {
        var temp = try AsyncUpdater(f).init(param, self.allocator);
        errdefer temp.deinit();
        try self.queues.append(&temp.vt);
    }

    pub fn update(self: *@This()) void {
        for (self.queues.items) |item| {
            item.update();
        }
    }

    pub fn deinit(self: *@This()) void {
        for (self.queues.items) |item| {
            item.deinit();
        }
        self.queues.deinit();
    }
};
