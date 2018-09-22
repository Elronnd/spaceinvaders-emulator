import CPU;
import std.stdio;
import SDL;
import derelict.sdl2.sdl;                                                                                                              


__gshared bool p1_start, p1_start2, p1_shoot, p1_left, p1_right;
__gshared bool p2_tilt, p2_shoot, p2_left, p2_right;


ushort shift;
ubyte shift_offset;

ubyte IN(State state, ubyte port) {
	switch (port) {
		case 0:
			return 0 | (1 << 1) | (1 << 2) | (1 << 3) | (p1_shoot << 4) | (p1_left << 5) | (p1_right << 6);
		case 1:
			writeln("Queried port 1");
			return 1 | (p1_start << 2) | (1 << 3) | (p1_shoot << 4) | (p1_left << 5) | (p1_right << 6);
		case 2:
			return (p2_tilt << 2) | (p2_shoot << 4) | (p2_left << 5) | (p2_right << 6);
		case 3:
			return (shift >> (8-shift_offset)) & 0xff;
		default:
			//writefln("Unimplemented IN %s", port);
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
			//writefln("Unimplemented OUT %s", port);
		       	break;
	}
}
