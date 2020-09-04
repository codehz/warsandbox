const std = @import("std");

pub fn range(comptime T: type, comptime n: comptime_int) comptime [n]T {
    var ret: [n]T = [_]T{0} ** n;
    var i: T = 0;
    while (i < n) : (i += 1) {
        ret[i] = i;
    }
    return ret;
}

pub fn rangeEnum(comptime T: type) comptime [std.meta.fields(T).len]T {
    const fields = std.meta.fields(T);
    var ret: [fields.len]T = undefined;
    inline for (std.meta.fields(T)) |field, i| {
        ret[i] = @intToEnum(T, field.value);
    }
    return ret;
}