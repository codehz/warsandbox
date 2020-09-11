const std = @import("std");
const utils = @import("./utils.zig");

pub const Vector3D = [3]f32;
pub const BlockPos = [3]u16;
pub const Dir3D = [3]i2;
pub const Bound3D = struct {
    value: [3][2]f32,
    pub fn init() @This() {
        return .{
            .value = .{
                .{ -std.math.inf_f32, std.math.inf_f32 },
                .{ -std.math.inf_f32, std.math.inf_f32 },
                .{ -std.math.inf_f32, std.math.inf_f32 },
            },
        };
    }

    pub fn initBase(xmin: f32, xmax: f32, ymin: f32, ymax: f32, zmin: f32, zmax: f32) @This() {
        return .{
            .value = .{
                .{ xmin, xmax },
                .{ ymin, ymax },
                .{ zmin, zmax },
            },
        };
    }

    pub fn limit(self: *@This(), i: u32, p: bool, raw: anytype) void {
        const value = @intToFloat(f32, raw);
        if (p) {
            if (self.value[i][1] > value) self.value[i][1] = value;
        } else {
            if (self.value[i][0] < value) self.value[i][0] = value;
        }
    }

    pub fn mergeDirection(self: *@This(), i: u32, p: bool, rhs: *const @This()) void {
        if (p) {
            self.value[i][1] = std.math.min(self.value[i][1], rhs.value[i][1]);
        } else {
            self.value[i][0] = std.math.max(self.value[i][0], rhs.value[i][0]);
        }
    }

    pub fn mergeAxis(self: *@This(), i: u32, rhs: *const @This()) void {
        self.value[i][0] = std.math.max(self.value[i][0], rhs.value[i][0]);
        self.value[i][1] = std.math.min(self.value[i][1], rhs.value[i][1]);
    }

    pub fn apply(self: *const @This(), pos: *Vector3D) void {
        for (pos) |*val, dim| {
            val.* = minmax(val.*, self.value[dim][0], self.value[dim][1]);
        }
    }

    pub fn applyAxis(self: *const @This(), i: u32, input: f32) f32 {
        return minmax(input, self.value[i][0], self.value[i][1]);
    }

    pub fn applyAABB(self: *const @This(), aabb: Vector3D, pos: *Vector3D, vel: *Vector3D) void {
        for (pos) |*val, dim| {
            const new = if (dim == 2)
                minmax(val.*, self.value[dim][0], self.value[dim][1] - aabb[2])
            else
                minmax(val.*, self.value[dim][0] + aabb[dim], self.value[dim][1] - aabb[dim]);
            if (val.* != new) vel[dim] = 0;
            val.* = new;
        }
    }

    pub fn inbound(self: *const @This(), target: anytype) bool {
        if (@typeInfo(@TypeOf(target[0])) != .Float) {
            for (target) |val, dim| {
                const v = @intToFloat(f32, val);
                if (v < self.value[dim][0] or v >= self.value[dim][1]) return false;
            }
        } else {
            for (target) |val, dim| {
                const v = if (@typeInfo(@TypeOf(val)) != .Float) @intToFloat(f32, val) else @floatCast(f32, val);
                if (v < self.value[dim][0] or v > self.value[dim][1]) return false;
            }
        }
        return true;
    }

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        return std.fmt.format(writer, "[<{d:.1}, {d:.1}> <{d:.1}, {d:.1}> <{d:.1}, {d:.1}>]", .{
            self.value[0][0],
            self.value[0][1],
            self.value[1][0],
            self.value[1][1],
            self.value[2][0],
            self.value[2][1],
        });
    }
};
pub const AABB = struct {
    float: [3][2]f32,
    xrange: [2]u16,
    yrange: [2]u16,
    zrange: [2]u8,

    pub fn fromEntityPosBox(pos: [3]f32, box: [2]f32, bound: Bound3D) @This() {
        var ret: @This() = undefined;
        inline for (comptime utils.range(usize, 3)) |i| {
            if (i != 2) {
                const range = if (i == 0) &ret.xrange else &ret.yrange;
                ret.float[i][0] = bound.applyAxis(i, pos[i] - box[0]);
                range[0] = @floatToInt(u16, ret.float[i][0]);
                ret.float[i][1] = bound.applyAxis(i, pos[i] + box[0]);
                range[1] = @floatToInt(u16, ret.float[i][1]);
            } else {
                const range = &ret.zrange;
                ret.float[i][0] = bound.applyAxis(i, pos[i]);
                range[0] = @floatToInt(u8, ret.float[i][0]);
                ret.float[i][1] = bound.applyAxis(i, pos[i] + box[1]);
                range[1] = @floatToInt(u8, ret.float[i][1]);
            }
        }
        return ret;
    }

    pub const Iterator = struct {
        parent: *const AABB,
        step: enum { uninit, running, done } = .uninit,
        result: Result = undefined,
        frame: @Frame(loop) = undefined,

        pub const Result = struct {
            x: u16,
            y: u16,
            z: u8,

            pub fn get(self: @This(), comptime i: comptime_int) if (i == 2) u8 else u16 {
                return switch (i) {
                    0 => self.x,
                    1 => self.y,
                    2 => self.z,
                    else => unreachable,
                };
            }

            pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
                return std.fmt.format(writer, "({} {} {})", .{ self.x, self.y, self.z });
            }
        };

        pub fn init(parent: *const AABB) @This() {
            return .{ .parent = parent };
        }

        fn loop(self: *@This()) void {
            self.step = .running;
            defer self.step = .done;
            self.result.x = self.parent.xrange[0];
            while (self.result.x <= self.parent.xrange[1]) : (self.result.x += 1) {
                self.result.y = self.parent.yrange[0];
                while (self.result.y <= self.parent.yrange[1]) : (self.result.y += 1) {
                    self.result.z = self.parent.zrange[0];
                    while (self.result.z <= self.parent.zrange[1]) : (self.result.z += 1) {
                        suspend;
                    }
                }
            }
        }

        pub fn next(self: *@This()) ?Result {
            if (self.step == .done) return null;
            if (self.step == .uninit) {
                self.frame = async self.loop();
            } else {
                resume self.frame;
            }
            if (self.step == .done) return null;
            return self.result;
        }
    };

    pub fn iterator(self: *const @This()) Iterator {
        return Iterator.init(self);
    }
};
pub const Ray3D = struct {
    origin: Vector3D,
    direction: Vector3D,

    pub fn getOriginBlockPos(self: *const @This()) BlockPos {
        return toBlockPos(self.origin);
    }

    fn mapOrder(order: std.math.Order) i8 {
        return switch (order) {
            .lt => -1,
            .eq => 0,
            .gt => 1,
        };
    }

    fn safeConvert(im: [3]i32) ?BlockPos {
        var ret: BlockPos = undefined;
        for (im) |v, i| {
            if (v < 0 or v > std.math.maxInt(u16)) return null;
            ret[i] = @intCast(u16, v);
        }
        return ret;
    }

    fn loop(self: *const @This(), state: *Iterator) void {
        state.stage = 1;
        defer state.stage = 2;
        suspend;
        // output
        var current = [3]i32{
            @floatToInt(i32, self.origin[0]),
            @floatToInt(i32, self.origin[1]),
            @floatToInt(i32, self.origin[2]),
        };
        // internal
        const diff = [3]f32{
            self.origin[0] - std.math.floor(self.origin[0]),
            self.origin[1] - std.math.floor(self.origin[1]),
            self.origin[2] - std.math.floor(self.origin[2]),
        };
        state.current = safeConvert(current).?;
        // internal
        const stepF = [3]f32{
            if (std.math.signbit(self.direction[0])) -1 else 1,
            if (std.math.signbit(self.direction[1])) -1 else 1,
            if (std.math.signbit(self.direction[2])) -1 else 1,
        };
        const step = [3]i32{
            @floatToInt(i32, stepF[0]),
            @floatToInt(i32, stepF[1]),
            @floatToInt(i32, stepF[2]),
        };
        const tdelta = [3]f32{
            std.math.fabs(1.0 / self.direction[0]),
            std.math.fabs(1.0 / self.direction[1]),
            std.math.fabs(1.0 / self.direction[2]),
        };
        var tmax = [3]f32{
            std.math.fabs(((stepF[0] + 1) / 2 - (stepF[0] * diff[0])) / self.direction[0]),
            std.math.fabs(((stepF[1] + 1) / 2 - (stepF[1] * diff[1])) / self.direction[1]),
            std.math.fabs(((stepF[2] + 1) / 2 - (stepF[2] * diff[2])) / self.direction[2]),
        };
        suspend;
        while (true) {
            const mi = utils.minIndex(f32, tmax[0..]);
            current[mi] += step[mi];
            state.time = tmax[mi];
            tmax[mi] += tdelta[mi];
            state.current = safeConvert(current) orelse return;
            suspend;
        }
    }

    const Self = @This();

    const Iterator = struct {
        parent: *const Self,
        frame: @Frame(loop) = undefined,
        stage: usize = 0,
        time: f32 = 0,
        current: BlockPos = undefined,

        pub fn next(self: *@This()) ?BlockPos {
            if (self.stage == 2) return null;
            if (self.stage == 0) self.frame = async self.parent.loop(self);
            resume self.frame;
            if (self.stage == 2) return null;
            return self.current;
        }
    };

    pub fn iterator(self: *const @This()) Iterator {
        return .{ .parent = self };
    }
};

pub fn minmax(source: anytype, min: anytype, max: anytype) @TypeOf(source) {
    return std.math.min(std.math.max(source, min), max);
}

fn dirAbs(x: f32) i2 {
    if (x > 0) return 1;
    if (x < 0) return -1;
    return 0;
}

pub fn toDir3D(vec: Vector3D) Dir3D {
    return .{
        dirAbs(vec[0]),
        dirAbs(vec[1]),
        dirAbs(vec[2]),
    };
}

pub fn invertDir3D(vec: Dir3D) Dir3D {
    return .{
        -vec[0],
        -vec[1],
        -vec[2],
    };
}

pub fn add3d(a: anytype, b: anytype) blk: {
    std.testing.expectEqual(@TypeOf(a), @TypeOf(b));
    std.testing.expect(@TypeOf(a) == Vector3D or @TypeOf(a) == BlockPos);
    break :blk @TypeOf(a);
} {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}

pub fn sub3d(a: anytype, b: anytype) blk: {
    std.testing.expectEqual(@TypeOf(a), @TypeOf(b));
    std.testing.expect(@TypeOf(a) == Vector3D or @TypeOf(a) == BlockPos);
    break :blk @TypeOf(a);
} {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

pub fn distance3d(v: Vector3D) f32 {
    return std.math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

pub fn morph3d(a: Vector3D, b: Vector3D, t: f32) Vector3D {
    return .{
        (b[0] - a[0]) * t + a[0],
        (b[1] - a[1]) * t + a[1],
        (b[2] - a[2]) * t + a[2],
    };
}

pub fn toBlockPos(src: anytype) BlockPos {
    return .{
        @floatToInt(u16, src[0]),
        @floatToInt(u16, src[1]),
        @floatToInt(u16, src[2]),
    };
}

pub fn toVector3D(src: anytype) Vector3D {
    return .{
        @intToFloat(f32, src[0]),
        @intToFloat(f32, src[1]),
        @intToFloat(f32, src[2]),
    };
}
