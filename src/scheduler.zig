const std = @import("std");

pub const Process = struct {
    allocator: *std.mem.Allocator,
    stopsignal: bool,
    dead: bool,

    fn Bundle(comptime Frame: type) type {
        const Origin = @This();
        return struct {
            data: Origin,
            frame: Frame,
        };
    }

    pub fn create(allocator: *std.mem.Allocator, comptime f: anytype, args: anytype) !*@This() {
        var ret = try allocator.create(Bundle(@Frame(f)));
        ret.data.allocator = allocator;
        ret.data.stopsignal = false;
        ret.data.dead = false;
        ret.frame = async f(&ret.data, args);
        return &ret.data;
    }

    fn getFrame(self: *@This()) anyframe {
        return @intToPtr(anyframe, @ptrToInt(self) + @sizeOf(@This()));
    }

    pub fn cont(self: *@This()) bool {
        if (self.dead) return true;
        resume self.getFrame();
        return self.dead;
    }

    pub fn stop(self: *@This()) void {
        self.stopsignal = true;
        while (!self.dead) {
            resume self.getFrame();
        }
    }

    pub fn deinit(self: *@This()) void {
        self.stop();
        self.allocator.destroy(self);
    }
};

pub const Scheduler = struct {
    processes: std.ArrayList(*Process),
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) @This() {
        return .{
            .processes = std.ArrayList(*Process).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn add(self: *@This(), comptime f: anytype, arg: anytype) !void {
        var proc = try Process.create(self.allocator, f, arg);
        errdefer proc.deinit();
        try self.processes.append(proc);
    }

    pub fn update(self: *@This()) void {
        for (self.processes.items) |item| {
            _ = item.cont();
        }
    }

    pub fn cleanDead(self: *@This()) void {
        var i: usize = 0;
        var dr = self.processes.items.len;
        while (i < self.processes.items.len) : (i += 1) {
            if (self.processes.items[i].dead) {
                if (dr > i) {
                    dr = i;
                }
                self.processes.items[dr].deinit();
            } else if (dr < i) {
                self.processes.items[dr] = self.processes.items[i];
                dr += 1;
            }
        }
        if (dr != self.processes.items.len) {
            self.processes.shrinkRetainingCapacity(dr);
        }
    }

    pub fn clear(self: *@This()) void {
        for (self.processes.items) |item| {
            item.deinit();
        }
        self.processes.shrinkRetainingCapacity(0);
    }

    pub fn deinit(self: *@This()) void {
        self.clear();
        self.processes.deinit();
    }
};