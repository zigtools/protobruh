pub const WireType = enum(usize) {
    varint_or_zigzag,
    fixed64bit,
    delimited,
    group_start,
    group_end,
    fixed32bit,
};
