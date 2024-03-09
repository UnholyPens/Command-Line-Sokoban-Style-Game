NAME=AssemblyAdv

all: AssemblyAdv

clean:
	rm -rf AssemblyAdv AssemblyAdv.o rawmode.o

AssemblyAdv: AssemblyAdv.asm
	nasm -f elf -F dwarf -g AssemblyAdv.asm
	nasm -f elf -F dwarf -g rawmode.asm
	gcc -no-pie -g -m32 -o AssemblyAdv AssemblyAdv.o rawmode.o