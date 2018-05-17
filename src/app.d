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
enum us_per_cycle = 2;
enum us_per_screenrefresh = 16666;


void main(string[] args) {
	auto sw = StopWatch();
	uint time_since_refresh;

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


	sw.start();
	//print_dissasembly(s.mem);
	while (true) {
		static if (dbg) {
			debug_instr(s);
		}
		if (time_since_refresh >= us_per_screenrefresh) {
			// munch events
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
						SDL2.close;
						goto quit;
					default: break;
				}
			}

			time_since_refresh -= us_per_screenrefresh;
			draw_screen(s.mem.memory);
			SDL2.refresh;
		}
		int time_theoretical = step(s) * us_per_cycle;
		int elapsed = cast(int)sw.peek().usecs;
		time_since_refresh += time_theoretical;
		int t = time_theoretical - elapsed;
		if (t < 0) {
			writeln("LAG OF ", t);
		} else {
			Thread.sleep(dur!"usecs"(t));
		}
		sw.reset();
	}

quit:
}
