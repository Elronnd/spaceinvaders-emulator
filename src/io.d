import CPU;
import std.stdio;
import SDL;
import derelict.sdl2.sdl;                                                                                                              


__gshared bool p1_start, p1_shoot, p1_left, p1_right;


ushort shift;
ubyte shift_offset;

ubyte IN(State state, ubyte port) {
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
			default: break;
		}
	}

	switch (port) {
		case 1:
			return 1 | (p1_start << 2) | (p1_shoot << 4) | (p1_left << 5) | (p1_right << 6);
		/*
		case 2:
		*/
		case 3:
			return (shift >> (8-shift_offset)) & 0xff;
		default:
			writefln("Unimplemented IN %s", port);
			return 0;
	}
}

void OUT(State state, ubyte port) {
	switch (port) {
		case 2:
			shift_offset = state.mem.a & 0b111;
			break;
		case 4:
			shift = ((shift << 8) | state.mem.a) & 0xffff;
			break;
		default:
			writefln("Unimplemented OUT %s", port);
		       	break;
	}
}
