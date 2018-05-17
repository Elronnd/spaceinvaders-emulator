import std.stdio;
import derelict.sdl2.image, derelict.sdl2.sdl, derelict.sdl2.ttf, derelict.sdl2.mixer;
import drawing;
import CPU;
import SDL;

enum dbg = 0;


void main(string[] args) {
	import std.file: read;

	State s = new State();
	s.mem.memory = new ubyte[0x4000];
	s.mem.memory[0x0000 .. 0x07ff + 1] = cast(ubyte[])read("roam/invaders.h");
	s.mem.memory[0x0800 .. 0x0fff + 1] = cast(ubyte[])read("roam/invaders.g");
	s.mem.memory[0x1000 .. 0x17ff + 1] = cast(ubyte[])read("roam/invaders.f");
	s.mem.memory[0x1800 .. 0x1fff + 1] = cast(ubyte[])read("roam/invaders.e");
	if (!SDL2.init("Space Invaders!")) {
		writefln("SDL error: %s", SDL2.err_msg());
		assert(0);
	}


	//print_dissasembly(s.mem);
	while (true) {
		static if (dbg) {
			debug_instr(s);
		}
		step(s);
//		draw_screen(s.mem.memory);
//		SDL2.refresh;
	}
}
