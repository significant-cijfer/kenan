const std = @import("std");
const root = @import("root.zig");

const Context = struct {
    tables: std.StringHashMapUnmanaged(Table),
};

const Table = struct {
    parent: ?*Table,
    symbols: std.StringHashMapUnmanaged(Symbol),

    fn get(self: Table, name: []const u8) !Symbol {
        return self.symbols.get(name) orelse
            if (self.parent) |p| p.get(name) else error.UndefinedIdentifier;
    }

    fn put(self: *Table, allocator: std.mem.Allocator, name: []const u8, symbol: Symbol) !void {
        try self.symbols.put(allocator, name, symbol);
    }

    fn child(self: *Table) Table {
        return .{
            .parent = self,
            .symbols = .empty,
        };
    }
};

const Symbol = struct {
    typx: root.Type,
};

pub fn scan(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, program: root.parser.Program) !void {
    var context = Context{
        .tables = .empty,
    };

    var god = Table{
        .parent = null,
        .symbols = .empty,
    };

    try god.put(allocator, "i32", .{
        .typx = .{ .integer = .{ .signed = true, .bits = 32 } },
    });

    try context.tables.put(allocator, "<god>", god);

    try scanProgram(allocator, tokens, &god, program);

    @panic("passed scan");
}

fn scanProgram(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, table: *Table, program: root.parser.Program) !void {
    const functions = program.functions.slice();

    for (0..functions.len) |i|
        try scanFunction(allocator, tokens, table, functions.get(i));
}

fn scanFunction(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, table: *Table, function: root.parser.Function) !void {
    const name = tokens.slice(function.name);
    const decls = function.decls.slice();
    const exprs = function.exprs.slice();

    var chair = table.child();

    for (0..decls.len) |i|
        try scanDecl(allocator, tokens, &chair, decls.get(i));

    for (0..exprs.len) |i|
        _ = try scanExpr(allocator, tokens, &chair, exprs.get(i));

    //TODO
    try table.put(allocator, name, .{
        .typx = .dev_todo
    });
}

fn scanDecl(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, table: *Table, decl: root.parser.Declaration) !void {
    const name = tokens.slice(decl.name);
    const typx = try scanExpr(allocator, tokens, table, decl.typx);

    try table.put(allocator, name, .{ .typx = typx });
}

fn scanExpr(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, table: *Table, expr: root.parser.Expr) !root.Type {
    switch (expr) {
        .identifier => |t| {
            const name = tokens.slice(t);

            std.debug.print("name: {s}\n", .{name});
            const symbol = try table.get(name);

            return symbol.typx;
        },
        .add => |b| {
            const lhs = try scanExpr(allocator, tokens, table, b.lhs.*);
            const rhs = try scanExpr(allocator, tokens, table, b.rhs.*);

            std.debug.print("lhs: {}\n", .{lhs});
            std.debug.print("rhs: {}\n", .{rhs});

            if (!lhs.isNumeric())
                return error.NonNumericType;

            if (!rhs.isNumeric())
                return error.NonNumericType;

            if (!lhs.coerces(rhs))
                return error.IncoercibleType;

            return lhs;
        },
        .assign => |b| {
            const lhs = try scanExpr(allocator, tokens, table, b.lhs.*);
            const rhs = try scanExpr(allocator, tokens, table, b.rhs.*);

            if (!lhs.coerces(rhs))
                return error.IncoercibleType;

            return .novalue;
        },
        .call => |v| {
            std.debug.print("call: v.lhs = {*}\n", .{v.lhs});

            const lhs = try scanExpr(allocator, tokens, table, v.lhs.*);
            _ = lhs;

            std.debug.print("v: {}\n", .{v});
            @panic("todo, call");
        },
        else => std.debug.panic("unhandled expr: {}", .{expr}),
    }

    @panic("todo");
}
