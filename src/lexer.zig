const std = @import("std");

pub const Tokens = struct {
    text: [:0]const u8,
    list: std.MultiArrayList(Token),
};

const Token = struct {
    unit: Unit,
    index: u32,
};

const Unit = enum {
    last,
    integer,
    identifier,
    @"function",
    @"var",
    @"out",
    @"in",
    @"is",
    @"do",
    @"end",
    @"+",
    @"-",
    @"*",
    @"/",
    @"=",
    @"(",
    @")",
    @",",
    @";",
};

const State = enum {
    initial,
    integer,
    identifier,
};

pub fn lex(allocator: std.mem.Allocator, text: [:0]const u8) !Tokens {
    var index: u32 = 0;
    var list = std.MultiArrayList(Token).empty;

    while (true) {
        const tok, index = token(text, index);

        std.debug.print("tok: .index = {}, .unit = {}\n", .{tok.index, tok.unit});

        try list.append(allocator, tok);

        if (tok.unit == .last)
            break;
    }

    return .{
        .text = text,
        .list = list,
    };
}

fn token(text: [:0]const u8, index: u32) struct { Token, u32 } {
    var start = index;
    var idx = index;

    const unit:
        Unit = state: switch (State.initial) {
        .initial => switch (text[idx]) {
            0 => {
                break :state .last;
            },
            '\n', '\r', '\t', ' ' => {
                start += 1;
                idx += 1;
                continue :state .initial;
            },
            '0'...'9' => {
                continue :state .integer;
            },
            'a'...'z', 'A'...'Z' => {
                continue :state .identifier;
            },
            '+' => {
                idx += 1;
                break :state .@"+";
            },
            '-' => {
                idx += 1;
                break :state .@"-";
            },
            '*' => {
                idx += 1;
                break :state .@"*";
            },
            '/' => {
                idx += 1;
                break :state .@"/";
            },
            '=' => {
                idx += 1;
                break :state .@"=";
            },
            '(' => {
                idx += 1;
                break :state .@"(";
            },
            ')' => {
                idx += 1;
                break :state .@")";
            },
            ',' => {
                idx += 1;
                break :state .@",";
            },
            ';' => {
                idx += 1;
                break :state .@";";
            },
            else => |c| {
                std.debug.panic("c: '{c}'", .{c});
            },
        },
        .integer => switch (text[idx]) {
            '0'...'9' => {
                idx += 1;
                continue :state .integer;
            },
            else => {
                break :state .integer;
            },
        },
        .identifier => switch (text[idx]) {
            'a'...'z', 'A'...'Z', '0'...'9' => {
                idx += 1;
                continue :state .identifier;
            },
            else => {
                break :state std.meta.stringToEnum(Unit, text[start..idx]) orelse .identifier;
            },
        },
    };

    return .{
        .{ .unit = unit, .index = start },
        idx,
    };
}
