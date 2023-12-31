#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "common.h"
#include "chunk.h"
#include "debug.h"
#include "vm.h"

static void repl(VM *vm);
static void runFile(VM *vm, const char *path);
static char *readFile(const char *path);

int main(int argc, const char *argv[])
{
    clock_t start, end;
    VM vm;
    initVM(&vm);
    if (argc == 1)
    {
        repl(&vm);
    }
    else if (argc == 2)
    {
        start = clock();
        runFile(&vm, argv[1]);
        end = clock();
        printf("Time: %f seconds\n", (double)(end - start));
    }
    else
    {
        fprintf(stderr, "Usage: clox [path]\n");
        exit(64);
    }

    freeVM(&vm);
    return 0;
}

static void repl(VM *vm)
{
    char line[1024];
    printf("Welcome human to the shadow realm.\nHere you can write spells that will make the computer do your bidding.\nIf you wish to exit the shadow realm, say the magic words (exit).\n");
    for (;;)
    {
        printf(">");

        if (!fgets(line, sizeof(line), stdin) || strcasecmp(line, "exit\n") == 0)
        {
            printf("\n");
            break;
        }

        interpret(vm, line);
    }
}

static void runFile(VM *vm, const char *path)
{
    char *source = readFile(path);
    InterpretResult result = interpret(vm, source);
    free(source);

    if (result == INTERPRET_COMPILE_ERROR)
        exit(65);
    if (result == INTERPRET_RUNTIME_ERROR)
        exit(70);
}

static char *readFile(const char *path)
{
    FILE *file = fopen(path, "rb");
    if (file == NULL)
    {
        fprintf(stderr, "Could not open file \"%s\".\n", path);
        exit(74);
    }

    fseek(file, 0L, SEEK_END);
    size_t fileSize = ftell(file);
    rewind(file);

    char *buffer = (char *)malloc(fileSize + 1);
    if (buffer == NULL)
    {
        fprintf(stderr, "Not enougth mermory to read \"%s\".\n", path);
        exit(74);
    }

    size_t bytesRead = fread(buffer, sizeof(char), fileSize, file);
    if (bytesRead < fileSize)
    {
        fprintf(stderr, "Could not read file \"%s\".\n", path);
        exit(74);
    }
    buffer[bytesRead] = '\0';

    fclose(file);
    return buffer;
}
