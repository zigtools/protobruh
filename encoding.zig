const std = @import("std");

// COMMON

pub const WireType = enum(usize) {
    varint_or_zigzag,
    fixed64bit,
    delimited,
    group_start,
    group_end,
    fixed32bit,
};

pub const SplitTag = struct { field: usize, wire_type: WireType };
fn splitTag(tag: usize) SplitTag {
    return .{ .field = tag >> 3, .wire_type = @intToEnum(WireType, tag & 7) };
}

fn joinTag(split: SplitTag) usize {
    return (split.field << 3) | split.wire_type;
}

fn readTag(reader: anytype) !SplitTag {
    return splitTag(try std.leb.readULEB128(usize, reader));
}

fn writeTag(writer: anytype, split: SplitTag) !void {
    try std.leb.writeULEB128(writer, joinTag(split));
}

// DECODE

pub fn decode(comptime T: type, allocator: std.mem.Allocator, reader: anytype) !T {
    var value: T = undefined;
    try decodeInternal(T, &value, allocator, reader, true);
    return value;
}

fn decodeMessageFields(comptime T: type, allocator: std.mem.Allocator, reader: anytype, length: usize) !T {
    var counting_reader = std.io.countingReader(reader);
    var value = if (@hasField(T, "items") and @hasField(T, "capacity")) .{} else std.mem.zeroInit(T, .{});

    while (length == 0 or counting_reader.bytes_read < length) {
        // TODO: Add type sameness checks
        const split = readTag(counting_reader.reader()) catch |err| switch (err) {
            error.EndOfStream => return value,
            else => return err,
        };

        inline for (@field(T, "tags")) |rel| {
            if (split.field == rel[1]) {
                decodeInternal(@TypeOf(@field(value, rel[0])), &@field(value, rel[0]), allocator, counting_reader.reader(), false) catch |err| switch (err) {
                    error.EndOfStream => return value,
                    else => return err,
                };
            }
        }
    }

    return value;
}

fn decodeInternal(
    comptime T: type,
    value: *T,
    allocator: std.mem.Allocator,
    reader: anytype,
    top: bool,
) !void {
    _ = allocator;
    _ = top;

    switch (@typeInfo(T)) {
        .Struct => {
            if (@hasField(T, "items") and @hasField(T, "capacity")) {
                const Child = @typeInfo(@field(T, "Slice")).Pointer.child;
                var new_elem: Child = undefined;
                try decodeInternal(Child, &new_elem, allocator, reader, false);
                try value.append(allocator, new_elem);
            } else {
                var length = if (top) 0 else try std.leb.readULEB128(usize, reader);
                value.* = try decodeMessageFields(T, allocator, reader, length);
            }
        },
        .Pointer => |ptr| {
            _ = ptr;
            // TODO: Handle non-slices
            if (T == []const u8) {
                var data = try allocator.alloc(u8, try std.leb.readULEB128(usize, reader));
                _ = try reader.readAll(data);
                value.* = data;
            } else @compileError("Slices not implemented");
        },
        // TODO: non-usize enums
        .Enum => value.* = @intToEnum(T, try std.leb.readULEB128(usize, reader)),
        .Int => |i| value.* = switch (i.signedness) {
            .signed => try std.leb.readILEB128(T, reader),
            .unsigned => try std.leb.readULEB128(T, reader),
        },
        .Bool => value.* = ((try std.leb.readULEB128(usize, reader)) != 0),
        else => @compileError("Unsupported: " ++ @typeName(T)),
    }
}

test "Decode" {
    const scip = @import("test/scip/scip.zig");

    var file = try std.fs.cwd().openFile("test/scip/basic.bin", .{});
    defer file.close();

    var reader = file.reader();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const index = try decode(scip.Index, arena.allocator(), reader);

    try std.testing.expectEqual(scip.ProtocolVersion.unspecified_protocol_version, index.metadata.version);
    try std.testing.expectEqualSlices(u8, "joe", index.metadata.tool_info.name);
    try std.testing.expectEqualSlices(u8, "mama", index.metadata.tool_info.version);
    try std.testing.expectEqual(@as(usize, 2), index.metadata.tool_info.arguments.items.len);
    try std.testing.expectEqualSlices(u8, "amog", index.metadata.tool_info.arguments.items[0]);
    try std.testing.expectEqualSlices(u8, "us", index.metadata.tool_info.arguments.items[1]);

    // TODO: Check more of this result

    // try std.testing.expectEqual(scip.Index{
    //     .metadata = .{
    //         .version = .unspecified_protocol_version,
    //         .tool_info = .{
    //             .name = "joe",
    //             .version = "mama",
    //             .arguments = try TestUtils.unmanagedFromSlice([]const u8, arena.allocator(), &.{ "amog", "us" }),
    //         },
    //         .project_root = "C:\\Programming\\Zig\\scip-zig\\test",
    //         .text_document_encoding = .utf8,
    //     },
    //     .documents = try TestUtils.unmanagedFromSlice(scip.Document, arena.allocator(), &.{
    //         .{
    //             .language = "zig",
    //             .relative_path = "loris.zig",
    //             .occurrences = .{},
    //             .symbols = try TestUtils.unmanagedFromSlice(scip.SymbolInformation, arena.allocator(), &.{
    //                 .{
    //                     .symbol = "swag",
    //                     .documentation = try TestUtils.unmanagedFromSlice([]const u8, arena.allocator(), &.{ "Is Loris swag?", "Yes" }),
    //                     .relationships = .{},
    //                 },
    //             }),
    //         },
    //     }),
    //     .external_symbols = .{},
    // }, index);
}

// ENCODE

test "Encode" {}
