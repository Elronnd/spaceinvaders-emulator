import std.stdio;
import derelict.sdl2.image, derelict.sdl2.sdl, derelict.sdl2.ttf, derelict.sdl2.mixer;
import CPU;


void main(string[] args) {
	import std.file: read;

	Mem m;

	m.program = cast(ubyte[])read(args[1]);
	print_dissasembly(m);
	writeln("Edit source/app.d to start your project.");
}
