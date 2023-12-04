const std = @import("std");

pub inline fn growCapacity(comptime T: type, capacity: anytype) T {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn growArray(allocator: std.mem.Allocator, comptime T: type, oldArrayPtr: [*]T, oldCount: u32, newCount: u32) [*]T {
    return reallocate(allocator, oldArrayPtr, oldCount, newCount) orelse oldArrayPtr;
}

pub fn freeArray(allocator: std.mem.Allocator, comptime T: type, oldArrayPtr: [*]T, oldCount: usize) void {
    _ = reallocate(allocator, oldArrayPtr, oldCount, 0);
    return;
}

pub fn reallocate(allocator: std.mem.Allocator, voidPtr: anytype, oldSize: usize, newSize: usize) ?@TypeOf(voidPtr) {
    const typeInfo = @typeInfo(@TypeOf(voidPtr));
    if (typeInfo != .Pointer) {
        unreachable;
    }
    if (newSize == 0) {
        allocator.free(voidPtr[0..oldSize]);
        return null;
    }
    return (allocator.realloc(voidPtr[0..oldSize], newSize) catch std.os.exit(1)).ptr;
    // return result;
}
