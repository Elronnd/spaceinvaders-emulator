static import opcodes;
import std.stdio;

string cformat(in string str, ubyte[] args) {
	import std.string: format;

	size_t argindex;
	string ret;

	for (size_t index = 0; index < str.length; index++) {
		if (str[index] == '%') {
			index++;

			// escaped %
			if (str[index] == '%') {
				ret ~= '%';
				index++;
			// proper format string
			} else if (str[index] == '!') {
				ret ~= format("%02x", args[argindex++]);
			// indexed format string
			} else if (('0' <= str[index]) && (str[index] <= '9')) {
				ret ~= format("%02x", args[str[index] - '0']);
			// Bare %, but we'll allow it
			} else {
				ret ~= '%';
			}
		} else {
			ret ~= str[index];
		}
	}

	return ret;
}

enum Conditions {
	none = 0x0,
	z = 0x1,
	s = 0x2,
	p = 0x4,
	cy = 0x8,
	ac = 0xf,

	all = z | s | p | cy | ac
}
struct Condition {
	bool z, s, p, cy, ac;
}
struct Mem {
	// registers
	ubyte a, b, c, d, e, h, l;

	// memory space, including the program
	ubyte[] memory;

	// stack pointer and program counter
	ushort sp, pc;

	// enable interrupts
	ubyte int_enable;
}

// automatic class by reference; that is all
class State {
	Mem mem;
	Condition condition;
}


void set_conditions(State state, ushort ans, Conditions conditions) {
	if (conditions & Conditions.z) {
		state.condition.z = ((ans & 0xff) == 0);
	}
	if (conditions & Conditions.s) {
		state.condition.s = ((ans & 0x80) != 0);
	}
	if (conditions & Conditions.p) {
		state.condition.p = !((ans&0xff) & 0x1);
	}
	if (conditions & Conditions.cy) {
		state.condition.cy = (ans > 0xff);
	}
//	state.condition.ac = (ans & 0xff) != 0;
}


void run(State state) {
	state.mem.pc = 0;
	opcodes.Opcode curr;
	ubyte opcode;
	ubyte[] opargs;
	short ans;

	while (state.mem.pc < state.mem.memory.length /* 0x1fff */ /* || true */) {
		opcode = state.mem.memory[state.mem.pc++];
		curr = opcodes.opcodes[opcode];
		opargs = state.mem.memory[state.mem.pc .. state.mem.pc+=curr.size];

		ans = curr.fun(state, opcode, opargs);

		set_conditions(state, ans, curr.cccodes_set);
		//state.mem.a = ans & 0xff;
	}
}




void print_dissasembly(Mem mem) {
	ushort pc; // make our own, to avoid disrupting Mem's
	opcodes.Opcode curr;

	while (pc < mem.memory.length /* 0x1fff */) {
		writef("%04x: ", pc);

		curr = opcodes.opcodes[mem.memory[pc]];

		{
			import std.string: format;

			string hex = format("%02x", mem.memory[pc++]);

			// write out hex
			foreach (i; 0 .. curr.size) {
				hex ~= format(" %02x", mem.memory[pc+i]);
			}
			writef("%-8s", hex); // max 8 characters (6 hex, plus 2 spaces, plus some padding
			// - left-aligns
		}

		write("\t\t"); // padding


		// write dissassembly
		write(curr.opcode);
		write("\t");
		write(cformat(curr.format_string, mem.memory[pc .. pc+curr.size]));
		writeln;

		// skip over arguments
		pc += curr.size;
	}
}
