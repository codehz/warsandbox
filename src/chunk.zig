const common = @import("./common.zig");

pub fn Chunk(comptime mBlockType: type, mWidth: u8, mHeight: u8) type {
    return struct {
        pub const BlockType = mBlockType;
        pub const width: usize = mWidth;
        pub const height: usize = mHeight;

        data: [width * width * height]BlockType = undefined,
        dirty: bool = false,

        pub fn init() @This() {
            var ret: @This() = .{};
            for (ret.data) |*blk| {
                blk.* = BlockType.init();
            }
            return ret;
        }

        pub fn access(self: *@This(), x: u8, y: u8, z: u8) *BlockType {
            return &self.data[x + width * y + width * width * z];
        }

        pub fn accessNeighbor(self: *@This(), x: u8, y: u8, z: u8, dir: common.Direction) ?*BlockType {
            switch (dir) {
                .Down => if (z == 0) {
                    return null;
                } else {
                    return self.access(x, y, z - 1);
                },
                .Up => if (z == height - 1) {
                    return null;
                } else {
                    return self.access(x, y, z + 1);
                },
                .Left => if (x == 0) {
                    return null;
                } else {
                    return self.access(x - 1, y, z);
                },
                .Right => if (x == width - 1) {
                    return null;
                } else {
                    return self.access(x + 1, y, z);
                },
                .Backward => if (y == 0) {
                    return null;
                } else {
                    return self.access(x, y - 1, z);
                },
                .Forward => if (y == width - 1) {
                    return null;
                } else {
                    return self.access(x, y + 1, z);
                },
            }
        }
    };
}
