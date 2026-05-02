const std = @import("std");
const root = @import("tataC");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);

    if (args.len < 2)
        @panic("Usage: <program> [file.tc]");

    const text = try std.Io.Dir.cwd().readFileAllocOptions(init.io, args[1], gpa, .unlimited, .of(u8), 0);

    const tokens = try root.lexer.lex(gpa, text);
    const program = try root.parser.parse(gpa, tokens);
    _ = program;
}
