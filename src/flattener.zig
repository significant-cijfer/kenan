const std = @import("std");
const root = @import("root.zig");

const Graph = struct {
    blocks: std.MultiArrayList(Block),
};

const Block = struct {
};

const Inst = union(enum) {
};

pub fn flatten(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, program: root.parser.Program) !void {
    const functions = program.functions.slice();

    for (0..functions.len) |i| {
        const function = functions.get(i);
        const name = tokens.slice(function.name);

        std.debug.print("function {s}:\n", .{name});

        try flattenFunction(allocator, tokens, function);
    }
}

fn flattenFunction(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, function: root.parser.Function) !void {
    const exprs = function.exprs.slice();

    for (0..exprs.len) |i| {
        const expr = exprs.get(i);

        try flattenExpr(allocator, tokens, expr);
    }
}

fn flattenExpr(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, expr: root.parser.Expr) !void {
    _ = allocator;
    _ = tokens;

    switch (expr) {
        else => std.debug.panic("unhandled expr: {}", .{expr}),
    }
}
