const std = @import("std");
const block = @import("./world/block.zig");
const chunk = @import("./world/chunk.zig");
const map = @import("./world/map.zig");
const common = @import("./utils/common.zig");
const control = @import("./game/control.zig");
usingnamespace @import("./utils/utils.zig");
const C = @import("./game/components.zig");
const I = @import("./game/item.zig");
const console = @import("./introp/console.zig");
usingnamespace @import("./game/engine.zig");
usingnamespace @import("./utils/math.zig");

pub const log = console.zlog;
pub const log_level = .debug;

const chunkWidth = 16;
const chunkHeight = 32;
const width = 2;
const length = 8;
const TestingMap = map.Map(chunk.Chunk(block.SimpleBlock, chunkWidth, chunkHeight), width, length);

const MapInfo = extern struct {
    chunkWidth: usize = chunkWidth,
    chunkHeight: usize = chunkHeight,
    width: usize = width,
    length: usize = length,
};

const ExportedPosition = extern struct {
    dataCount: u32,
    indicesCount: u32,
    version: u32 = 0,
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
    data: [8]f32,
    selectedFace: DirEnum,
    inventory: [8]extern struct {
        iconid: u16,
        count: u16,
    },

    fn adjustCamera(self: *@This(), offset: f32) void {
        var camIter = engine.registry.view(struct {
            control: *C.ControlByPlayer,
            pos: *C.Position,
            vel: *C.Velocity,
            faced: *C.Faced,
        });
        if (camIter.next()) |str| {
            const pos = str.pos;
            const vel = str.vel;
            const faced = str.faced;
            const highlight = blk: {
                if (str.control.selected) |d| {
                    self.selectedFace = dir2Enum(d.direction);
                    break :blk toVector3D(d.pos);
                } else {
                    break :blk Vector3D{ -1, -1, -1 };
                }
            };
            self.data = [_]f32{
                pos.value[0] + vel.value[0] * offset,
                pos.value[1] + vel.value[1] * offset,
                pos.value[2] + vel.value[2] * offset,
                faced.yaw + control.info.rotate[0],
                minmax(faced.pitch + control.info.rotate[1], std.math.pi / -2.0, std.math.pi / 2.0),
                highlight[0],
                highlight[1],
                highlight[2],
            };
        }
    }

    fn updateCamera(self: *@This(), stopped: *bool) void {
        while (true) {
            suspend;
            if (stopped.*) return;
            var camIter = engine.registry.view(struct {
                control: *C.ControlByPlayer,
                pos: *C.Position,
                faced: *C.Faced,
            });
            if (camIter.next()) |str| {
                const pos = str.pos;
                const faced = str.faced;
                const highlight = blk: {
                    if (str.control.selected) |d| {
                        break :blk toVector3D(d.pos);
                    } else {
                        break :blk Vector3D{ -1, -1, -1 };
                    }
                };
                self.data = [_]f32{
                    pos.value[0],
                    pos.value[1],
                    pos.value[2],
                    faced.yaw,
                    faced.pitch,
                    highlight[0],
                    highlight[1],
                    highlight[2],
                };
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

export const blockTextureCount: u16 = 2;
export var blockTextureMapping: [blockTextureCount]u16 = [1]u16{0} ** blockTextureCount;
export var blockTextureBase: u16 = 4;
export var mapInfo: MapInfo = .{};
export var cameraInfo: CameraInfo = undefined;
export var particle: @import("./introp/particle.zig").ParticleManager = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{
    .thread_safe = false,
    .safety = false,
}) = .{};
var exportedMap: [width * length]ExportedPosition = undefined;
var testingMap: TestingMap = undefined;
var player: Entity = undefined;
pub var engine: Engine(TestingMap) = undefined;

comptime {
    @export(exportedMap, .{ .name = "map" });
}

export fn initEngine() void {
    particle.init();
    engine = Engine(TestingMap).init(&gpa.allocator, &testingMap);
    engine.initSystem() catch |e| {
        engine.deinit();
        reportError("Failed to init engine", e);
    };
    engine.updater.addFn(@TypeOf(particle).updateFunction, &particle) catch report("Failed to register particle updater");
}

export fn deinitEngine() void {
    engine.deinit();
}

export fn initPlayer() void {
    player = engine.initPlayer(.{
        .pos = .{ .value = .{ 0.5, 0.5, 8 } },
    }) catch unreachable;
    const inv = engine.registry.get(player, C.Inventory).?;
    inv.container.data.insert(0, I.ItemStack.init(
        &gpa.allocator,
        I.Item.createForBlock(&gpa.allocator, 1) catch report("Failed to create item"),
        64,
    )) catch report("Failed to add item");
    inv.container.data.insert(1, I.ItemStack.init(
        &gpa.allocator,
        I.Item.createForBlock(&gpa.allocator, 2) catch report("Failed to create item"),
        64,
    )) catch report("Failed to add item");
    inv.container.data.insert(2, I.ItemStack.init(
        &gpa.allocator,
        I.Item.createSimpleWeapon(&gpa.allocator, 0xFFFF00, 0.5, 0.5) catch report("Failed to create item"),
        32767,
    )) catch report("Failed to add item");

    engine.updater.addFn(CameraInfo.updateCamera, &cameraInfo) catch report("Failed to register camera updater");
}

export fn tick() void {
    engine.update();
    for (testingMap.chunks) |*current, i| {
        if (current.dirty) {
            generateGeomentryData(current, &exportedMap[i]);
            exportedMap[i].version +%= 1;
            current.dirty = false;
        }
    }
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
                testingMap.accessBlock(i, j, k).id = prng.random.uintAtMost(u16, 2);
            }
        }
    }
    return true;
}

fn generateGeomentryData(current: *TestingMap.ChunkType, exp: *ExportedPosition) void {
    exp.reset();
    for (range(u8, chunkWidth)) |i| {
        for (range(u8, chunkWidth)) |j| {
            for (range(u8, chunkHeight)) |k| {
                const cur = current.access(i, j, k);
                if (cur.solid()) {
                    for (rangeEnum(common.Direction)) |dir| {
                        if (current.accessNeighbor(i, j, k, dir)) |neighbor| {
                            if (neighbor.solid()) continue;
                        }
                        const texid = blockTextureMapping[cur.id - 1];
                        exp.push(
                            8,
                            common.fillRect(
                                [_]u32{ i, j, k },
                                dir,
                                [_]u16{
                                    @mod(texid, blockTextureBase),
                                    @divTrunc(texid, blockTextureBase),
                                    blockTextureBase,
                                },
                            ),
                            [_]u32{ 0, 1, 2, 2, 1, 3 },
                        );
                    }
                }
            }
        }
    }
}

export fn generateGeomentryDataForChunk(x: u8, y: u8) *ExportedPosition {
    const current = testingMap.access(x, y);
    const ret = &exportedMap[x + y * width];
    generateGeomentryData(current, ret);
    return ret;
}
