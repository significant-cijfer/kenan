const std = @import("std");
const root = @import("root.zig");

const Graph = struct {
    blocks: std.MultiArrayList(Block),
};

const Block = struct {
    insts: std.MultiArrayList(Inst),
    flow: Flow,

    const Flow = struct {
    };
};

const Inst = union(enum) {
    add: Binary,

    const Binary = struct {
        dst: Location,
        lhs: Location,
        rhs: Location,
    };
};

const Table = struct {
    locations: std.StringHashMapUnmanaged(Location),
    count: u32 = 0,

    fn getOrPut(self: *Table, allocator: std.mem.Allocator, name: []const u8) !Location {
        const value = Location{ .id = self.count };
        const entry = try self.locations.getOrPutValue(allocator, name, value);
        self.count += 1;

        return entry.value_ptr.*;
    }

    fn get(self: *Table) Location {
        const value = Location{ .id = self.count };
        self.count += 1;

        return value;
    }
};

const Location = struct {
    id: u32,
};

pub fn flatten(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, program: root.parser.Program) !void {
    const functions = program.functions.slice();

    for (0..functions.len) |i| {
        const function = functions.get(i);
        const name = tokens.slice(function.name);

        var graph = Graph{
            .blocks = .empty,
        };

        var block = Block{
            .insts = .empty,
            .flow = .{},
        };

        var table = Table{
            .locations = .empty,
        };

        std.debug.print("function {s}:\n", .{name});

        try flattenFunction(allocator, tokens, &graph, &block, &table, function);
    }
}

fn flattenFunction(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, graph: *Graph, block: *Block, table: *Table, function: root.parser.Function) !void {
    const exprs = function.exprs.slice();

    for (0..exprs.len) |i| {
        const expr = exprs.get(i);

        _ = try flattenExpr(allocator, tokens, graph, block, table, expr);
    }
}

fn flattenExpr(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, graph: *Graph, block: *Block, table: *Table, expr: root.parser.Expr) !struct { *Block, Location } {
    var blok = block;

    switch (expr) {
        .identifier => |t| {
            const name = tokens.slice(t);
            const location = try table.getOrPut(allocator, name);

            return .{
                blok,
                location,
            };
        },
        .add => |b| {
            blok, const lhs = try flattenExpr(allocator, tokens, graph, blok, table, b.lhs.*);
            blok, const rhs = try flattenExpr(allocator, tokens, graph, blok, table, b.rhs.*);

            const dst = table.get();

            try blok.insts.append(allocator, .{ .add = .{
                .dst = dst,
                .lhs = lhs,
                .rhs = rhs,
            }});

            std.debug.print(";;;\n", .{});
            std.debug.print("dst: {}\n", .{dst});
            std.debug.print("lhs: {}\n", .{lhs});
            std.debug.print("rhs: {}\n", .{rhs});

            return .{
                blok,
                dst,
            };
        },
        .assign => |b| {
            blok, const lhs = try flattenExpr(allocator, tokens, graph, blok, table, b.lhs.*);
            blok, const rhs = try flattenExpr(allocator, tokens, graph, blok, table, b.rhs.*);

            std.debug.print(";;;\n", .{});
            std.debug.print("lhs: {}\n", .{lhs});
            std.debug.print("rhs: {}\n", .{rhs});

            @panic("todo, assign");
        },
        else => std.debug.panic("unhandled expr: {}", .{expr}),
    }

    @panic("todo");
}
