const std = @import("std");
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

pub fn toBlockPos(src: Vector3D) BlockPos {
    return .{
        @floatToInt(u16, src[0] - 0.5),
        @floatToInt(u16, src[1] - 0.5),
        @floatToInt(u16, src[2] - 0.5),
    };
}

pub fn toVector3D(src: BlockPos) Vector3D {
    return .{
        @intToFloat(f32, src[0]) + 0.5,
        @intToFloat(f32, src[1]) + 0.5,
        @intToFloat(f32, src[2]) + 0.5,
    };
}
