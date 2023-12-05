const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const value = @import("value.zig");
const debug = @import("debug.zig");
const Compiler = @import("compiler.zig").Compiler;

const STACK_MAX = 256;

const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};

pub const VM = struct {
    const Self = @This();
    alloc: std.mem.Allocator,
    chunk: *Chunk = undefined,
    ip: [*]u8 = undefined,
    stack: *[STACK_MAX]Value = undefined,
    stackTop: [*]Value = undefined,

    pub fn init(alloc: std.mem.Allocator) Self {
        var vm = Self{ .alloc = alloc };
        vm.stack = vm.alloc.create([STACK_MAX]Value) catch std.os.exit(1);
        vm.resetStack();
        return vm;
    }

    pub fn deinit(self: *Self) void {
        self.chunk.deinit();
    }

    pub fn interpret(vm: *Self, source: [:0]u8) InterpretResult {
        var chunk = Chunk.init(vm.alloc);
        var compiler = Compiler.init(source, &chunk);
        if (!compiler.compile()) {
            vm.deinit();
            return InterpretResult.COMPILE_ERROR;
        }
        vm.chunk = &chunk;
        vm.ip = vm.chunk.code;
        var result = vm.run();
        return result;
    }

    pub fn run(vm: *Self) InterpretResult {
        while (true) {
            if (debug.trace_enabled) {
                std.debug.print("          ");
                inline for (vm.stack) |slot| {
                    std.debug.print("[ ");
                    value.printValue(slot.*);
                    std.debug.print(" ]");
                }
                std.debug.print("\n", .{});
                debug.disassembleInstruction(vm.chunk, vm.ip - vm.chunk.code.ptr);
            }
            var instruction = @as(OpCode, @enumFromInt(vm.readByte()));
            switch (instruction) {
                .OP_CONSTANT => {
                    var constant = vm.readConstant();
                    vm.push(constant);
                },
                .OP_TRUE => vm.push(Value{ .boolean = true }),
                .OP_FALSE => vm.push(Value{ .boolean = false }),
                .OP_NIL => vm.push(Value{ .nil = undefined }),
                .OP_NEGATE => vm.negate(),
                .OP_ADD => vm.binaryOp(add),
                .OP_SUBTRACT => vm.binaryOp(sub),
                .OP_MULTIPLY => vm.binaryOp(mul),
                .OP_DIVIDE => vm.binaryOp(div),
                .OP_RETURN => {
                    value.printValue(vm.pop());
                    std.debug.print("\n", .{});
                    return InterpretResult.OK;
                },
            }
        }
    }

    inline fn readByte(vm: *Self) u8 {
        var result = vm.ip[0];
        vm.ip += 1;
        return result;
    }

    inline fn readConstant(vm: *Self) Value {
        return vm.chunk.constants.values[readByte(vm)];
    }

    inline fn binaryOp(vm: *Self, comptime op: fn (f64, f64) f64) void {
        var b = vm.pop();
        var a = vm.pop();
        vm.push(Value{ .number = op(a.number, b.number) });
    }

    pub fn resetStack(self: *Self) void {
        self.stackTop = self.stack;
    }

    pub fn push(self: *Self, val: Value) void {
        self.stackTop[0] = val;
        self.stackTop += 1;
    }

    pub fn pop(self: *Self) Value {
        self.stackTop -= 1;
        return self.stackTop[0];
    }

    pub fn negate(self: *Self) void {
        (self.stackTop - 1)[0] = Value{ .number = -(self.stackTop - 1)[0].number };
    }

    fn runtimeError(self: *Self, comptime format: []const u8, args: anytype) void {
        std.debug.panic(format, args);
        std.debug.panic("\n", .{});
        var instruction = self.ip - self.chunk.code - 1;
        const line = self.chunk.getLine(instruction);
        std.debug.panic("[line {}] in script\n", .{line});
        self.resetStack();
    }
};

fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn sub(a: f64, b: f64) f64 {
    return a - b;
}

fn mul(a: f64, b: f64) f64 {
    return a * b;
}

fn div(a: f64, b: f64) f64 {
    return a / b;
}
