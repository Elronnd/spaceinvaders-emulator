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
//				writefln("It was %d ('%c').  Length is %s.  So we can get s.  Hellno world?", str[index] - '0', str[index], args.length/*, args[str[index] - '0']*/);
//				ubyte cxx = args[str[index] - '0'];
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

struct Condition {
	bool z, s, p, cy, ac;
}
struct Mem {
	// registers
	ubyte a, b, c, d, e, h, l;

	// program data
	ubyte[] program;

	// stack pointer and program counter
	ushort sp, pc;

	ubyte int_enable;
}

// automatic class by reference; that is all
class State {
	Mem mem;
	Condition condition;
}


void run(State state) {
	state.mem.pc = 0;
	opcodes.Opcode curr;
	ubyte opcode;
	ubyte[] opargs;

	while (state.mem.pc < state.mem.program.length) {
		opcode = state.mem.program[state.mem.pc++];
		curr = opcodes.opcodes[opcode];
		opargs = state.mem.program[state.mem.pc .. state.mem.pc+=curr.size];

		curr.fun(state, opcode, opargs);
	}
}





void print_dissasembly(Mem mem) {
	ushort pc; // make our own, to avoid disrupting Mem's
	opcodes.Opcode curr;

	while (pc < mem.program.length) {
		curr = opcodes.opcodes[mem.program[pc]];

		{
			import std.string: format;

			string hex = format("%02x", mem.program[pc++]);

			// write out hex
			foreach (i; 0 .. curr.size) {
				hex ~= format(" %02x", mem.program[pc+i]);
			}
			writef("%-10s", hex); // max 8 characters (6 hex, plus 2 spaces, plus some padding
			// - left-aligns
		}

		write("\t\t"); // padding


		//			pc++; // skip over the opcode


		// write dissassembly
		write(curr.opcode);
		write("\t");
		write(cformat(curr.format_string, mem.program[pc .. pc+curr.size]));
		writeln;

		// skip over arguments
		pc += curr.size;
	}
}
