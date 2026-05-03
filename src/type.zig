pub const Type = union(enum) {
    integer: Integer,

    const Integer = struct {
        signed: bool,
        bits: u16,
    };
};
