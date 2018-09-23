import std.stdio;
static import opcodes;
import derelict.sdl2.image, derelict.sdl2.sdl, derelict.sdl2.ttf, derelict.sdl2.mixer;
import drawing;
import CPU;
import SDL;
import io;
import std.file: read;
import core.time: dur;
import core.thread: Thread;
import std.datetime.stopwatch: StopWatch;

enum dbg = 0;
enum ns_per_cycle = 500;
enum ns_per_frame = 16666666;
import core.stdc.time: time_t;
// d doesn't support c11
extern (C) struct timespec {
	time_t tv_sec;
	long tv_nsec;
}


extern (C) int timespec_get(timespec *ts, int base);
ulong time_mod_n(ulong n) {
	timespec t;
	timespec_get(&t, 1); // 1 is a reasonable guess for UTC
	return (t.tv_nsec + ((t.tv_sec % n) * (1_000_000 % n)) % n) % n;
}


void main(string[] args) {
	__gshared bool done;
	__gshared State s = new State();

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
					case SDLK_UP:
						p2_tilt = ev.type == SDL_KEYDOWN;
						break;
					case SDLK_SPACE:
						p1_shoot = ev.type == SDL_KEYDOWN;
						break;
					case SDLK_RETURN:
						writef("p1_start: %s", p1_start);
						p1_start = ev.type == SDL_KEYDOWN;
						writefln(" -> %s", p1_start);
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

		}
	}).start();
	//print_dissasembly(s.mem);

	enum Interrupt {
		Vblank,
		Hblank,
	}
	Interrupt interrupt_type;
	ulong cycles_this_interrupt;

	while (!done) {
		// intentionally unsigned.  It is allowed to go negative.  So, if we get to 16_666_664ns in this frame, then we want to execute 16_666_668ns worth of stuff next frame.  it Just Works™
		long ns_this_frame;
		while (true) {
			if ((cycles_this_interrupt * ns_per_cycle * 2) >= ns_per_frame) {
				ubyte[] interrupt;
				final switch (interrupt_type) {
					case Interrupt.Vblank:
						interrupt = [0xcf];
						break;
					case Interrupt.Hblank:
						interrupt = [0xd7];
						break;
				}
				if (s.interrupt_enabled) {
					writefln("%s", interrupt_type);
					s.interrupt_enabled = false;
					s.interrupt = interrupt;
					s.interrupted = true;
				}

				interrupt_type = cast(Interrupt)!interrupt_type;
				cycles_this_interrupt = 0;
			}


			// fetch the op
			ubyte op_b;
			ubyte[] op_args;

			if (s.interrupted) {
				op_b = s.interrupt[0];
			} else {
				op_b = s.mem.memory[s.mem.pc];
			}
			opcodes.Opcode op = opcodes.opcodes[op_b];
			ns_this_frame += op.cycles * ns_per_cycle;
			cycles_this_interrupt += op.cycles;


			// if it would push us over the the limit for one frame, then sleep now and defer it until the next frame
			if (ns_this_frame > ns_per_frame) {
				ns_this_frame -= ns_per_frame;
				break;
			}

			// now actually execute it
			if (s.interrupted) {
				op_args = s.interrupt[1 .. $];
			} else {
				s.mem.pc++;
				op_args = s.mem.memory[s.mem.pc .. s.mem.pc += op.size];
			}

			static if (dbg) {
				if (s.interrupted) {
					debug_instr(s, s.interrupt);
				} else {
					debug_instr(s);
				}
			}
			//s.mem.memory[0x20c0] = 0;
			ushort ans = op.fun(s, op_b, op_args);
			set_conditions(s, ans, op.cccodes_set);
			s.interrupted = false;
		}
		ulong sleep_time = ns_per_frame - time_mod_n(ns_per_frame);
		//writefln("Sleeping for %s", sleep_time);
		/*

		*/

		Thread.sleep(dur!"nsecs"(sleep_time));
	}
quit:
}
