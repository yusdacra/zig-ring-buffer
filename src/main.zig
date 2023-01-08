const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const ordering = std.atomic.Ordering;

pub const RingBufferError = error{
    SIZE_NOT_POWER_OF_2,
    RING_FULL,
    RING_DEAD,
};

fn Element(comptime T: type) type {
    return struct {
        /// Proper data container
        data: T,
        /// Whether the buffer has been produced
        produced: bool,
    };
}

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const This = @This();
        const ElementType = Element(T);
        allocator: std.mem.Allocator,
        size: usize,
        data: []ElementType,
        /// Index where the next produced item will be placed
        next_producer: usize,
        /// Index of the next consumed element
        next_consumer: usize,
        /// Whether the Ringbuffer is alive
        alive: bool = false,
        /// Whether the ring buffer is empty
        empty: bool = true,

        pub fn init(this: *This, size: usize, allocator: std.mem.Allocator) anyerror!void {
            if (@clz(size) + @ctz(size) != @bitSizeOf(usize) - 1) {
                // Hack to make sure the given size is a power of 2
                debug.print("Input size is not a power of 2.", .{});
                return RingBufferError.SIZE_NOT_POWER_OF_2;
            }

            this.allocator = allocator;
            this.size = size;
            this.data = try allocator.alloc(ElementType, size);
            this.next_producer = 0;
            this.next_consumer = 0;

            var i: usize = 0;

            // Initialize the flags
            while (i < size) : (i += 1) {
                this.data[i].produced = false;
            }

            // Post-initialization activation of the buffer
            @atomicStore(bool, &this.alive, true, ordering.Release);
        }

        pub fn produce(this: *This, elt: T) RingBufferError!void {
            if (!@atomicLoad(bool, &this.alive, ordering.Acquire)) {
                return RingBufferError.RING_DEAD;
            }
            if (@atomicLoad(bool, &this.data[this.next_producer].produced, ordering.Acquire)) {
                return RingBufferError.RING_FULL;
            }

            this.data[this.next_producer].data = elt;
            @atomicStore(bool, &this.data[this.next_producer].produced, true, ordering.Release);
            this.next_producer = (this.next_producer + 1) % this.size;
        }

        pub fn consume(this: *This) RingBufferError!?T {
            if (!@atomicLoad(bool, &this.alive, ordering.Acquire)) {
                return RingBufferError.RING_DEAD;
            }
            if (!@atomicLoad(bool, &this.data[this.next_consumer].produced, ordering.Acquire)) {
                return null;
            } else {
                var elt = @ptrCast(*volatile T, &this.data[this.next_consumer]).*;
                @atomicStore(bool, &this.data[this.next_consumer].produced, false, ordering.Release);
                this.next_consumer = (this.next_consumer + 1) % this.size;
                return elt;
            }
        }
        pub fn deinit(this: *This) void {
            this.allocator.free(this.data);
        }
    };
}

test "init" {
    const UsizeBuffer = RingBuffer(usize);
    var buf: UsizeBuffer = undefined;
    try buf.init(128, std.testing.allocator);
    buf.deinit();
}
