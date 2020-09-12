const ControlInfo = extern struct {
    move: [2]f32 = [_]f32{ 0, 0 }, // absolute
    rotate: [2]f32 = [_]f32{ 0, 0 }, // relative
    jump: bool = false, // state
    sneak: bool = false, // state
    boost: bool = false, // state
    use1: bool = false, // state
    use2: bool = false, // state
    use3: bool = false, // state
    selectedSlot: u8 = 0, // absolute
};

pub var info = ControlInfo{};

comptime {
    @export(info, .{ .name = "control" });
}
