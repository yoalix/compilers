#include "common.h"
#include "chunk.h"
#include "debug.h"
#include "vm.h"
#include <time.h>

int main(int argc, const char* argv[]) {
    clock_t start, end;
   start = clock();
    VM vm;
    initVM(&vm);

    Chunk chunk;
    initChunk(&chunk);

    int constant = addConstant(&chunk, 1.2);
    writeChunk(&chunk, OP_CONSTANT, 1);
    writeChunk(&chunk, constant, 1);

    constant = addConstant(&chunk, 3.4);
    writeChunk(&chunk, OP_CONSTANT, 1);
    writeChunk(&chunk, constant, 1);

    writeChunk(&chunk, OP_ADD, 1);


    constant = addConstant(&chunk, 5.6);
    writeChunk(&chunk, OP_CONSTANT, 1);
    writeChunk(&chunk, constant, 1);

    writeChunk(&chunk, OP_DIVIDE, 1);
    writeChunk(&chunk, OP_NEGATE, 1);

    writeChunk(&chunk, OP_RETURN, 2);
    disassembleChunk(&chunk, "test chunk");
    interpret(&vm, &chunk);
    end = clock();

    printf("Time: %f seconds\n", (double)(end - start) );
    freeVM(&vm);
    freeChunk(&chunk);
    return 0;
}
