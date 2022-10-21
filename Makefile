NAME=Final

all: Final

clean:
	rm -rf Final Final.o

Final: Final.asm
	nasm -f elf -F dwarf -g Final.asm
	nasm -f elf -F dwarf -g thing.asm
	gcc -no-pie -g -m32 -o Final Final.o thing.o