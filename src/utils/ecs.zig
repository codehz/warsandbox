const std = @import("std");
const builtin = std.builtin;
const srb = @import("./srb.zig");

fn getTypeCount(comptime components: anytype) comptime_int {
    switch (@typeInfo(components)) {
        .Array => |arr| return arr.len,
        .Struct => |str| {
            if (str.is_tuple) {
                return str.fields.len;
            } else {
                return str.decls.len;
            }
        },
        else => @compileError("not support"),
    }
}

fn toTypeArray(comptime components: anytype) [getTypeCount(components)]type {
    switch (@typeInfo(components)) {
        .Array => |x| return x,
        .Struct => |str| {
            var ret: [getTypeCount(components)]type = undefined;
            if (str.is_tuple) {
                inline for (components) |t, i| {
                    ret[i] = t;
                }
            } else {
                inline for (str.decls) |decl, i| {
                    ret[i] = decl.data.Type;
                }
            }
            return ret;
        },
        else => @compileError("not support"),
    }
}

pub fn Registry(comptime components: anytype, comptime Entity: type) type {
    const types = toTypeArray(components);
    const emptyDecls = [_]builtin.TypeInfo.Declaration{};
    comptime var fields: [types.len]builtin.TypeInfo.StructField = undefined;
    inline for (types) |t, i| {
        fields[i] = .{
            .name = @typeName(t),
            .field_type = srb.AutoTreeMapUnmanaged(Entity, t),
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(srb.AutoTreeMapUnmanaged(Entity, t)),
        };
    }
    const Storage = @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = fields[0..],
            .decls = emptyDecls[0..],
            .is_tuple = false,
        },
    });
    return struct {
        const RegistrySelf = @This();

        allocator: *std.mem.Allocator,
        storage: Storage = undefined,
        last_id: Entity = 0,

        pub fn init(allocator: *std.mem.Allocator) @This() {
            var ret: @This() = .{ .allocator = allocator };
            inline for (types) |t| {
                @field(ret.storage, @typeName(t)) = .{};
            }
            return ret;
        }

        pub fn deinit(self: *@This()) void {
            inline for (types) |t| {
                @field(self.storage, @typeName(t)).deinit(self.allocator);
            }
        }

        pub fn create(self: *@This()) Entity {
            defer self.last_id += 1;
            return self.last_id;
        }

        pub fn set(self: *@This(), e: Entity, comptime ct: type) !*ct {
            const ctn = @typeName(ct);
            return @field(self.storage, ctn).set(self.allocator, e);
        }

        pub fn add(self: *@This(), e: Entity, component: anytype) !void {
            const ct = @TypeOf(component);
            const ctn = @typeName(ct);
            return @field(self.storage, ctn).insert(self.allocator, e, component);
        }

        pub fn remove(self: *@This(), e: Entity, comptime ct: type) void {
            const ctn = @typeName(ct);
            _ = @field(self.storage, ctn).remove(self.allocator, e);
        }

        pub fn destroy(self: *@This(), e: Entity) void {
            inline for (types) |t| {
                self.remove(e, t);
            }
        }

        pub fn get(self: *@This(), e: Entity, comptime ct: type) ?*ct {
            const ctn = @typeName(ct);
            return @field(self.storage, ctn).find(e);
        }

        pub fn iterator(self: *@This(), comptime ct: type) srb.FieldType(Storage, @typeName(ct)).Iterator {
            const ctn = @typeName(ct);
            return @field(self.storage, ctn).iterator();
        }

        fn ViewIterator(comptime field: builtin.TypeInfo.StructField) type {
            comptime var isOptional = false;
            const ct = switch (@typeInfo(field.field_type)) {
                .Pointer => |ptr| ptr.child,
                .Optional => |opt| blk: {
                    isOptional = true;
                    break :blk @typeInfo(opt.child).Pointer.child;
                },
                else => @compileError("Unknown type"),
            };
            const ctn = @typeName(ct);
            const ft = srb.FieldType(Storage, @typeName(ct));
            return struct {
                iter: ft.Iterator,
                source: *ft,
                last: ?*ft.KV = null,

                const optional = isOptional;

                fn jump(self: *@This(), key: Entity) bool {
                    if (self.source.lookup(key)) |kv| {
                        self.last = kv;
                        self.iter.node = &kv.node;
                        return true;
                    }
                    return false;
                }

                fn peek(self: *@This()) ?Entity {
                    if (self.last) |last| return last.key;
                    self.last = self.iter.next();
                    return (self.last orelse return null).key;
                }

                fn next(self: *@This()) ?Entity {
                    self.last = self.iter.next();
                    return (self.last orelse return null).key;
                }

                fn fetch(self: *@This()) *ct {
                    // caller should call peek at first
                    const last = self.last.?;
                    self.last = self.iter.next();
                    return &last.value;
                }
            };
        }

        fn View(comptime Item: type) type {
            const itemFields = @typeInfo(Item).Struct.fields;
            comptime {
                std.debug.assert(itemFields.len > 0);
            }
            var iterators: [itemFields.len]builtin.TypeInfo.StructField = undefined;
            inline for (itemFields) |field, i| {
                const ct = switch (@typeInfo(field.field_type)) {
                    .Pointer => |ptr| ptr.child,
                    .Optional => |opt| @typeInfo(opt.child).Pointer.child,
                    else => @compileError("Unknown type"),
                };
                const ctn = @typeName(ct);
                iterators[i] = .{
                    .name = ctn,
                    .field_type = ViewIterator(field),
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(ViewIterator(field)),
                };
            }
            const Iterators = @Type(.{
                .Struct = .{
                    .layout = .Auto,
                    .fields = iterators[0..],
                    .decls = emptyDecls[0..],
                    .is_tuple = false,
                },
            });
            return struct {
                iters: Iterators,
                entity: Entity = undefined,

                fn init(storage: *Storage) @This() {
                    var ret: @This() = .{ .iters = undefined };
                    inline for (iterators) |def, i| {
                        @field(ret.iters, def.name) = .{ .source = &@field(storage, def.name), .iter = @field(storage, def.name).iterator() };
                    }
                    return ret;
                }

                pub fn next(self: *@This()) ?Item {
                    out: while (true) {
                        var ret: Item = undefined;
                        var ent: ?Entity = null;
                        inline for (iterators) |def, i| {
                            var iter = &@field(self.iters, def.name);
                            if (iterators[i].field_type.optional) {
                                const e = ent.?;
                                var skip = false;
                                if (iter.peek()) |current| {
                                    if (iter.jump(e)) {
                                        @field(ret, itemFields[i].name) = iter.fetch();
                                    } else {
                                        @field(ret, itemFields[i].name) = null;
                                    }
                                }
                            } else {
                                const current = iter.peek() orelse return null;
                                if (ent) |e| {
                                    const re = std.math.order(current, e);
                                    if (re == .lt) {
                                        if (!iter.jump(e)) {
                                            continue :out;
                                        }
                                    } else if (re == .gt) {
                                        continue :out;
                                    }
                                    @field(ret, itemFields[i].name) = iter.fetch();
                                } else {
                                    ent = current;
                                    @field(ret, itemFields[i].name) = iter.fetch();
                                }
                            }
                        }
                        self.entity = ent.?;
                        return ret;
                    }
                }
            };
        }

        pub fn view(self: *@This(), comptime Item: type) View(Item) {
            return View(Item).init(&self.storage);
        }
    };
}

test "Basic test" {
    const t = std.testing;
    const components = struct {
        const A = struct {};
        const B = struct {};
        const C = struct {};
    };

    const Reg = Registry(components, u8);
    var reg = Reg.init(t.allocator);
    defer reg.deinit();
    const e0 = reg.create();
    const e1 = reg.create();
    const e2 = reg.create();
    t.expect(e0 != e1 and e1 != e2);

    try reg.add(e0, components.A{});
    t.expectError(error.Overlapped, reg.add(e0, components.A{}));

    try reg.add(e0, components.B{});
    t.expect(reg.get(e0, components.A) != null);
    t.expect(reg.get(e0, components.B) != null);
    t.expect(reg.get(e0, components.C) == null);

    var it = reg.iterator(components.A);
    t.expect(it.next() != null);
    t.expect(it.next() == null);

    try reg.add(e1, components.A{});
    t.expect(reg.get(e1, components.A) != null);

    var it2 = reg.iterator(components.A);
    t.expect(it2.next() != null);
    t.expect(it2.next() != null);
    t.expect(it2.next() == null);

    try reg.add(e2, components.A{});
    try reg.add(e2, components.B{});
    try reg.add(e2, components.C{});

    var vi = reg.view(struct { a: *components.A, b: *components.B });
    t.expect(vi.next() != null);
    t.expect(vi.next() != null);
    t.expect(vi.next() == null);

    var vi2 = reg.view(struct { b: *components.B, a: *components.A });
    t.expect(vi2.next() != null);
    t.expect(vi2.next() != null);
    t.expect(vi2.next() == null);

    var vi3 = reg.view(struct { a: *components.A, b: ?*components.B });
    t.expect(vi3.next() != null);
    t.expect(vi3.next() != null);
    t.expect(vi3.next() != null);
    t.expect(vi3.next() == null);
}
