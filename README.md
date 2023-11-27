# Compilers

A version of Lox Compiler implemented in both C and Zig

# Build and run

For C:

```
$ cd clox
$ zig cc main.c chunk.c debug.c memory.c value.c vm.c -o main
$ ./main
```

For Zig:

$ cd zlox
$ zig build run
