const chunk = @import("./chunk.zig");
usingnamespace @import("./math.zig");

pub fn Map(comptime mChunkType: type, mWidth: u8, mLength: u8) type {
    return struct {
        pub const width: usize = mWidth;
        pub const length: usize = mLength;
        pub const totalChunks: u16 = width * length;
        pub const ChunkType = mChunkType;

        chunks: [totalChunks]ChunkType = undefined,

        pub fn init() @This() {
            var ret: @This() = .{};
            for (ret.chunks) |*blk| {
                blk.* = ChunkType.init();
            }
            return ret;
        }

        pub fn access(self: *@This(), cx: u8, cy: u8) *ChunkType {
            return &self.chunks[cx * width + cy];
        }
        pub fn accessChunk(self: *@This(), x: u16, y: u16) struct {
            chunk: *ChunkType,
            mx: u8,
            my: u8,
        } {
            const cx = @intCast(u8, x / ChunkType.width);
            const cy = @intCast(u8, y / ChunkType.width);
            const mx = @intCast(u8, x % ChunkType.width);
            const my = @intCast(u8, y % ChunkType.width);
            return .{
                .chunk = self.access(cx, cy),
                .mx = mx,
                .my = my,
            };
        }
        pub fn accessBlock(self: *@This(), x: u16, y: u16, z: u8) *ChunkType.BlockType {
            const data = self.accessChunk(x, y);
            return data.chunk.access(data.mx, data.my, z);
        }
        pub fn checkBlockFace(self: *@This(), x: u16, y: u16, z: u8, dir: *Dir3D) void {
            //x
            if (dir[0] < 0) {
                dir[0] = if (x == 0 or self.accessBlock(x - 1, y, z).solid()) 0 else dir[0];
            } else if (dir[0] > 0) {
                dir[0] = if (x == width * ChunkType.width or self.accessBlock(x + 1, y, z).solid()) 0 else dir[0];
            }
            // y
            if (dir[1] < 0) {
                dir[1] = if (y == 0 or self.accessBlock(x, y - 1, z).solid()) 0 else dir[1];
            } else if (dir[1] > 0) {
                dir[1] = if (y == length * ChunkType.width or self.accessBlock(x, y + 1, z).solid()) 0 else dir[1];
            }
            // z
            if (dir[2] < 0) {
                dir[2] = if (z == 0 or self.accessBlock(x, y, z - 1).solid()) 0 else dir[2];
            } else if (dir[2] > 0) {
                dir[2] = if (z == ChunkType.height or self.accessBlock(x, y, z + 1).solid()) 0 else dir[2];
            }
        }
    };
}
