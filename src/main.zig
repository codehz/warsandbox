const std = @import("std");
const block = @import("./block.zig");
const chunk = @import("./chunk.zig");
const map = @import("./map.zig");
const common = @import("./common.zig");
const sche = @import("./scheduler.zig");
usingnamespace @import("./utils.zig");
const ecs = @import("./ecs/ecs.zig");
const C = @import("./components.zig");
const console = @import("./console.zig");
usingnamespace @import("./engine.zig");

pub const log = console.zlog;

const chunkWidth = 16;
const chunkHeight = 32;
const width = 4;
const length = 16;
const TestingMap = map.Map(chunk.Chunk(block.TestingBlock, chunkWidth, chunkHeight), width, length);

const MapInfo = extern struct {
    chunkWidth: u32 = chunkWidth,
    chunkHeight: u32 = chunkHeight,
    width: u32 = width,
    length: u32 = length,
};

const ExportedPosition = extern struct {
    dataCount: u32,
    dataOffset: u32,
    indicesCount: u32,
    indicesOffset: u32,
    data: [chunkWidth * chunkWidth * chunkHeight * 192]f32,
    indices: [chunkWidth * chunkWidth * chunkHeight * 6 * 6]u32,

    fn reset(self: *@This()) void {
        self.dataCount = 0;
        self.dataOffset = @byteOffsetOf(@This(), "data");
        self.indicesCount = 0;
        self.indicesOffset = @byteOffsetOf(@This(), "indices");
    }

    fn push(self: *@This(), group: u32, arr: anytype, indices: anytype) void {
        const base = self.dataCount;
        for (arr) |val| {
            self.data[self.dataCount] = val;
            self.dataCount += 1;
        }
        for (indices) |val| {
            self.indices[self.indicesCount] = val + base / group;
            self.indicesCount += 1;
        }
    }
};

const CameraInfo = extern struct {
    posrot: [5]f32,
};

export var mapInfo: MapInfo = .{};
export var cameraInfo: CameraInfo = undefined;
var exported: [width * length]ExportedPosition = undefined;
var testingMap: TestingMap = undefined;
var registry: ecs.Registry = undefined;
var player: ecs.Entity = undefined;
var engine: Engine(TestingMap) = undefined;

export fn initEngine() void {
    engine = Engine(TestingMap).init(std.heap.page_allocator, &testingMap);
}

export fn deinitEngine() void {
    engine.deinit();
}

export fn initPlayer() void {
    player = engine.initPlayer(.{
        .pos = .{
            .x = 0,
            .y = 0,
            .z = 32,
        },
    });
}

export fn tick() bool {
    engine.update();
    // var grView = registry.view(.{ C.Velocity, C.Position, C.Physics }, .{});
    // var grIter = grView.iterator();
    // while (grIter.next()) |e| {
    //     var vel = grView.get(C.Velocity, e);
    //     const phys = grView.get(C.Physics, e);
    //     vel.z -= phys.gravity;
    // }
    // var vpIter = state.vpGroup.iterator(struct { vel: *C.Velocity, pos: *C.Position });
    // while (vpIter.next()) |e| {
    //     e.pos.x += e.vel.x;
    //     e.pos.y += e.vel.y;
    //     e.pos.z += e.vel.z;
    // }
    // var camView = registry.view(.{ C.ControlByPlayer, C.Position, C.Faced }, .{});
    // var camIter = camView.iterator();
    // if (camIter.next()) |e| {
    //     const pos = registry.getConst(C.Position, e);
    //     const faced = registry.getConst(C.Faced, e);
    //     cameraInfo.posrot = [_]f32{ pos.x, pos.y, pos.z, faced.yaw, faced.pitch };
    // }
    return true;
}

export fn loadSampleMap() bool {
    var prng = std.rand.DefaultPrng.init(0);
    testingMap = TestingMap.init();
    for (range(u16, length * chunkWidth)) |i| {
        for (range(u16, width * chunkWidth)) |j| {
            for (range(u8, 8)) |k| {
                testingMap.accessBlock(i, j, k).*.isAir = prng.random.float(f32) > (1 - @intToFloat(f32, k) / 2);
            }
        }
    }
    return testingMap.accessBlock(0, 0, 0).*.isAir;
}

export fn generateGeomentryDataForChunk(x: u8, y: u8) *ExportedPosition {
    const current = testingMap.access(x, y);
    const ret = &exported[x + y * length];
    ret.reset();
    for (range(u8, chunkWidth)) |i| {
        for (range(u8, chunkWidth)) |j| {
            for (range(u8, chunkHeight)) |k| {
                if (!current.access(i, j, k).isAir) {
                    for (rangeEnum(common.Direction)) |dir| {
                        if (current.accessNeighbor(i, j, k, dir)) |neighbor| {
                            if (!neighbor.isAir) continue;
                        }
                        ret.push(8, common.fillRect([_]u32{ i, j, k }, dir, [_]f32{ 0, 0, 1 }), [_]u32{ 0, 1, 2, 2, 1, 3 });
                    }
                }
            }
        }
    }
    return ret;
}
