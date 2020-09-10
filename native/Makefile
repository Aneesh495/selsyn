# Selsyn Native C DSP Acceleration Library Makefile

CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -pedantic -std=c99 -fPIC -Iinclude
AR ?= ar
ARFLAGS = rcs

SRC = src/fast_dft.c src/symmetrical_fast.c src/comtrade_fast.c
OBJ = $(SRC:.c=.o)
TARGET_LIB = build/libselsyn_native.a
TEST_SRC = tests/test_native.c
TEST_BIN = build/test_native

.PHONY: all clean test

all: $(TARGET_LIB)

build:
	mkdir -p build

$(TARGET_LIB): build $(OBJ)
	$(AR) $(ARFLAGS) $@ $(OBJ)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TEST_BIN): $(TARGET_LIB) $(TEST_SRC)
	$(CC) $(CFLAGS) $(TEST_SRC) $(TARGET_LIB) -lm -o $@

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -rf build src/*.o
