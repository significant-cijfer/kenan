const std = @import("std");
const root = @import("root.zig");

const Context = struct {
};

const Table = struct {
};

pub fn scan(allocator: std.mem.Allocator, program: root.parser.Program) !void {
    _ = allocator;
    _ = program;
}
