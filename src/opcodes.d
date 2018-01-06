import CPU;

struct Opcode {
	// returns the answer if there was one
	ushort function(State state, ubyte opcode, ubyte[] args) fun;
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
	ushort ans = cast(ushort)state.mem.a - cast(ushort)args[0];
	state.mem.a = ans & 0xff;
	return ans;
}

ushort function(State state, ubyte opcode, ubyte[] args) genmov(char to, char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			mixin("state.mem." ~ to ~ " = state.mem.memory[(state.mem.h << 8) | (state.mem.l)];");
		} else static if (to == 'm') {
			mixin("state.mem.memory[(state.mem.h << 8) | (state.mem.l)] = state.mem." ~ from ~ ";");
		} else {
			mixin("state.mem." ~ to ~ " = state.mem." ~ from ~ ";");
		}
		return cast(ushort)0;
	};
}

// All adds add *to* a
ushort function(State state, ubyte opcode, ubyte[] args) genadd(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			mixin("ushort ans = cast(ushort)state.mem.a + cast(ushort)state.mem.memory[(state.mem.h << 8) | (state.mem.l)];");
		} else {
			mixin("ushort ans = cast(ushort)state.mem.a + cast(ushort)state.mem." ~ from ~ ";");
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
ushort function(State state, ubyte opcode, ubyte[] args) gensub(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			mixin("ushort ans = cast(ushort)(state.mem.a - cast(ushort)state.mem.memory[(state.mem.h << 8) | (state.mem.l)]);");
		} else {
			mixin("ushort ans = cast(ushort)(state.mem.a - cast(ushort)state.mem." ~ from ~ ");");
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
ushort function(State state, ubyte opcode, ubyte[] args) gensbb(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			mixin("ushort ans = cast(ushort)(state.mem.a - cast(ushort)state.mem.memory[(state.mem.h << 8) | (state.mem.l)] - state.condition.cy);");
		} else {
			mixin("ushort ans = cast(ushort)(state.mem.a - cast(ushort)state.mem." ~ from ~ " - state.condition.cy);");
		}

		state.mem.a = ans&0xff;
		return ans;
	};
}
ushort function(State state, ubyte opcode, ubyte[] args) geninr(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			return ++state.mem.memory[(state.mem.h << 8) | (state.mem.l)];
		} else {
			return ++mixin("state.mem." ~ from);
		}
	};
}
ushort function(State state, ubyte opcode, ubyte[] args) gendcr(char from)() {
	return (State state, ubyte opcode, ubyte[] args) {
		static if (from == 'm') {
			return --state.mem.memory[(state.mem.h << 8) | (state.mem.l)];
		} else {
			return --mixin("state.mem." ~ from);
		}  
	};
}

// custom formatter.  Just accepts '%!' by itself (or %% to escape)
Opcode[] opcodes = [
	/*0x00: */{&nop, "NOP"},
	/*0x01: */{((State state, ubyte opcode, ubyte[] args) => cast(ushort)(((state.mem.c = args[0]) | (state.mem.b = args[1])) & 0)) /* I am...terribly sorry for this abomination.  But the compiler was buggy */, "LXI", "B,#$%1%0", 2},
	/*0x02: */{&un_impl, "STAX B"},
	/*0x03: */{&un_impl, "INX B"},
	/*0x04: */{geninr!'b', "INR B", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x05: */{gendcr!'b', "DCR B", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x06: */{&un_impl, "MVI", "B,#0x%!", 1},
	/*0x07: */{&un_impl, "RLC"},
	/*0x08: */{&nop, "NOP"},
	/*0x09: */{&un_impl, "DAD B", cccodes_set:Conditions.cy}, // manually set just carry
	/*0x0a: */{&un_impl, "LDAX B"},
	/*0x0b: */{&un_impl, "DCX B"},
	/*0x0c: */{geninr!'c', "INR C", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x0d: */{gendcr!'c', "DCR C", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x0e: */{&un_impl, "MVI", "C,#$%!", 1},
	/*0x0f: */{&un_impl, "RRC"},
	/*0x10: */{&nop, "NOP"},
	/*0x11: */{&un_impl, "LXI", "D,#$%1%0", 2},
	/*0x12: */{&un_impl, "STAX D"},
	/*0x13: */{&un_impl, "INX D"},
	/*0x14: */{geninr!'d', "INR D", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x15: */{gendcr!'d', "DCR D", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x16: */{&un_impl, "MVI", "D,#$%!", 1},
	/*0x17: */{&un_impl, "RAL"},
	/*0x18: */{&nop, "NOP"},
	/*0x19: */{&un_impl, "DAD D"}, // manually set just carry
	/*0x1a: */{&un_impl, "LDAX D"},
	/*0x1b: */{&un_impl, "DCX D"},
	/*0x1c: */{geninr!'e', "INR E", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x1d: */{gendcr!'e', "DCR E", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x1e: */{&un_impl, "MVI", "E,#$%!", 1},
	/*0x1f: */{&un_impl, "RAR"},
	/*0x20: */{&un_impl, "RIM"},
	/*0x21: */{&un_impl, "LXI", "H,#$%1%0", 2},
	/*0x22: */{&un_impl, "SHLD", "TODO what the fuck (adr) <-L; (adr+1)<-H", 2},
	/*0x23: */{&un_impl, "INX H"},
	/*0x24: */{geninr!'h', "INR H", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x25: */{gendcr!'h', "DCR H", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x26: */{&un_impl, "MVI", "H,#$%!", 1},
	/*0x27: */{&un_impl, "DAA", "special"},
	/*0x28: */{&nop, "NOP"},
	/*0x29: */{&un_impl, "DAD H"},
	/*0x2a: */{&un_impl, "LHLD", "TODO what the fuck (same as SHDL"},
	/*0x2b: */{&un_impl, "DCX H"},
	/*0x2c: */{geninr!'l', "INR L", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x2d: */{gendcr!'l', "DCR L", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x2e: */{&un_impl, "MVI", "L,#$%!", 1},
	/*0x2f: */{&un_impl, "CMA"},
	/*0x30: */{&un_impl, "SIM", "special"},
	/*0x31: */{&un_impl, "LXI", "SP,#$%1%0", 2},
	/*0x32: */{&un_impl, "STA", "$%1%0", 2},
	/*0x33: */{&un_impl, "INX", "SP"},
	/*0x34: */{geninr!'m', "INR M", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x35: */{gendcr!'m', "DCR M", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x36: */{&un_impl, "MVI", "M,#$%!", 1},
	/*0x37: */{&un_impl, "STC"},
	/*0x38: */{&nop, "NOP"},
	/*0x39: */{&un_impl, "DAD SP"},
	/*0x3a: */{&un_impl, "LDA", "$%1%0", 2},
	/*0x3b: */{&un_impl, "DCX SP"},
	/*0x3c: */{geninr!'a', "INR A", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x3d: */{gendcr!'a', "DCR A", cccodes_set:Conditions.all & ~(Conditions.cy)},
	/*0x3e: */{&un_impl, "MVI", "A,#0x%!", 1},
	/*0x3f: */{&un_impl, "CMC"},
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
	/*0x88: */{&un_impl, "ADC", "B"},
	/*0x89: */{&un_impl, "ADC", "C"},
	/*0x8a: */{&un_impl, "ADC", "D"},
	/*0x8b: */{&un_impl, "ADC", "D"},
	/*0x8c: */{&un_impl, "ADC", "H"},
	/*0x8d: */{&un_impl, "ADC", "L"},
	/*0x8e: */{&un_impl, "ADC", "M"},
	/*0x8f: */{&un_impl, "ADC", "A"},
	/*0x90: */{gensub!'b', "SUB", "B"},
	/*0x91: */{gensub!'c', "SUB", "C"},
	/*0x92: */{gensub!'d', "SUB", "D"},
	/*0x93: */{gensub!'e', "SUB", "E"},
	/*0x94: */{gensub!'h', "SUB", "H"},
	/*0x95: */{gensub!'l', "SUB", "L"},
	/*0x96: */{gensub!'m', "SUB", "M"},
	/*0x97: */{gensub!'a', "SUB", "A"},
	/*0x98: */{gensbb!'b', "SBB", "B"},
	/*0x99: */{gensbb!'c', "SBB", "C"},
	/*0x9a: */{gensbb!'d', "SBB", "D"},
	/*0x9b: */{gensbb!'e', "SBB", "E"},
	/*0x9c: */{gensbb!'h', "SBB", "H"},
	/*0x9d: */{gensbb!'l', "SBB", "L"},
	/*0x9e: */{gensbb!'m', "SBB", "M"},
	/*0x9f: */{gensbb!'a', "SBB", "A"},
	/*0xa0: */{&un_impl, "ANA", "B"},
	/*0xa1: */{&un_impl, "ANA", "C"},
	/*0xa2: */{&un_impl, "ANA", "D"},
	/*0xa3: */{&un_impl, "ANA", "E"},
	/*0xa4: */{&un_impl, "ANA", "H"},
	/*0xa5: */{&un_impl, "ANA", "L"},
	/*0xa6: */{&un_impl, "ANA", "M"},
	/*0xa7: */{&un_impl, "ANA", "A"},
	/*0xa8: */{&un_impl, "XRA", "B"},
	/*0xa9: */{&un_impl, "XRA", "C"},
	/*0xaa: */{&un_impl, "XRA", "D"},
	/*0xab: */{&un_impl, "XRA", "E"},
	/*0xac: */{&un_impl, "XRA", "H"},
	/*0xad: */{&un_impl, "XRA", "L"},
	/*0xae: */{&un_impl, "XRA", "M"},
	/*0xaf: */{&un_impl, "XRA", "A"},
	/*0xb0: */{&un_impl, "ORA", "B"},
	/*0xb1: */{&un_impl, "ORA", "C"},
	/*0xb2: */{&un_impl, "ORA", "D"},
	/*0xb3: */{&un_impl, "ORA", "E"},
	/*0xb4: */{&un_impl, "ORA", "H"},
	/*0xb5: */{&un_impl, "ORA", "L"},
	/*0xb6: */{&un_impl, "ORA", "M"},
	/*0xb7: */{&un_impl, "ORA", "A"},
	/*0xb8: */{&un_impl, "CMP", "B"},
	/*0xb9: */{&un_impl, "CMP", "C"},
	/*0xba: */{&un_impl, "CMP", "D"},
	/*0xbb: */{&un_impl, "CMP", "E"},
	/*0xbc: */{&un_impl, "CMP", "H"},
	/*0xbd: */{&un_impl, "CMP", "L"},
	/*0xbe: */{&un_impl, "CMP", "M"},
	/*0xbf: */{&un_impl, "CMP", "A"},
	/*0xc0: */{&un_impl, "RNZ"},
	/*0xc1: */{&un_impl, "POP", "B"},
	/*0xc2: */{&un_impl, "JNZ", "$%1%0", 2},
	/*0xc3: */{&un_impl, "JMP", "$%1%0", 2},
	/*0xc4: */{&un_impl, "CNZ", "$%1%0", 2},
	/*0xc5: */{&un_impl, "PUSH", "B"},
	/*0xc6: */{&ADI, "ADI", "#$%!", 1, cccodes_set:Conditions.all},
	/*0xc7: */{&un_impl, "RST 0"},
	/*0xc8: */{&un_impl, "RZ"},
	/*0xc9: */{&un_impl, "RET"},
	/*0xca: */{&un_impl, "JZ", "$%1%0", 2},
	/*0xcb: */{&nop, "NOP"},
	/*0xcc: */{&un_impl, "CZ", "$%1%0", 2},
	/*0xcd: */{&un_impl, "CALL", "$%1%0", 2},
	/*0xce: */{&ACI, "ACI", "#$%!", 1},
	/*0xcf: */{&un_impl, "RST", "1"},
	/*0xd0: */{&un_impl, "RNC"},
	/*0xd1: */{&un_impl, "POP", "D"},
	/*0xd2: */{&un_impl, "JNC", "$%1%0", 2},
	/*0xd3: */{&un_impl, "OUT", "Special?  %!", 1},
	/*0xd4: */{&un_impl, "CNC", "$%1%0", 2},
	/*0xd5: */{&un_impl, "PUSH", "D"},
	/*0xd6: */{&SUI, "SUI", "#$%!", 1},
	/*0xd7: */{&un_impl, "RST", "2"},
	/*0xd8: */{&un_impl, "RC"},
	/*0xd9: */{&nop, "NOP"},
	/*0xda: */{&un_impl, "JC", "$%1%0", 2},
	/*0xdb: */{&un_impl, "IN", "#$%! (special)", 1},
	/*0xdc: */{&un_impl, "CC", "$%1%0", 2},
	/*0xdd: */{&nop, "NOP"},
	/*0xde: */{&un_impl, "SBI", "#$%!", 1},
	/*0xdf: */{&un_impl, "RST 3"},
	/*0xe0: */{&un_impl, "RPO"},
	/*0xe1: */{&un_impl, "POP H"},
	/*0xe2: */{&un_impl, "JPO", "$%1%0", 2},
	/*0xe3: */{&un_impl, "XTHL"},
	/*0xe4: */{&un_impl, "CPO", "$%1%0", 2},
	/*0xe5: */{&un_impl, "PUSH", "H"},
	/*0xe6: */{&un_impl, "ANI", "#$%!", 1},
	/*0xe7: */{&un_impl, "RST 4"},
	/*0xe8: */{&un_impl, "RPE"},
	/*0xe9: */{&un_impl, "PCHL"},
	/*0xea: */{&un_impl, "JPE", "$%1%0", 2},
	/*0xeb: */{&un_impl, "XCHG"},
	/*0xec: */{&un_impl, "CPE", "$%1%0", 2},
	/*0xed: */{&nop, "NOP"},
	/*0xee: */{&un_impl, "XRI", "#$%!", 1},
	/*0xef: */{&un_impl, "RST", "5"},
	/*0xf0: */{&un_impl, "RP"},
	/*0xf1: */{&un_impl, "POP", "PSW"},
	/*0xf2: */{&un_impl, "JP", "$%1%0", 2},
	/*0xf3: */{&un_impl, "DI"},
	/*0xf4: */{&un_impl, "CP", "$%1%0", 2},
	/*0xf5: */{&un_impl, "PUSH", "PSW"},
	/*0xf6: */{&un_impl, "ORI", "#$%!", 1},
	/*0xf7: */{&un_impl, "RST", "6"},
	/*0xf8: */{&un_impl, "RM"},
	/*0xf9: */{&un_impl, "SPHL"},
	/*0xfa: */{&un_impl, "JM", "$%1%0", 2},
	/*0xfb: */{&un_impl, "EI"},
	/*0xfc: */{&un_impl, "CM", "$%1%0", 2},
	/*0xfd: */{&nop, "NOP"},
	/*0xfe: */{&un_impl, "CPI", "#$%!", 1},
	/*0xff: */{&un_impl, "RST", "7"},
	];
