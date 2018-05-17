import CPU;
import std.algorithm.mutation: swap;

alias Opfun = ushort function(State state, ubyte opcode, ubyte[] args);

struct Opcode {
	// returns the answer if there was one
	Opfun fun;
	string opcode;
	string format_string;
	ubyte size; // number of arguments after the opcode
	bool invalid;
	Conditions cccodes_set = Conditions.none;
}

ushort un_impl(State state, ubyte opcode, ubyte[] args) {
	import std.stdio;
	writefln("Unimplemented opcode %s!", cformat(opcodes[opcode].opcode ~ " " ~ opcodes[opcode].format_string, args));
	return 0;
}
ushort nop(State state, ubyte opcode, ubyte[] args) {
	return 0;
}
// TODO: once dmd fixes their compiler bug move this back into a lambda
ushort ADI(State state, ubyte opcode, ubyte[] args) {
	ushort ans = cast(ushort)state.mem.a + cast(ushort)args[0];
	state.mem.a = ans & 0xff;
	return ans;
}
ushort ACI(State state, ubyte opcode, ubyte[] args) {
	ushort ans = cast(ushort)state.mem.a + cast(ushort)args[0] + state.condition.cy;
	state.mem.a = ans & 0xff;
	return ans;
}
ushort SUI(State state, ubyte opcode, ubyte[] args) {
	ushort ans = cast(ushort)(state.mem.a - args[0]);
	state.mem.a = ans & 0xff;
	return ans;
}

Opfun genmov(char to, char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			mixin(q{state.mem.} ~ to) = state.mem.memory[state.mem.hl];
		} else static if (to == 'm') {
			state.mem.memory[state.mem.hl] = mixin(q{state.mem.} ~ from);
		} else {
			mixin(q{state.mem.} ~ to) = mixin(q{state.mem.} ~ from);
		}
		return cast(ushort)0;
	};
}

// All adds add *to* a
Opfun genadd(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ans = cast(ushort)state.mem.a + cast(ushort)state.mem.memory[state.mem.hl];
		} else {
			ushort ans = cast(ushort)state.mem.a + cast(ushort)mixin(q{state.mem.} ~ from);
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
Opfun gensub(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ans = cast(ushort)(state.mem.a - cast(ushort)state.mem.memory[state.mem.hl]);
		} else {
			ushort ans = cast(ushort)(state.mem.a - cast(ushort)mixin(q{state.mem.} ~ from);
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
Opfun gensbb(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ans = cast(ushort)(state.mem.a - cast(ushort)state.mem.memory[state.mem.hl] - state.condition.cy);
		} else {
			ushort ans = cast(ushort)(state.mem.a - cast(ushort)mixin(q{state.mem.} ~ from) - state.condition.cy);
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
Opfun geninr(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			return ++state.mem.memory[state.mem.hl];
		} else {
			return ++mixin(q{state.mem.} ~ from);
		}
	};
}
Opfun gendcr(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			return --state.mem.memory[state.mem.hl];
		} else {
			return --mixin(q{state.mem.} ~ from);
		}
	};
}
Opfun genadc(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ans = cast(ushort)(state.mem.a + cast(ushort)state.mem.memory[state.mem.hl] + state.condition.cy);
		} else {
			ushort ans = cast(ushort)(state.mem.a + cast(ushort)mixin(q{state.mem.} ~ from) + state.condition.cy);
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
Opfun geninx(string from /* could be sp */)() {
	return (State state, ubyte opcode, ubyte[] args) {
		mixin(q{state.mem.} ~ from)++;

		return cast(ushort)0;
	};
}
Opfun gendcx(string from /* could be sp */)() {
	return (State state, ubyte opcode, ubyte[] args) {
		mixin(q{state.mem.} ~ from)--;

		return cast(ushort)0;
	};
}

Opfun genlxi(string from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		mixin(q{state.mem.} ~ from) = (args[1] << 8) | args[0];
		return cast(ushort)0;
	};
}
Opfun genstax(string from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		state.mem.memory[mixin(q{state.mem.} ~ from)] = state.mem.a;
		return cast(ushort)0;
	};
}
Opfun genmvi(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			state.mem.memory[state.mem.hl] = args[0];
		} else {
			mixin(q{state.mem.} ~ from) = args[0];
		}
		return cast(ushort)0;
	};
}
Opfun gendad(string from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		uint res = state.mem.hl + mixin(q{state.mem.} ~ from);
		if (res & 0xffff0000) {
			state.condition.cy = true;
		}
		state.mem.hl = cast(ushort)(res & 0x0000ffff);

		return cast(ushort)0;
	};
}
Opfun genldax(string from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		state.mem.a = state.mem.memory[mixin(q{state.mem.} ~ from)];
		return cast(ushort)0;
	};
}
Opfun genana(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ret = state.mem.a & state.mem.memory[state.mem.hl];
		} else {
			ushort ret = state.mem.a & mixin(q{state.mem.} ~ from);
		}
		state.mem.a = ret & 0xff;
		return ret;
	};
}
Opfun genxra(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ret = state.mem.a ^ state.mem.memory[state.mem.hl];
		} else {
			ushort ret = state.mem.a ^ mixin(q{state.mem.} ~ from);
		}
		state.mem.a = ret & 0xff;
		return ret;
	};
}
Opfun genora(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			ushort ret = state.mem.a | state.mem.memory[state.mem.hl];
		} else {
			ushort ret = state.mem.a | mixin(q{state.mem.} ~ from);
		}
		state.mem.a = ret & 0xff;
		return ret;
	};
}
Opfun gencjmp(string from, bool expected)() {
	return (State state, ubyte opcode, ubyte[] args) {
		if (mixin(q{state.condition.} ~ from) == expected) {
			state.mem.pc = (args[1] << 8) | args[0];
		}
		return cast(ushort)0;
	};
}
Opfun genccall(string from, bool expected)() {
	return (State state, ubyte opcode, ubyte[] args) {
		if (mixin(q{state.condition.} ~ from) == expected) {
			state.call((args[1] << 8) | args[0]);
		}
		return cast(ushort)0;
	};
}
Opfun gencret(string from, bool expected)() {
	return (State state, ubyte opcode, ubyte[] args) {
		if (mixin(q{state.condition.} ~ from) == expected) {
			state.ret;
		}
		return cast(ushort)0;
	};
}
void push(State state, ubyte value) {
	state.mem.memory[--state.mem.sp] = value;
}
ubyte pop(State state) {
	return state.mem.memory[state.mem.sp++];
}
void call(State state, ushort addr) {
	state.push(addr >> 8);
	state.push(addr & 0xff);
	state.mem.pc = addr;
}
void ret(State state) {
	ubyte lo, hi;
	lo = state.pop;
	hi = state.pop; // order of evaluation is undefined
	state.mem.pc = (hi << 8) | lo;
}
Opfun genrst(ushort target_addr)() {
	return (State state, ubyte opcode, ubyte[] args) {
		state.call(target_addr);
		return cast(ushort)0;
	};
}
Opfun gencmp(char target)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (target == 'm') {
			return cast(ushort)(state.mem.a - state.mem.memory[state.mem.hl]);
		} else {
			return cast(ushort)(state.mem.a - mixin(q{state.mem.} ~ target));
		}
	};
}



// custom formatter.  Just accepts '%!' by itself (or %% to escape)
immutable Opcode[] opcodes = [
	/*0x00: */{&nop, "NOP"},
	/*0x01: */{genlxi!"bc", "LXI", "B,#$%1%0", 2},
	/*0x02: */{genstax!"bc", "STAX B"},
	/*0x03: */{geninx!"b", "INX B"},
	/*0x04: */{geninr!'b', "INR B", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x05: */{gendcr!'b', "DCR B", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x06: */{genmvi!'b', "MVI", "B,#0x%!", 1},
	/*0x07: */{(State state, ubyte opcode, ubyte[] args) { /* manually set cy because it's set differently */ state.condition.cy = (state.mem.a >> 7); state.mem.a = cast(ubyte)(((state.mem.a << 1) | (state.mem.a >> 7)) & 0xff); return cast(ushort)0; }, "RLC"},
	/*0x08: */{&nop, "NOP"},
	/*0x09: */{gendad!"bc", "DAD B", cccodes_set:Conditions.cy},
	/*0x0a: */{genldax!"bc", "LDAX B"},
	/*0x0b: */{gendcx!"b", "DCX B"},
	/*0x0c: */{geninr!'c', "INR C", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x0d: */{gendcr!'c', "DCR C", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x0e: */{genmvi!'c', "MVI", "C,#$%!", 1},
	/*0x0f: */{(State state, ubyte opcode, ubyte[] args) { /* Ditto for cy */ state.condition.cy = state.mem.a & 0b00000001; state.mem.a = cast(ubyte)(((state.mem.a >> 1) | (state.mem.a << 7)) & 0xff); return cast(ushort)0; }, "RRC"},
	/*0x10: */{&nop, "NOP"},
	/*0x11: */{genlxi!"de", "LXI", "D,#$%1%0", 2},
	/*0x12: */{genstax!"de", "STAX D"},
	/*0x13: */{geninx!"d", "INX D"},
	/*0x14: */{geninr!'d', "INR D", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x15: */{gendcr!'d', "DCR D", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x16: */{genmvi!'d', "MVI", "D,#$%!", 1},
	/*0x17: */{(State state, ubyte opcode, ubyte[] args) { /* Yeah I have no idea wtf is going on with this opcode */ bool newcy = cast(bool)(state.mem.a & 0b10000000); state.mem.a = cast(ubyte)(((state.mem.a << 1)&0xff) | state.condition.cy); state.condition.cy = newcy; return cast(ushort)0; }, "RAL"},
	/*0x18: */{&nop, "NOP"},
	/*0x19: */{gendad!"de", "DAD D", cccodes_set:Conditions.cy},
	/*0x1a: */{genldax!"de", "LDAX D"},
	/*0x1b: */{gendcx!"d", "DCX D"},
	/*0x1c: */{geninr!'e', "INR E", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x1d: */{gendcr!'e', "DCR E", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x1e: */{genmvi!'e', "MVI", "E,#$%!", 1},
	/*0x1f: */{(State state, ubyte opcode, ubyte[] args) { /* This one is even weirder.  Basically treat the bottom 7 bits of a and the carry bit all together as a byte, and right shift????????? */ ubyte bit7 = state.mem.a & 0b10000000; bool bit0 = state.mem.a & 0b00000001; state.mem.a = (state.mem.a >> 1) | bit7; state.condition.cy = bit0; return cast(ushort)0; }, "RAR"},
	/*0x20: */{&un_impl, "RIM"}, // "special".  Whatever the hell that means.
	/*0x21: */{genlxi!"hl", "LXI", "H,#$%1%0", 2},
	/*0x22: */{(State state, ubyte opcode, ubyte[] args) { ushort ptr = (args[1] << 8) | args[0]; state.mem.memory[ptr] = state.mem.l; state.mem.memory[ptr+1] = state.mem.h; return cast(ushort)0; }, "SHLD", "#$%1%0 = LH", 2},
	/*0x23: */{geninx!"h", "INX H"},
	/*0x24: */{geninr!'h', "INR H", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x25: */{gendcr!'h', "DCR H", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x26: */{genmvi!'h', "MVI", "H,#$%!", 1},
	/*0x27: */{&un_impl, "DAA", "special"},
	/*0x28: */{&nop, "NOP"},
	/*0x29: */{gendad!"hl", "DAD H", cccodes_set:Conditions.cy},
	/*0x2a: */{(State state, ubyte opcode, ubyte[] args) { ushort ptr = (args[1] << 8) | args[0]; state.mem.l = state.mem.memory[ptr]; state.mem.h = state.mem.memory[ptr+1]; return cast(ushort)0; }, "LHLD", "LH = #$%1%0"},
	/*0x2b: */{gendcx!"h", "DCX H"},
	/*0x2c: */{geninr!'l', "INR L", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x2d: */{gendcr!'l', "DCR L", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x2e: */{genmvi!'l', "MVI", "L,#$%!", 1},
	/*0x2f: */{(State state, ubyte opcode, ubyte[] args) { state.mem.a = ~state.mem.a; return cast(ushort)0; }, "CMA"},
	/*0x30: */{&un_impl, "SIM", "special"},
	/*0x31: */{genlxi!"sp", "LXI", "SP,#$%1%0", 2},
	/*0x32: */{(State state, ubyte opcode, ubyte[] args) { state.mem.memory[(args[1] << 8) | args[0]] = state.mem.a; return cast(ushort)0; }, "STA", "$%1%0", 2},
	/*0x33: */{geninx!"sp", "INX", "SP"},
	/*0x34: */{geninr!'m', "INR M", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x35: */{gendcr!'m', "DCR M", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x36: */{genmvi!'m', "MVI", "M,#$%!", 1},
	/*0x37: */{(State state, ubyte opcode, ubyte[] args) { /* Why TF is this SeT Carry instead of STore C???  Be consistent, intel!! */ state.condition.cy = true; return cast(ushort)0; }, "STC"},
	/*0x38: */{&nop, "NOP"},
	/*0x39: */{gendad!"sp", "DAD SP", cccodes_set:Conditions.cy},
	/*0x3a: */{(State state, ubyte opcode, ubyte[] args) { state.mem.a = state.mem.memory[(args[1] << 8) | args[0]]; return cast(ushort)0; }, "LDA", "$%1%0", 2},
	/*0x3b: */{gendcx!"sp", "DCX SP"},
	/*0x3c: */{geninr!'a', "INR A", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x3d: */{gendcr!'a', "DCR A", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x3e: */{genmvi!'a', "MVI", "A,#0x%!", 1},
	/*0x3f: */{(State state, ubyte opcode, ubyte[] args) { state.condition.cy = !state.condition.cy; return cast(ushort)0; }, "CMC"},
	/*0x40: */{genmov!('b', 'b'), "MOV", "B,B"},
	/*0x41: */{genmov!('b', 'c'), "MOV", "B,C"},
	/*0x42: */{genmov!('b', 'd'), "MOV", "B,D"},
	/*0x43: */{genmov!('b', 'e'), "MOV", "B,E"},
	/*0x44: */{genmov!('b', 'h'), "MOV", "B,H"},
	/*0x45: */{genmov!('b', 'l'), "MOV", "B,L"},
	/*0x46: */{genmov!('b', 'm'), "MOV", "B,M"},
	/*0x47: */{genmov!('b', 'a'), "MOV", "B,A"},
	/*0x48: */{genmov!('c', 'b'), "MOV", "C,B"},
	/*0x49: */{genmov!('c', 'c'), "MOV", "C,C"},
	/*0x4a: */{genmov!('c', 'd'), "MOV", "C,D"},
	/*0x4b: */{genmov!('c', 'e'), "MOV", "C,E"},
	/*0x4c: */{genmov!('c', 'h'), "MOV", "C,H"},
	/*0x4d: */{genmov!('c', 'l'), "MOV", "C,L"},
	/*0x4e: */{genmov!('c', 'm'), "MOV", "C,M"},
	/*0x4f: */{genmov!('c', 'a'), "MOV", "C,A"},
	/*0x50: */{genmov!('d', 'b'), "MOV", "D,B"},
	/*0x51: */{genmov!('d', 'c'), "MOV", "D,C"},
	/*0x52: */{genmov!('d', 'd'), "MOV", "D,D"},
	/*0x53: */{genmov!('d', 'e'), "MOV", "D,E"},
	/*0x54: */{genmov!('d', 'h'), "MOV", "D,H"},
	/*0x55: */{genmov!('d', 'l'), "MOV", "D,L"},
	/*0x56: */{genmov!('d', 'm'), "MOV", "D,M"},
	/*0x57: */{genmov!('d', 'a'), "MOV", "D,A"},
	/*0x58: */{genmov!('e', 'b'), "MOV", "E,B"},
	/*0x59: */{genmov!('e', 'c'), "MOV", "E,C"},
	/*0x5a: */{genmov!('e', 'd'), "MOV", "E,D"},
	/*0x5b: */{genmov!('e', 'e'), "MOV", "E,E"},
	/*0x5c: */{genmov!('e', 'h'), "MOV", "E,H"},
	/*0x5d: */{genmov!('e', 'l'), "MOV", "E,L"},
	/*0x5e: */{genmov!('e', 'm'), "MOV", "E,M"},
	/*0x5f: */{genmov!('e', 'a'), "MOV", "E,A"},
	/*0x60: */{genmov!('h', 'b'), "MOV", "H,B"},
	/*0x61: */{genmov!('h', 'c'), "MOV", "H,C"},
	/*0x62: */{genmov!('h', 'd'), "MOV", "H,D"},
	/*0x63: */{genmov!('h', 'e'), "MOV", "H,E"},
	/*0x64: */{genmov!('h', 'h'), "MOV", "H,H"},
	/*0x65: */{genmov!('h', 'l'), "MOV", "H,L"},
	/*0x66: */{genmov!('h', 'm'), "MOV", "H,M"},
	/*0x67: */{genmov!('h', 'c'), "MOV", "H,A"},
	/*0x68: */{genmov!('l', 'b'), "MOV", "L,B"},
	/*0x69: */{genmov!('l', 'c'), "MOV", "L,C"},
	/*0x6a: */{genmov!('l', 'd'), "MOV", "L,D"},
	/*0x6b: */{genmov!('l', 'e'), "MOV", "L,E"},
	/*0x6c: */{genmov!('l', 'h'), "MOV", "L,H"},
	/*0x6d: */{genmov!('l', 'l'), "MOV", "L,L"},
	/*0x6e: */{genmov!('l', 'm'), "MOV", "L,M"},
	/*0x6f: */{genmov!('l', 'a'), "MOV", "L,A"},
	/*0x70: */{genmov!('m', 'b'), "MOV", "M,B"},
	/*0x71: */{genmov!('m', 'c'), "MOV", "M,C"},
	/*0x72: */{genmov!('m', 'd'), "MOV", "M,D"},
	/*0x73: */{genmov!('m', 'e'), "MOV", "M,E"},
	/*0x74: */{genmov!('m', 'h'), "MOV", "M,H"},
	/*0x75: */{genmov!('m', 'l'), "MOV", "M,L"},
	/*0x76: */{&un_impl, "HLT"},
	/*0x77: */{genmov!('m', 'a'), "MOV", "M,A"},
	/*0x78: */{genmov!('a', 'b'), "MOV", "A,B"},
	/*0x79: */{genmov!('a', 'c'), "MOV", "A,C"},
	/*0x7a: */{genmov!('a', 'd'), "MOV", "A,D"},
	/*0x7b: */{genmov!('a', 'e'), "MOV", "A,E"},
	/*0x7c: */{genmov!('a', 'h'), "MOV", "A,H"},
	/*0x7d: */{genmov!('a', 'l'), "MOV", "A,L"},
	/*0x7e: */{genmov!('a', 'm'), "MOV", "A,M"},
	/*0x7f: */{genmov!('a', 'a'), "MOV", "A,A"},
	/*0x80: */{genadd!'b', "ADD", "B", cccodes_set:Conditions.all},
	/*0x81: */{genadd!'c', "ADD", "C", cccodes_set:Conditions.all},
	/*0x82: */{genadd!'d', "ADD", "D", cccodes_set:Conditions.all},
	/*0x83: */{genadd!'e', "ADD", "E", cccodes_set:Conditions.all},
	/*0x84: */{genadd!'h', "ADD", "H", cccodes_set:Conditions.all},
	/*0x85: */{genadd!'l', "ADD", "L", cccodes_set:Conditions.all},
	/*0x86: */{genadd!'m', "ADD", "M", cccodes_set:Conditions.all},
	/*0x87: */{genadd!'a', "ADD", "A", cccodes_set:Conditions.all},
	/*0x88: */{genadc!'b', "ADC", "B", cccodes_set:Conditions.all},
	/*0x89: */{genadc!'c', "ADC", "C", cccodes_set:Conditions.all},
	/*0x8a: */{genadc!'d', "ADC", "D", cccodes_set:Conditions.all},
	/*0x8b: */{genadc!'e', "ADC", "E", cccodes_set:Conditions.all},
	/*0x8c: */{genadc!'h', "ADC", "H", cccodes_set:Conditions.all},
	/*0x8d: */{genadc!'l', "ADC", "L", cccodes_set:Conditions.all},
	/*0x8e: */{genadc!'m', "ADC", "M", cccodes_set:Conditions.all},
	/*0x8f: */{genadc!'a', "ADC", "A", cccodes_set:Conditions.all},
	/*0x90: */{gensub!'b', "SUB", "B", cccodes_set:Conditions.all},
	/*0x91: */{gensub!'c', "SUB", "C", cccodes_set:Conditions.all},
	/*0x92: */{gensub!'d', "SUB", "D", cccodes_set:Conditions.all},
	/*0x93: */{gensub!'e', "SUB", "E", cccodes_set:Conditions.all},
	/*0x94: */{gensub!'h', "SUB", "H", cccodes_set:Conditions.all},
	/*0x95: */{gensub!'l', "SUB", "L", cccodes_set:Conditions.all},
	/*0x96: */{gensub!'m', "SUB", "M", cccodes_set:Conditions.all},
	/*0x97: */{gensub!'a', "SUB", "A", cccodes_set:Conditions.all},
	/*0x98: */{gensbb!'b', "SBB", "B", cccodes_set:Conditions.all},
	/*0x99: */{gensbb!'c', "SBB", "C", cccodes_set:Conditions.all},
	/*0x9a: */{gensbb!'d', "SBB", "D", cccodes_set:Conditions.all},
	/*0x9b: */{gensbb!'e', "SBB", "E", cccodes_set:Conditions.all},
	/*0x9c: */{gensbb!'h', "SBB", "H", cccodes_set:Conditions.all},
	/*0x9d: */{gensbb!'l', "SBB", "L", cccodes_set:Conditions.all},
	/*0x9e: */{gensbb!'m', "SBB", "M", cccodes_set:Conditions.all},
	/*0x9f: */{gensbb!'a', "SBB", "A", cccodes_set:Conditions.all},
	/*0xa0: */{genana!'b', "ANA", "B", cccodes_set:Conditions.all},
	/*0xa1: */{genana!'c', "ANA", "C", cccodes_set:Conditions.all},
	/*0xa2: */{genana!'d', "ANA", "D", cccodes_set:Conditions.all},
	/*0xa3: */{genana!'e', "ANA", "E", cccodes_set:Conditions.all},
	/*0xa4: */{genana!'h', "ANA", "H", cccodes_set:Conditions.all},
	/*0xa5: */{genana!'l', "ANA", "L", cccodes_set:Conditions.all},
	/*0xa6: */{genana!'m', "ANA", "M", cccodes_set:Conditions.all},
	/*0xa7: */{genana!'a', "ANA", "A", cccodes_set:Conditions.all},
	/*0xa8: */{genxra!'b', "XRA", "B", cccodes_set:Conditions.all},
	/*0xa9: */{genxra!'c', "XRA", "C", cccodes_set:Conditions.all},
	/*0xaa: */{genxra!'d', "XRA", "D", cccodes_set:Conditions.all},
	/*0xab: */{genxra!'e', "XRA", "E", cccodes_set:Conditions.all},
	/*0xac: */{genxra!'h', "XRA", "H", cccodes_set:Conditions.all},
	/*0xad: */{genxra!'l', "XRA", "L", cccodes_set:Conditions.all},
	/*0xae: */{genxra!'m', "XRA", "M", cccodes_set:Conditions.all},
	/*0xaf: */{genxra!'a', "XRA", "A", cccodes_set:Conditions.all},
	/*0xb0: */{genora!'b', "ORA", "B", cccodes_set:Conditions.all},
	/*0xb1: */{genora!'c', "ORA", "C", cccodes_set:Conditions.all},
	/*0xb2: */{genora!'d', "ORA", "D", cccodes_set:Conditions.all},
	/*0xb3: */{genora!'e', "ORA", "E", cccodes_set:Conditions.all},
	/*0xb4: */{genora!'h', "ORA", "H", cccodes_set:Conditions.all},
	/*0xb5: */{genora!'l', "ORA", "L", cccodes_set:Conditions.all},
	/*0xb6: */{genora!'m', "ORA", "M", cccodes_set:Conditions.all},
	/*0xb7: */{genora!'a', "ORA", "A", cccodes_set:Conditions.all},
	/*0xb8: */{gencmp!'b', "CMP", "B", cccodes_set:Conditions.all},
	/*0xb9: */{gencmp!'c', "CMP", "C", cccodes_set:Conditions.all},
	/*0xba: */{gencmp!'d', "CMP", "D", cccodes_set:Conditions.all},
	/*0xbb: */{gencmp!'e', "CMP", "E", cccodes_set:Conditions.all},
	/*0xbc: */{gencmp!'h', "CMP", "H", cccodes_set:Conditions.all},
	/*0xbd: */{gencmp!'l', "CMP", "L", cccodes_set:Conditions.all},
	/*0xbe: */{gencmp!'m', "CMP", "M", cccodes_set:Conditions.all},
	/*0xbf: */{gencmp!'a', "CMP", "A", cccodes_set:Conditions.all},
	/*0xc0: */{gencret!("z", false), "RNZ"},
	/*0xc1: */{(State state, ubyte opcode, ubyte[] args) { state.mem.c = state.pop; state.mem.b = state.pop; return cast(ushort)0; }, "POP", "B"},
	/*0xc2: */{gencjmp!("z", false), "JNZ", "$%1%0", 2},
	/*0xc3: */{(State state, ubyte opcode, ubyte[] args) { state.mem.pc = (args[1] << 8) | args[0]; return cast(ushort)0; }, "JMP", "$%1%0", 2},
	/*0xc4: */{genccall!("z", false), "CNZ", "$%1%0", 2},
	/*0xc5: */{(State state, ubyte opcode, ubyte[] args) { state.push(state.mem.b); state.push(state.mem.c); return cast(ushort)0; }, "PUSH", "B"},
	/*0xc6: */{&ADI, "ADI", "#$%!", 1, cccodes_set:Conditions.all},
	/*0xc7: */{genrst!0, "RST 0"},
	/*0xc8: */{gencret!("z", true), "RZ"},
	/*0xc9: */{(State state, ubyte opcode, ubyte[] args) { state.ret; return cast(ushort)0; }, "RET"},
	/*0xca: */{gencjmp!("z", true), "JZ", "$%1%0", 2},
	/*0xcb: */{&nop, "NOP"},
	/*0xcc: */{genccall!("z", true), "CZ", "$%1%0", 2},
	/*0xcd: */{(State state, ubyte opcode, ubyte[] args) { state.call((args[1] << 8) | args[0]); return cast(ushort)0; }, "CALL", "$%1%0", 2},
	/*0xce: */{&ACI, "ACI", "#$%!", 1},
	/*0xcf: */{genrst!0x8, "RST", "1"},
	/*0xd0: */{gencret!("cy", false), "RNC"},
	/*0xd1: */{(State state, ubyte opcode, ubyte[] args) { state.mem.e = state.pop; state.mem.d = state.pop; return cast(ushort)0; }, "POP", "D"},
	/*0xd2: */{gencjmp!("cy", false), "JNC", "$%1%0", 2},
	/*0xd3: */{&un_impl, "OUT", "Special?  %!", 1},
	/*0xd4: */{genccall!("cy", false), "CNC", "$%1%0", 2},
	/*0xd5: */{(State state,  ubyte opcode, ubyte[] args) { state.push(state.mem.d); state.push(state.mem.e); return cast(ushort)0; }, "PUSH", "D"},
	/*0xd6: */{&SUI, "SUI", "#$%!", 1},
	/*0xd7: */{genrst!0x10, "RST", "2"},
	/*0xd8: */{gencret!("cy", true), "RC"},
	/*0xd9: */{&nop, "NOP"},
	/*0xda: */{gencjmp!("cy", true), "JC", "$%1%0", 2},
	/*0xdb: */{&un_impl, "IN", "#$%! (special)", 1},
	/*0xdc: */{genccall!("cy", true), "CC", "$%1%0", 2},
	/*0xdd: */{&nop, "NOP"},
	/*0xde: */{&un_impl, "SBI", "#$%!", 1},
	/*0xdf: */{genrst!0x18, "RST 3"},
	/*0xe0: */{gencret!("p", false), "RPO"},
	/*0xe1: */{(State state, ubyte opcode, ubyte[] args) { state.mem.l = state.pop; state.mem.h = state.pop; return cast(ushort)0; }, "POP H"},
	/*0xe2: */{gencjmp!("p", false), "JPO", "$%1%0", 2},
	/*0xe3: */{(State state, ubyte opcode, ubyte[] args) { ubyte h = state.mem.h; ubyte l = state.mem.l; state.mem.l = state.pop; state.mem.h = state.pop; state.push(h); state.push(l); return cast(ushort)0; }, "XTHL"},
	/*0xe4: */{genccall!("p", false), "CPO", "$%1%0", 2},
	/*0xe5: */{(State state, ubyte opcode, ubyte[] args) { state.push(state.mem.h); state.push(state.mem.l); return cast(ushort)0; }, "PUSH", "H"},
	/*0xe6: */{(State state, ubyte opcode, ubyte[] args) { state.mem.a &= args[0]; return state.mem.a; }, "ANI", "#$%!", 1},
	/*0xe7: */{genrst!0x20, "RST 4"},
	/*0xe8: */{gencret!("p", true), "RPE"},
	/*0xe9: */{(State state, ubyte opcode, ubyte[] args) { state.mem.pc = state.mem.hl; return cast(ushort)0; }, "PCHL"},
	/*0xea: */{gencjmp!("p", true), "JPE", "$%1%0", 2},
	/*0xeb: */{(State state, ubyte opcode, ubyte[] args) { swap(state.mem.hl, state.mem.de); return cast(ushort)0; }, "XCHG"},
	/*0xec: */{genccall!("p", true), "CPE", "$%1%0", 2},
	/*0xed: */{&nop, "NOP"},
	/*0xee: */{&un_impl, "XRI", "#$%!", 1},
	/*0xef: */{genrst!0x28, "RST", "5"},
	/*0xf0: */{gencret!("s", false), "RP"},
	/*0xf1: */{(State state, ubyte opcode, ubyte[] args) { ubyte flags = state.pop; state.mem.a = state.pop; state.condition.cy = flags & 1; state.condition.p = cast(bool)(flags & 0b00000100); state.condition.ac = cast(bool)(flags & 0b00010000); state.condition.z = cast(bool)(flags & 0b01000000); state.condition.s = cast(bool)(flags & 0b10000000); return cast(ushort)0; }, "POP", "PSW"},
	/*0xf2: */{gencjmp!("s", false), "JP", "$%1%0", 2},
	/*0xf3: */{(State state, ubyte opcode, ubyte[] args) { state.interrupt_enabled = false; return cast(ushort)0; }, "DI"},
	/*0xf4: */{genccall!("s", false), "CP", "$%1%0", 2},
	/*0xf5: */{(State state, ubyte opcode, ubyte[] args) { state.push(state.mem.a); state.push(state.condition.cy | (1 << 1) | (state.condition.p << 2) | (0 << 3) | (state.condition.ac << 4) | (0 << 5) | (state.condition.z << 6) | (state.condition.s << 7)); return cast(ushort)0; }, "PUSH", "PSW"},
	/*0xf6: */{&un_impl, "ORI", "#$%!", 1},
	/*0xf7: */{genrst!0x30, "RST", "6"},
	/*0xf8: */{gencret!("s", true), "RM"},
	/*0xf9: */{(State state, ubyte opcode, ubyte[] args) { state.mem.sp = state.mem.hl; return cast(ushort)0; }, "SPHL"},
	/*0xfa: */{gencjmp!("s", true), "JM", "$%1%0", 2},
	/*0xfb: */{(State state, ubyte opcode, ubyte[] args) { state.interrupt_enabled = true; return cast(ushort)0; }, "EI"},
	/*0xfc: */{genccall!("s", true), "CM", "$%1%0", 2},
	/*0xfd: */{&nop, "NOP"},
	/*0xfe: */{(State state, ubyte opcode, ubyte[] args) { state.condition.cy = state.mem.a < args[0]; ubyte x = cast(ubyte)(state.mem.a - args[0]); return x; }, "CPI", "#$%!", 1, cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0xff: */{genrst!0x38, "RST", "7"},
	];
