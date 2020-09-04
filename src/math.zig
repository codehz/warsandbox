const std = @import("std");
pub const Vector3D = [3]f32;
pub const BlockPos = [3]u16;
pub const Dir3D = [3]i2;

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
