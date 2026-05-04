const std = @import("std");
const root = @import("kenan");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);

    if (args.len < 2)
        @panic("Usage: <program> [file.kn]");

    const text = try std.Io.Dir.cwd().readFileAllocOptions(init.io, args[1], gpa, .unlimited, .of(u8), 0);

    const tokens = try root.lexer.lex(gpa, text);
    const program = try root.parser.parse(gpa, tokens);
    try root.scanner.scan(gpa, tokens, program);

    std.debug.print("capacity:\n", .{});
    std.debug.print("        : {} bytes\n", .{init.arena.queryCapacity()});
    std.debug.print("        : {} kibibytes\n", .{init.arena.queryCapacity() / 1024});
    std.debug.print("        : {} mebibytes\n", .{init.arena.queryCapacity() / 1024 / 1024});
}
