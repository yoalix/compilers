#include <stdlib.h>

#include "chunk.h"
#include "memory.h"

void initChunk(Chunk* chunk) {
    chunk->count = 0;
    chunk->capacity = 0;
    chunk->code=NULL;
    chunk->lines=NULL;
    chunk->linesCapacity = 0;
    chunk->lineCount = 0;
    initValueArray(&chunk->constants);
}

void freeChunk(Chunk* chunk) {
    FREE_ARRAY(uint8_t, chunk->code, chunk->capacity);
    FREE_ARRAY(int, chunk->lines, chunk->linesCapacity);
    freeValueArray(&chunk->constants);
    initChunk(chunk);
}

void writeChunk(Chunk* chunk, uint8_t byte, int line) {
    if (chunk->capacity < chunk->count + 1) {
        int oldCapacity = chunk->capacity;
        chunk->capacity = GROW_CAPACITY(oldCapacity);
        chunk->code = GROW_ARRAY(uint8_t, chunk->code, oldCapacity, chunk->capacity);
    }
    if (chunk->linesCapacity < chunk->lineCount + 1) {
        int oldCapacity = chunk->linesCapacity;
        chunk->linesCapacity = GROW_CAPACITY(oldCapacity);
        chunk->lines = GROW_ARRAY(int, chunk->lines, oldCapacity, chunk->linesCapacity);
        for (int i = oldCapacity; i < chunk->linesCapacity; ++i){
            chunk->lines[i] = 0;
        }
    }

    chunk->code[chunk->count] = byte;
    if (chunk->lines[line - 1]) {
        chunk->lineCount++;
    }
    chunk->lines[line - 1]++;
    chunk->count++;
}

int addConstant(Chunk* chunk, Value value) {
    writeValueArray(&chunk->constants, value);
    return chunk->constants.count - 1;
}

int getLine(Chunk* chunk, int index) {
    int i = 0;
    while (index >= 0) {
         if (chunk->lines[i] == 0) {
            i++;
         }
         chunk->lines[i]--;
         index--;
    }
    return i + 1;
}
