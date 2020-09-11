pub const TestingBlock = struct {
    isAir: bool = true,
    pub fn solid(self: *const @This()) bool {
        return !self.isAir;
    }

    pub fn setAir(self: *@This()) void {
        self.isAir = true;
    }

    pub fn setBlock(self: *@This()) void {
        self.isAir = false;
    }

    pub fn init() @This() {
        return .{};
    }
};
