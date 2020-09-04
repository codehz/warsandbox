pub const TestingBlock = struct {
    isAir: bool = true,
    pub fn solid(self: *const @This()) bool {
        return !self.isAir;
    }

    pub fn init() @This() {
        return .{};
    }
};
