const std = @import("std");

extern "console" fn console_debug(data: [*]const u8, len: u32) void;
extern "console" fn console_info(data: [*]const u8, len: u32) void;
extern "console" fn console_log(data: [*]const u8, len: u32) void;
extern "console" fn console_warn(data: [*]const u8, len: u32) void;
extern "console" fn console_error(data: [*]const u8, len: u32) void;

fn logWrite(context: std.log.Level, bytes: []const u8) error{}!usize {
    const f = switch (context) {
        .debug => console_debug,
        .info => console_info,
        .notice => console_log,
        .warn => console_warn,
        else => console_error,
    };
    f(bytes.ptr, bytes.len);
    return bytes.len;
}

const LogWriter = std.io.Writer(std.log.Level, error{}, logWrite);

pub fn zlog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const writer = LogWriter{ .context = message_level };
    var buffered = std.io.bufferedWriter(writer);
    defer buffered.flush() catch unreachable;
    buffered.writer().print(format, args) catch return;
}
