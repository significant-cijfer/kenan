pub const Type = union(enum) {
    dev_todo, //TODO, remove this. this type only exists to fill some arbitrary thing, when sketching up a new function. where you dont want an unknown type
    novalue,
    integer: Integer,

    const Integer = struct {
        signed: bool,
        bits: u16,
    };

    pub fn isNumeric(self: Type) bool {
        return self == .integer;
    }

    pub fn coerces(self: Type, rhs: Type) bool {
        return switch (self) {
            .integer => |i| switch (rhs) {
                .integer => |j| i.signed == j.signed and i.bits >= j.bits,
                else => false,
            },
            else => @panic("todo"),
        };
    }
};
