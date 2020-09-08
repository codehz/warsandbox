// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Order = std.math.Order;

const Color = enum(u1) {
    Black,
    Red,
};
const Red = Color.Red;
const Black = Color.Black;

const ReplaceError = error{NotEqual};

pub fn FieldType(comptime Data: type, comptime field: []const u8) type {
    return std.meta.fieldInfo(Data, field).field_type;
}

pub fn Node(
    comptime Data: type,
    comptime nodefield: []const u8,
    comptime keyfield: []const u8,
    // comptime compareFn: fn (a: FieldType(Data, keyfield), b: FieldType(Data, keyfield)) Order,
    comptime compareFn: anytype,
) type {
    return struct {
        pub const KeyType = FieldType(Data, keyfield);
        pub const compareKey = compareFn;
        pub const NodeType = @This();

        left: ?*@This() = null,
        right: ?*@This() = null,

        parent_and_color: usize = 0,

        pub fn fromData(data: *Data) *@This() {
            return &@field(data, nodefield);
        }

        pub fn getData(self: *@This()) *Data {
            return @fieldParentPtr(Data, nodefield, self);
        }

        pub fn getKey(self: *@This()) KeyType {
            return @field(self.getData(), keyfield);
        }

        pub fn compare(a: *@This(), b: *@This()) Order {
            return compareFn(a.getKey(), b.getKey());
        }

        pub fn next(self: *@This()) ?*@This() {
            var node = self;

            if (node.right) |right| {
                var n = right;
                while (n.left) |left| n = left;
                return n;
            }

            while (true) {
                var parent = node.getParent();
                if (parent) |p| {
                    if (node != p.right)
                        return p;
                    node = p;
                } else
                    return null;
            }
        }

        pub fn prev(self: *@This()) ?*@This() {
            var node = self;

            if (node.left) |left| {
                var n = left;
                while (n.right) |right| n = right;
                return n;
            }

            while (true) {
                var parent = node.getParent();
                if (parent) |p| {
                    if (node != p.left)
                        return p;
                    node = p;
                } else
                    return null;
            }
        }
        pub fn isRoot(self: *@This()) bool {
            return self.getParent() == null;
        }

        fn isRed(self: *@This()) bool {
            return self.getColor() == Red;
        }

        fn isBlack(self: *@This()) bool {
            return self.getColor() == Black;
        }

        fn setParent(self: *@This(), parent: ?*@This()) void {
            self.parent_and_color = @ptrToInt(parent) | (self.parent_and_color & 1);
        }

        fn getParent(self: *@This()) ?*@This() {
            const mask: usize = 1;
            comptime {
                assert(@alignOf(*@This()) >= 2);
            }
            const maybe_ptr = self.parent_and_color & ~mask;
            return if (maybe_ptr == 0) null else @intToPtr(*@This(), maybe_ptr);
        }

        fn setColor(self: *@This(), color: Color) void {
            const mask: usize = 1;
            self.parent_and_color = (self.parent_and_color & ~mask) | @enumToInt(color);
        }

        fn getColor(self: *@This()) Color {
            return @intToEnum(Color, @intCast(u1, self.parent_and_color & 1));
        }

        fn setChild(self: *@This(), child: ?*@This(), is_left: bool) void {
            if (is_left) {
                self.left = child;
            } else {
                self.right = child;
            }
        }

        fn getFirst(self: *@This()) *@This() {
            var node = self;
            while (node.left) |left| {
                node = left;
            }
            return node;
        }

        fn getLast(self: *@This()) *@This() {
            var node = self;
            while (node.right) |right| {
                node = right;
            }
            return node;
        }
    };
}

pub fn Tree(
    comptime Data: type,
    comptime nodefield: []const u8,
) type {
    return struct {
        pub const NodeType = FieldType(Data, nodefield);
        pub const KeyType = NodeType.KeyType;

        root: ?*NodeType = null,

        pub fn first(self: *@This()) ?*NodeType {
            var node: *NodeType = self.root orelse return null;
            return node.getFirst();
        }

        pub fn last(self: *@This()) ?*NodeType {
            var node: *NodeType = self.root orelse return null;
            return node.getLast();
        }

        pub fn insert(self: *@This(), data: *Data) ?*Data {
            var node = NodeType.fromData(data);
            var maybe_key: ?*NodeType = undefined;
            var maybe_parent: ?*NodeType = undefined;
            var is_left: bool = undefined;

            maybe_key = doLookup(node.getKey(), self, &maybe_parent, &is_left);
            if (maybe_key) |key| {
                return key.getData();
            }

            node.left = null;
            node.right = null;
            node.setColor(Red);
            node.setParent(maybe_parent);

            if (maybe_parent) |parent| {
                parent.setChild(node, is_left);
            } else {
                self.root = node;
            }

            while (node.getParent()) |*parent| {
                if (parent.*.isBlack())
                    break;
                // the root is always black
                var grandpa = parent.*.getParent() orelse unreachable;

                if (parent.* == grandpa.left) {
                    var maybe_uncle = grandpa.right;

                    if (maybe_uncle) |uncle| {
                        if (uncle.isBlack())
                            break;

                        parent.*.setColor(Black);
                        uncle.setColor(Black);
                        grandpa.setColor(Red);
                        node = grandpa;
                    } else {
                        if (node == parent.*.right) {
                            rotateLeft(parent.*, self);
                            node = parent.*;
                            parent.* = node.getParent().?; // Just rotated
                        }
                        parent.*.setColor(Black);
                        grandpa.setColor(Red);
                        rotateRight(grandpa, self);
                    }
                } else {
                    var maybe_uncle = grandpa.left;

                    if (maybe_uncle) |uncle| {
                        if (uncle.isBlack())
                            break;

                        parent.*.setColor(Black);
                        uncle.setColor(Black);
                        grandpa.setColor(Red);
                        node = grandpa;
                    } else {
                        if (node == parent.*.left) {
                            rotateRight(parent.*, self);
                            node = parent.*;
                            parent.* = node.getParent().?; // Just rotated
                        }
                        parent.*.setColor(Black);
                        grandpa.setColor(Red);
                        rotateLeft(grandpa, self);
                    }
                }
            }
            // This was an insert, there is at least one node.
            self.root.?.setColor(Black);
            return null;
        }

        pub fn lookup(self: *@This(), key: KeyType) ?*Data {
            var parent: ?*NodeType = undefined;
            var is_left: bool = undefined;
            return (doLookup(key, self, &parent, &is_left) orelse return null).getData();
        }

        pub fn lookupData(self: *@This(), key: *Data) ?*Data {
            var parent: ?*NodeType = undefined;
            var is_left: bool = undefined;
            return (doLookup(NodeType.fromData(key).getKey(), self, &parent, &is_left) orelse return null).getData();
        }

        pub fn remove(self: *@This(), key: KeyType) ?*Data {
            const data = self.lookup(key) orelse return null;
            self.removeData(data);
            return data;
        }

        pub fn removeData(self: *@This(), data: *Data) void {
            var node = NodeType.fromData(data);
            // as this has the same value as node, it is unsafe to access node after newnode
            var newnode: ?*NodeType = NodeType.fromData(data);
            var maybe_parent: ?*NodeType = node.getParent();
            var color: Color = undefined;
            var next: *NodeType = undefined;

            // This clause is to avoid optionals
            if (node.left == null and node.right == null) {
                if (maybe_parent) |parent| {
                    parent.setChild(null, parent.left == node);
                } else
                    self.root = null;
                color = node.getColor();
                newnode = null;
            } else {
                if (node.left == null) {
                    next = node.right.?; // Not both null as per above
                } else if (node.right == null) {
                    next = node.left.?; // Not both null as per above
                } else
                    next = node.right.?.getFirst(); // Just checked for null above

                if (maybe_parent) |parent| {
                    parent.setChild(next, parent.left == node);
                } else
                    self.root = next;

                if (node.left != null and node.right != null) {
                    const left = node.left.?;
                    const right = node.right.?;

                    color = next.getColor();
                    next.setColor(node.getColor());

                    next.left = left;
                    left.setParent(next);

                    if (next != right) {
                        var parent = next.getParent().?; // Was traversed via child node (right/left)
                        next.setParent(node.getParent());

                        newnode = next.right;
                        parent.left = node;

                        next.right = right;
                        right.setParent(next);
                    } else {
                        next.setParent(maybe_parent);
                        maybe_parent = next;
                        newnode = next.right;
                    }
                } else {
                    color = node.getColor();
                    newnode = next;
                }
            }

            if (newnode) |n|
                n.setParent(maybe_parent);

            if (color == Red)
                return;
            if (newnode) |n| {
                n.setColor(Black);
                return;
            }

            while (node == self.root) {
                // If not root, there must be parent
                var parent = maybe_parent.?;
                if (node == parent.left) {
                    var sibling = parent.right.?; // Same number of black nodes.

                    if (sibling.isRed()) {
                        sibling.setColor(Black);
                        parent.setColor(Red);
                        rotateLeft(parent, self);
                        sibling = parent.right.?; // Just rotated
                    }
                    if ((if (sibling.left) |n| n.isBlack() else true) and
                        (if (sibling.right) |n| n.isBlack() else true))
                    {
                        sibling.setColor(Red);
                        node = parent;
                        maybe_parent = parent.getParent();
                        continue;
                    }
                    if (if (sibling.right) |n| n.isBlack() else true) {
                        sibling.left.?.setColor(Black); // Same number of black nodes.
                        sibling.setColor(Red);
                        rotateRight(sibling, self);
                        sibling = parent.right.?; // Just rotated
                    }
                    sibling.setColor(parent.getColor());
                    parent.setColor(Black);
                    sibling.right.?.setColor(Black); // Same number of black nodes.
                    rotateLeft(parent, self);
                    newnode = self.root;
                    break;
                } else {
                    var sibling = parent.left.?; // Same number of black nodes.

                    if (sibling.isRed()) {
                        sibling.setColor(Black);
                        parent.setColor(Red);
                        rotateRight(parent, self);
                        sibling = parent.left.?; // Just rotated
                    }
                    if ((if (sibling.left) |n| n.isBlack() else true) and
                        (if (sibling.right) |n| n.isBlack() else true))
                    {
                        sibling.setColor(Red);
                        node = parent;
                        maybe_parent = parent.getParent();
                        continue;
                    }
                    if (if (sibling.left) |n| n.isBlack() else true) {
                        sibling.right.?.setColor(Black); // Same number of black nodes
                        sibling.setColor(Red);
                        rotateLeft(sibling, self);
                        sibling = parent.left.?; // Just rotated
                    }
                    sibling.setColor(parent.getColor());
                    parent.setColor(Black);
                    sibling.left.?.setColor(Black); // Same number of black nodes
                    rotateRight(parent, self);
                    newnode = self.root;
                    break;
                }

                if (node.isRed())
                    break;
            }

            if (newnode) |n|
                n.setColor(Black);
        }

        pub fn replace(self: *@This(), old: *Data, newconst: *Data) !void {
            var new = NodeType.fromData(newconst);

            // I assume this can get optimized out if the caller already knows.
            if (NodeType.compare(NodeType.fromData(old), NodeType.fromData(newconst)) != .eq) return ReplaceError.NotEqual;

            if (old.getParent()) |parent| {
                parent.setChild(new, parent.left == old);
            } else
                self.root = new;

            if (old.left) |left|
                left.setParent(new);
            if (old.right) |right|
                right.setParent(new);

            new.* = old.*;
        }

        fn rotateLeft(node: *NodeType, tree: *@This()) void {
            var p: *NodeType = node;
            var q: *NodeType = node.right orelse unreachable;
            var parent: *NodeType = undefined;

            if (!p.isRoot()) {
                parent = p.getParent().?;
                if (parent.left == p) {
                    parent.left = q;
                } else {
                    parent.right = q;
                }
                q.setParent(parent);
            } else {
                tree.root = q;
                q.setParent(null);
            }
            p.setParent(q);

            p.right = q.left;
            if (p.right) |right| {
                right.setParent(p);
            }
            q.left = p;
        }

        fn rotateRight(node: *NodeType, tree: *@This()) void {
            var p: *NodeType = node;
            var q: *NodeType = node.left orelse unreachable;
            var parent: *NodeType = undefined;

            if (!p.isRoot()) {
                parent = p.getParent().?;
                if (parent.left == p) {
                    parent.left = q;
                } else {
                    parent.right = q;
                }
                q.setParent(parent);
            } else {
                tree.root = q;
                q.setParent(null);
            }
            p.setParent(q);

            p.left = q.right;
            if (p.left) |left| {
                left.setParent(p);
            }
            q.right = p;
        }

        fn doLookup(key: KeyType, tree: *@This(), pparent: *?*NodeType, is_left: *bool) ?*NodeType {
            var maybe_node: ?*NodeType = tree.root;

            pparent.* = null;
            is_left.* = false;

            while (maybe_node) |node| {
                const res = NodeType.compareKey(node.getKey(), key);
                if (res == .eq) {
                    return node;
                }
                pparent.* = node;
                switch (res) {
                    .gt => {
                        is_left.* = true;
                        maybe_node = node.left;
                    },
                    .lt => {
                        is_left.* = false;
                        maybe_node = node.right;
                    },
                    .eq => unreachable, // handled above
                }
            }
            return null;
        }
    };
}

pub fn getAutoCompareFn(comptime T: type) fn (a: T, b: T) Order {
    return struct {
        fn compare(a: T, b: T) Order {
            return std.math.order(a, b);
        }
    }.compare;
}

pub fn TreeMapUnmanaged(comptime K: type, comptime V: type, comptime compareFn: fn (a: K, b: K) Order) type {
    return struct {
        pub const KV = struct {
            node: Node(@This(), "node", "key", compareFn),
            key: K,
            value: V,
        };
        pub const RawTree = Tree(KV, "node");
        raw: RawTree = .{},

        pub fn set(self: *@This(), allocator: *std.mem.Allocator, key: K) std.mem.Allocator.Error!*V {
            var temp = try allocator.create(KV);
            temp.key = key;
            return self.raw.insert(temp);
        }

        pub fn insert(self: *@This(), allocator: *std.mem.Allocator, key: K, value: V) (error{Overlapped} || std.mem.Allocator.Error)!void {
            var temp = try allocator.create(KV);
            errdefer allocator.destroy(temp);
            temp.key = key;
            temp.value = value;
            if (self.raw.insert(temp)) |_| return error.Overlapped;
        }

        pub fn remove(self: *@This(), allocator: *std.mem.Allocator, key: K) bool {
            const ret = self.raw.remove(key) orelse return false;
            allocator.destroy(ret);
            return true;
        }

        pub fn find(self: *@This(), key: K) ?*V {
            const ret = self.raw.lookup(key) orelse return null;
            return &ret.value;
        }

        pub const Iterator = struct {
            node: ?*RawTree.NodeType,

            pub fn next(self: *@This()) ?*KV {
                const node = self.node orelse return null;
                self.node = node.next();
                return node.getData();
            }

            pub fn nextValue(self: *@This()) ?*V {
                const node = self.node orelse return null;
                self.node = node.next();
                return &node.getData().value;
            }
        };

        pub fn iterator(self: *@This()) Iterator {
            return .{ .node = self.raw.first() };
        }

        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            while (self.raw.first()) |first| {
                self.raw.removeData(first.getData());
                allocator.destroy(first);
            }
        }
    };
}

pub fn AutoTreeMapUnmanaged(comptime K: type, comptime V: type) type {
    return TreeMapUnmanaged(K, V, getAutoCompareFn(K));
}

test "unmanaged tree map" {
    var map = AutoTreeMapUnmanaged(u8, u8){};
    defer map.deinit(testing.allocator);
    try map.insert(testing.allocator, 1, 2);
    try map.insert(testing.allocator, 3, 8);
    try map.insert(testing.allocator, 2, 4);
    testing.expectEqual(@as(?*u8, null), map.find(0));
    testing.expectEqual(@as(u8, 2), map.find(1).?.*);
    var iter = map.iterator();
    testing.expectEqual(@as(u8, 2), iter.nextValue().?.*);
    testing.expectEqual(@as(u8, 4), iter.nextValue().?.*);
    testing.expectEqual(@as(u8, 8), iter.nextValue().?.*);
    testing.expectEqual(@as(?*u8, null), iter.nextValue());
    testing.expect(map.remove(testing.allocator, 2));
    testing.expectEqual(@as(?*u8, null), map.find(2));
}

pub fn TreeMap(comptime K: type, comptime V: type, comptime compareFn: fn (a: K, b: K) Order) type {
    return struct {
        pub const Unmanaged = TreeMapUnmanaged(K, V, compareFn);
        pub const Iterator = Unmanaged.Iterator;
        pub const KV = Unmanaged.KV;
        pub const RawTree = Unmanaged.RawTree;

        allocator: *std.mem.Allocator,
        unmanaged: Unmanaged,

        pub fn init(allocator: *std.mem.Allocator) @This() {
            return .{
                .allocator = allocator,
                .unmanaged = .{},
            };
        }

        pub fn deinit(self: *@This()) void {
            self.unmanaged.deinit(self.allocator);
        }

        pub fn set(self: *@This(), key: K) !*V {
            return self.unmanaged.set(self.allocator, key);
        }

        pub fn insert(self: *@This(), key: K, value: V) !void {
            return self.unmanaged.insert(self.allocator, key, value);
        }

        pub fn remove(self: *@This(), key: K) bool {
            return self.unmanaged.remove(self.allocator, key);
        }

        pub fn find(self: *@This(), key: K) ?*V {
            return self.unmanaged.find(key);
        }

        pub fn iterator(self: *@This()) Iterator {
            return self.unmanaged.iterator();
        }
    };
}

pub fn AutoTreeMap(comptime K: type, comptime V: type) type {
    return TreeMap(K, V, getAutoCompareFn(K));
}

test "managed tree map" {
    var map = AutoTreeMap(u8, u8).init(testing.allocator);
    defer map.deinit();
    try map.insert(1, 2);
    try map.insert(3, 8);
    try map.insert(2, 4);
    testing.expectEqual(@as(?*u8, null), map.find(0));
    testing.expectEqual(@as(u8, 2), map.find(1).?.*);
    var iter = map.iterator();
    testing.expectEqual(@as(u8, 2), iter.nextValue().?.*);
    testing.expectEqual(@as(u8, 4), iter.nextValue().?.*);
    testing.expectEqual(@as(u8, 8), iter.nextValue().?.*);
    testing.expectEqual(@as(?*u8, null), iter.nextValue());
    testing.expect(map.remove(2));
    testing.expectEqual(@as(?*u8, null), map.find(2));
}
