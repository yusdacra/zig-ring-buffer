const std = @import("std");
const testing = std.testing;

fn Element(T: type) type {
    return struct {
        data: T,
    };
}

pub fn Buffer(T: type) type {
    return struct {
        const This = @This();
        const ElementType = Element(T);
        size: usize,
        data: [*]ElementType,

        pub fn init(this: *This, size: usize, allocator: std.mem.Allocator) anyerror!void {
            this.size = size;
            this.data = allocator.alloc(ElementType, size).?;
        }
    };
}
