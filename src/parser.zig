const std = @import("std");
const root = @import("root.zig");

const Program = struct {
    functions: std.MultiArrayList(Function),
};

const Function = struct {
    name: Expr.Token,
    varbs: std.StringArrayHashMapUnmanaged(root.Type),
    outs: std.StringArrayHashMapUnmanaged(root.Type),
    ins: std.StringArrayHashMapUnmanaged(root.Type),
    body: std.MultiArrayList(Expr),
};

const Declaration = struct {
    kind: Kind,
    name: Expr.Token,
    typx: Expr.Token, //TODO(urgent), store actual type here

    const Kind = enum {
        varb,
        out,
        in,
    };
};

const Expr = union(enum) {
    integer: Token,
    identifier: Token,
    add: Binary,
    sub: Binary,
    mul: Binary,
    div: Binary,
    assign: Binary,
    call: Variadic,

    const Token = u32;

    const Binary = struct {
        lhs: *Expr,
        rhs: *Expr,
    };

    const Variadic = struct {
        lhs: *Expr,
        rhs: []Expr,
    };

    //TODO, Remove all pointers in this data structure, and replace with indices.
    //      For now however, I'm using pointers, cuz they make development easier
    fn box(self: Expr, allocator: std.mem.Allocator) !*Expr {
        const ptr = try allocator.create(Expr);
        ptr.* = self;
        return ptr;
    }
};

const Op = enum {
    add,
    sub,
    mul,
    div,
    assign,

    const Power = struct {
        lbp: u8,
        rbp: u8,
    };

    fn infixPower(self: Op) ?Power {
        return switch (self) {
            .add, .sub =>       .{ .lbp = 6, .rbp = 7 },
            .mul, .div =>       .{ .lbp = 8, .rbp = 9 },
            .assign =>          .{ .lbp = 2, .rbp = 3 },
            //else => null,
        };
    }
};

pub fn parse(allocator: std.mem.Allocator, tokens: root.lexer.Tokens) !Program {
    var idx: u32 = 0;

    while (!check(tokens, idx, .last)) {
        idx, const function = try parseFunction(allocator, tokens, idx);

        std.debug.print("fn: {s}\n", .{tokens.slice(function.name)});
        std.debug.print("fn.varbs: {}\n", .{function.varbs});
        std.debug.print("fn.outs: {}\n", .{function.outs});
        std.debug.print("fn.ins: {}\n", .{function.ins});
        std.debug.print("fn.body: {}\n", .{function.body});
    }

    return .{
        .functions = .empty
    };
}

fn parseFunction(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, index: u32) !struct { u32, Function } {
    var idx = index;

    var varbs: std.StringArrayHashMapUnmanaged(root.Type) = .empty;
    var outs: std.StringArrayHashMapUnmanaged(root.Type) = .empty;
    var ins: std.StringArrayHashMapUnmanaged(root.Type) = .empty;
    var exprs: std.MultiArrayList(Expr) = .empty;

    idx = try expect(tokens, idx, .@"function");
    const name = idx;
    idx = try expect(tokens, idx, .identifier);

    while (!check(tokens, idx, .@"do")) {
        idx, const decl = try parseDeclaration(tokens, idx);
        idx = try expect(tokens, idx, .@";");

        const list = switch (decl.kind) {
            .varb => &varbs,
            .out => &outs,
            .in => &ins,
        };

        try list.put(allocator, tokens.slice(decl.name), .dev_todo);
    }

    idx = skip(idx);

    while (!check(tokens, idx, .@"end")) {
        idx, const expr = try parseExpr(allocator, tokens, idx);
        idx = try expect(tokens, idx, .@";");

        try exprs.append(allocator, expr);
    }

    idx = skip(idx);

    return .{
        idx,
        .{
            .name = name,
            .varbs = varbs,
            .outs = outs,
            .ins = ins,
            .body = exprs,
        },
    }; 
}

fn parseDeclaration(tokens: root.lexer.Tokens, index: u32) !struct { u32, Declaration } {
    var idx = index;

    const kind: Declaration.Kind = switch (peek(tokens, idx).unit) {
        .@"var" => .varb,
        .@"out" => .out,
        .@"in" => .in, 
        else => return error.UnexpectedUnit,
    };

    idx = skip(idx);

    const name = idx;
    idx = try expect(tokens, idx, .identifier);
    idx = try expect(tokens, idx, .@"is");
    const typx = idx;
    idx = try expect(tokens, idx, .identifier); //TODO(urgent), parse actual type here

    return .{
        idx,
        .{
            .kind = kind,
            .name = name,
            .typx = typx,
        },
    };
}

fn parseExpr(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, index: u32) !struct { u32, Expr } {
    return parseExprDo(allocator, tokens, index, 0);
}

fn parseExprDo(allocator: std.mem.Allocator, tokens: root.lexer.Tokens, index: u32, bind: u8) !struct { u32, Expr } {
    var idx, const first = next(tokens, index);

    var lhs: Expr = switch (first.unit) {
        .integer => .{
            .integer = first.index,
        },
        .identifier => .{
            .identifier = first.index,
        },
        else => |u| {
            std.debug.panic("huh? = {}", .{u});
        },
    };

    while (true) {
        const current = peek(tokens, idx);

        const op = switch (current.unit) {
            .@"+" => Op.add,
            .@"-" => Op.sub,
            .@"*" => Op.mul,
            .@"/" => Op.div,
            .@"=" => Op.assign,
            .@"(" => {
                var args: std.ArrayList(Expr) = .empty;

                idx = skip(idx);

                while (!check(tokens, idx, .@")")) {
                    idx, const arg = try parseExprDo(allocator, tokens, idx, 0);

                    if (!check(tokens, idx, .@")"))
                        idx = try expect(tokens, idx, .@",");

                    try args.append(allocator, arg);
                }

                idx = skip(idx);

                lhs = .{
                    .call = .{
                        .lhs = try lhs.box(allocator),
                        .rhs = try args.toOwnedSlice(allocator),
                    },
                };

                continue;
            },
            else => break,
        };

        if (op.infixPower()) |p| {
            if (p.lbp < bind)
                break;

            idx = skip(idx);

            idx, const rhs = try parseExprDo(allocator, tokens, idx, p.rbp);

            const payload: Expr.Binary = .{
                .lhs = try lhs.box(allocator),
                .rhs = try rhs.box(allocator),
            };

            lhs = switch (op) {
                .add => .{ .add = payload },
                .sub => .{ .sub = payload },
                .mul => .{ .mul = payload },
                .div => .{ .div = payload },
                .assign => .{ .assign = payload },
                //else => unreachable,
            };

            continue;
        }

        return error.UnhandledOp;
    }

    return .{
        idx,
        lhs,
    };
}

// Helpers
fn expect(tokens: root.lexer.Tokens, index: u32, unit: root.lexer.Unit) !u32 {
    if (tokens.get(index).unit != unit)
        return error.UnexpectedUnit;

    return index + 1;
}

fn check(tokens: root.lexer.Tokens, index: u32, unit: root.lexer.Unit) bool {
    return tokens.get(index).unit == unit;
}

fn next(tokens: root.lexer.Tokens, index: u32) struct { u32, root.lexer.Token } {
    return .{
        index + 1,
        tokens.get(index),
    };
}

fn peek(tokens: root.lexer.Tokens, index: u32) root.lexer.Token {
    return tokens.get(index);
}

fn skip(index: u32) u32 {
    return index + 1;
}
