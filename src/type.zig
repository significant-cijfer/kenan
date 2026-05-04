const std = @import("std");
const root = @import("root.zig");

pub const Type = union(enum) {
    dev_todo, //TODO, remove this. this type only exists to fill some arbitrary thing, when sketching up a new function. where you dont want an unknown type
    novalue,
    integer: Integer,
    function: Function,

    pub fn isNumeric(self: Type) bool {
        return self == .integer;
    }

    pub fn coerces(self: Type, rhs: Type) bool {
        return switch (self) {
            .integer => |i| switch (rhs) {
                .integer => |j|
                    if (i.signed != j.signed)
                        j.signed == false and i.bits > j.bits
                    else
                        i.bits >= j.bits,
                else => false,
            },
            else => @panic("todo"),
        };
    }
};

const Integer = struct {
    signed: bool,
    bits: u16,
};

const Function = struct {
    decls: std.StringArrayHashMapUnmanaged(Declaration),
};

pub const Declaration = struct {
    kind: root.parser.Declaration.Kind,
    typx: Type,
};
