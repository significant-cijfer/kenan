const std = @import("std");

pub const Tokens = struct {
    text: [:0]const u8,
    list: std.MultiArrayList(Token),

    pub fn get(self: Tokens, index: u32) Token {
        return self.list.get(index);
    }

    pub fn slice(self: Tokens, index: u32) []const u8 {
        const tok = self.get(index);
        _, const end = token(self.text, tok.index);

        return self.text[tok.index..end];
    }
};

pub const Token = struct {
    unit: Unit,
    index: u32,
};

pub const Unit = enum {
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
    comment,
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

                if (text[idx] == '/')
                    continue :state .comment
                else
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
        .comment => switch (text[idx]) {
            '\n' => {
                start += 1;
                continue :state .initial;
            },
            else => {
                start += 1;
                idx += 1;
                continue :state .comment;
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
