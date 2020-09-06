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
pub const log_level = .debug;

const chunkWidth = 16;
const chunkHeight = 32;
const width = 2;
const length = 4;
const TestingMap = map.Map(chunk.Chunk(block.TestingBlock, chunkWidth, chunkHeight), width, length);

const MapInfo = extern struct {
    chunkWidth: usize = chunkWidth,
    chunkHeight: usize = chunkHeight,
    width: usize = width,
    length: usize = length,
};

const ExportedPosition = extern struct {
    dataCount: u32,
    indicesCount: u32,
    data: [chunkWidth * chunkWidth * chunkHeight * 192]f32,
    indices: [chunkWidth * chunkWidth * chunkHeight * 6 * 6]u32,

    fn reset(self: *@This()) void {
        self.dataCount = 0;
        self.indicesCount = 0;
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

    fn adjustCamera(self: *@This(), offset: f32) void {
        var camView = engine.registry.view(.{ C.ControlByPlayer, C.Velocity, C.Position, C.Faced }, .{});
        var camIter = camView.iterator();
        if (camIter.next()) |e| {
            const pos = engine.registry.getConst(C.Position, e);
            const vel = engine.registry.getConst(C.Velocity, e);
            const faced = engine.registry.getConst(C.Faced, e);
            self.posrot = [_]f32{
                pos.value[0] + vel.value[0] * offset,
                pos.value[1] + vel.value[1] * offset,
                pos.value[2] + vel.value[2] * offset,
                faced.yaw,
                faced.pitch,
            };
        }
    }

    fn updateCamera(self: *@This(), stopped: *bool) void {
        var camView = engine.registry.view(.{ C.ControlByPlayer, C.Position, C.Faced }, .{});
        while (true) {
            suspend;
            if (stopped.*) return;
            var camIter = camView.iterator();
            if (camIter.next()) |e| {
                const pos = engine.registry.getConst(C.Position, e);
                const faced = engine.registry.getConst(C.Faced, e);
                self.posrot = [_]f32{ pos.value[0], pos.value[1], pos.value[2], faced.yaw, faced.pitch };
            }
        }
    }
};

fn report(comptime str: []const u8) noreturn {
    std.log.err("ERROR: {}", .{str});
    unreachable;
}

fn reportError(comptime str: []const u8, e: anytype) noreturn {
    std.log.err("ERROR: {} {}", .{ str, e });
    unreachable;
}

export var mapInfo: MapInfo = .{};
export var cameraInfo: CameraInfo = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{
    .thread_safe = false,
    .safety = false,
}) = .{};
export var exported: [width * length]ExportedPosition = undefined;
var testingMap: TestingMap = undefined;
var player: ecs.Entity = undefined;
var engine: Engine(TestingMap) = undefined;

export fn initEngine() void {
    engine = Engine(TestingMap).init(&gpa.allocator, &testingMap);
    engine.initSystem() catch |e| {
        engine.deinit();
        reportError("Failed to init engine", e);
    };
}

export fn deinitEngine() void {
    engine.deinit();
}

export fn initPlayer() void {
    player = engine.initPlayer(.{
        .pos = .{ .value = .{ 0.5, 0.5, 8 } },
    });

    engine.updater.addFn(CameraInfo.updateCamera, &cameraInfo) catch report("Failed to register camera updater");
}

export fn tick() bool {
    engine.update();
    return true;
}

export fn microtick(offset: f32) void {
    cameraInfo.adjustCamera(offset);
}

export fn loadSampleMap() bool {
    var prng = std.rand.DefaultPrng.init(0);
    testingMap = TestingMap.init();
    for (range(u16, width * chunkWidth)) |i| {
        for (range(u16, length * chunkWidth)) |j| {
            for (range(u8, 8)) |k| {
                testingMap.accessBlock(i, j, k).*.isAir = prng.random.float(f32) > (1 - @intToFloat(f32, k) / 8);
            }
        }
    }
    return testingMap.accessBlock(0, 0, 0).*.isAir;
}

export fn generateGeomentryDataForChunk(x: u8, y: u8) *ExportedPosition {
    const current = testingMap.access(x, y);
    const ret = &exported[x + y * width];
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
