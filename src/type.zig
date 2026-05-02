pub const Type = union(enum) {
    dev_todo, //TODO, remove this. this type only exists to fill some arbitrary thing, when sketching up a new function. where you dont want an unknown type
    integer: Integer,

    const Integer = struct {
        signed: bool,
        bits: u16,
    };
};
