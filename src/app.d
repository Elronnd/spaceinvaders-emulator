import std.stdio;
import derelict.sdl2.image, derelict.sdl2.sdl, derelict.sdl2.ttf, derelict.sdl2.mixer;
import drawing;
import CPU;
import SDL;
import io;
import std.file: read;
import core.time: dur;
import core.thread: Thread;
import std.datetime: StopWatch;

enum dbg = 0;
enum ns_per_cycle = 500;
enum ns_per_screenrefresh = 16666666;


void main(string[] args) {
	auto sw = StopWatch();
	__gshared bool done;
	__gshared State s = new State();

	s.mem.memory = new ubyte[0x4000];
	s.mem.memory[0x0000 .. 0x07ff + 1] = cast(ubyte[])read("roam/invaders.h");
	s.mem.memory[0x0800 .. 0x0fff + 1] = cast(ubyte[])read("roam/invaders.g");
	s.mem.memory[0x1000 .. 0x17ff + 1] = cast(ubyte[])read("roam/invaders.f");
	s.mem.memory[0x1800 .. 0x1fff + 1] = cast(ubyte[])read("roam/invaders.e");


	new Thread({
		if (!SDL2.init("Space Invaders!")) {
			writefln("SDL error: %s", SDL2.err_msg());
			assert(0);
		}
		while (true) {
			auto sw2 = StopWatch();
			uint time_elapsed = 0;
			sw2.start();
			SDL_Event *ev;
			while ((ev = SDL2.poll_event()) !is null) {
				if ((ev.type != SDL_KEYDOWN) && (ev.type != SDL_KEYUP)) {
					continue;
				}
				switch (ev.key.keysym.sym) {
					case SDLK_LEFT:
						p1_left = ev.type == SDL_KEYDOWN;
						break;
					case SDLK_RIGHT:
						p1_right = ev.type == SDL_KEYDOWN;
						break;
					case SDLK_SPACE:
						p1_shoot = ev.type == SDL_KEYDOWN;
						break;
					case SDLK_RETURN:
						p1_start = ev.type == SDL_KEYDOWN;
						break;
					case SDLK_q:
						writeln("QUIT");
						SDL2.close;
						done = true;
						return;
				default: break;
				}
			}

			draw_screen(s.mem.memory);
			SDL2.refresh;
			time_elapsed = cast(uint)sw2.peek().nsecs;
			Thread.sleep(dur!"nsecs"(ns_per_screenrefresh - time_elapsed));
			sw2.reset();
		}
	}).start();
	sw.start();
	//print_dissasembly(s.mem);
	while (!done) {
		static if (dbg) {
			debug_instr(s);
		}

		int time_theoretical = step(s) * ns_per_cycle;
		int elapsed = cast(int)sw.peek().nsecs;
		int t = time_theoretical - elapsed;
		if (t < 0) {
			writeln("LAG OF ", t);
		} else {
			Thread.sleep(dur!"nsecs"(t));
		}
		sw.reset();
	}

quit:
}
