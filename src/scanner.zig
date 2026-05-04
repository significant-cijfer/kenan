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
    typx: root.typx.Type,
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

    var t_decls: std.StringArrayHashMapUnmanaged(root.typx.Declaration) = .empty;

    for (0..decls.len) |i| {
        const decl = decls.get(i);

        const t_decl = try scanDecl(allocator, tokens, &chair, decl);
        const t_name = tokens.slice(decl.name);

        try t_decls.put(allocator, t_name, t_decl);
    }

    for (0..exprs.len) |i| {
        const expr = exprs.get(i);

        const typx = try scanExpr(allocator, tokens, &chair, expr);

        if (typx != .novalue)
            return error.NonVoidStatement;

        //TODO, add noreturn case here
    }

    try table.put(allocator, name, .{ .typx = .{
        .function = .{ .decls = t_decls },
    }});
}

fn scanDecl(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, table: *Table, decl: root.parser.Declaration) !root.typx.Declaration {
    const name = tokens.slice(decl.name);
    const typx = try scanExpr(allocator, tokens, table, decl.typx);

    try table.put(allocator, name, .{ .typx = typx });

    return .{
        .kind = decl.kind,
        .typx = typx,
    };
}

fn scanExpr(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, table: *Table, expr: root.parser.Expr) !root.typx.Type {
    switch (expr) {
        .integer => |t| {
            const string = tokens.slice(t);

            var number = try std.math.big.int.Managed.init(allocator);
            try number.setString(10, string);
            defer number.deinit();

            const signed = !number.isPositive();
            const bits = number.bitCountTwosComp();

            return .{ .integer = .{
                .signed = signed,
                .bits = @intCast(bits),
            }};
        },
        .identifier => |t| {
            const name = tokens.slice(t);
            const symbol = try table.get(name);

            return symbol.typx;
        },
        .add => |b| {
            const lhs = try scanExpr(allocator, tokens, table, b.lhs.*);
            const rhs = try scanExpr(allocator, tokens, table, b.rhs.*);

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
            const lhs = try scanExpr(allocator, tokens, table, v.lhs.*);

            if (lhs != .function)
                return error.NonFunctionCall;

            const decls = lhs.function.decls.values();

            for (v.rhs, decls) |r, decl| {
                const rhs = try scanExpr(allocator, tokens, table, r);

                if (!decl.typx.coerces(rhs))
                    return error.IncoercibleType;
            }

            return .novalue;
        },
        else => std.debug.panic("unhandled expr: {}", .{expr}),
    }

    @panic("todo");
}
