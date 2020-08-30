pub const TestingBlock = struct {
    isAir: bool = true,

    pub fn init() @This() {
        return .{};
    }
};
