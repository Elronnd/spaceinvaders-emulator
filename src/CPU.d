static import opcodes;
import debugging;

import std.stdio;
import std.string: format;
import std.array: split;

pure /*private*/ string cformat(in string str, ubyte[] args) {
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
	ubyte a;
	union {
		struct {
			ubyte c;
			ubyte b;
		}
		ushort bc;
	}
	union {
		struct {
			ubyte e;
			ubyte d;
		}
		ushort de;
	}
	union {
		struct {
			ubyte l;
			ubyte h;
		}
		ushort hl;
	}

	// memory space, including the program
	ubyte[] memory;

	// stack pointer and program counter
	ushort sp, pc;
}

// automatic class by reference; that is all
class State {
	Mem mem;
	Condition condition;
	bool interrupt_enabled;
	bool interrupted;
	ubyte[] interrupt;

	this() {
		mem.memory = new ubyte[0x10000];
		mem.sp = 0xF000;
	}
}

void push(State state, ubyte value) {
	state.mem.memory[--state.mem.sp] = value;
}


void set_conditions(State state, ushort ans, Conditions conditions) {
	if (conditions & Conditions.z) {
		state.condition.z = ((ans & 0xff) == 0);
	}
	if (conditions & Conditions.s) {
		state.condition.s = ((ans & 0x80) != 0);
	}
	if (conditions & Conditions.p) {
		state.condition.p = !((ans&0xff) & 1);
	}
	if (conditions & Conditions.cy) {
		state.condition.cy = (ans > 0xff);
	}
//	state.condition.ac = (ans & 0xff) != 0;
}

void debug_instr(State state) {
	string err_reason;
	bool valid_cmd;

	writefln("Execution: %s", disasemble_instr(state.mem, state.mem.pc));
	with (state.mem) writefln("Registers: a: 0x%02x, b: 0x%02x, c: 0x%02x, d: 0x%02x, e: 0x%02x, h: 0x%02x, l: 0x%02x, bc: 0x%04x, de: 0x%04x, hl: 0x%04x, sp: 0x%04x, pc: 0x%04x.", a, b, c, d, e, h, l, bc, de, hl, sp, pc);
	with (state.mem) writefln("Registers: a: %-4s, b: %-4s, c: %-4s, d: %-4s, e: %-4s, h: %-4s, l: %-4s, bc: %-6s, de: %-6s, hl: %-6s, sp: %-6s, pc: %-6s.", a, b, c, d, e, h, l, bc, de, hl, sp, pc); // todo: make this prettier ('a: 5,    b:' instead of 'a: 5   , :' (or possibly it should be 'a:   5,  b:' so that the 5 lines up with the '5' in '0x5' instead of the '0'?))
	with (state.condition) writefln("Flags: %s%s%s%s%s.  %s", z ? "zero, " : "", s ? "sign, " : "", p ? "parity, " : "", cy ? "carry, " : "", ac ? "auxilliary carry" : "", state.interrupt_enabled ? "Interrupts enabled" : "Interrupts not enabled");

	while (true) {
		write("> ");
		string[] args = readln.split;

		if (!args) {
			break;
		}

		string cmd = args[0];
		args = args[1 .. $];

		if (cmd !in dbg_cmds) {
			valid_cmd = false;
			err_reason = format("%s is not a command!", cmd);
			// -1 = any number of arguments
		} else if ((cast(byte)(args.length) !in dbg_cmds[cmd].argnums) && (-1 !in dbg_cmds[cmd].argnums)) {
			valid_cmd = false;
			err_reason = format("passed %s arguments to a function that could only take %s arguments", args.length, dbg_cmds[cmd].argnums);
		} else if (!dbg_cmds[cmd].veriflags(args, err_reason)) {
			valid_cmd = false;
		} else {
			valid_cmd = true;
		}

		if (valid_cmd) {
			dbg_cmds[cmd].cmd(state, args);
		} else {
			writefln("Error: %s.  Press <enter> to skip to the next instruction.", err_reason);
		}
	}
}


/*
ubyte run(State state) {
	//writeln(disasemble_instr(state.mem, state.mem.pc));
	opcodes.Opcode curr;
	ubyte opcode;
	ubyte[] opargs;
	ushort ans;

	opcode = state.mem.memory[state.mem.pc++];
	curr = opcodes.opcodes[opcode];
	opargs = state.mem.memory[state.mem.pc .. state.mem.pc+=curr.size];

	ans = curr.fun(state, opcode, opargs);

	set_conditions(state, ans, curr.cccodes_set);
	return curr.cycles;
}
*/

ubyte interrupt(State state, ubyte[] codes) {
	opcodes.Opcode curr = opcodes.opcodes[codes[0]];
	if ((codes.length - 1) != curr.size) {
		assert(0);
	}

	set_conditions(state, curr.fun(state, codes[0], codes[1 .. $]), curr.cccodes_set);
	return opcodes.opcodes[codes[0]].cycles;
}

private pure string disasemble_instr(Mem mem, ushort pc) {
	opcodes.Opcode op;
	string ret;
	ret ~= format("%04x: ", pc);

	op = opcodes.opcodes[mem.memory[pc]];

	string hex = format("%02x", mem.memory[pc++]);

	foreach (i; 0 .. op.size) {
		hex ~= format(" %02x", mem.memory[pc+i]);
	}
	ret ~= format("%-8s", hex); // max 8 characters (6 hex, plus 2 spaces, plus some padding
	// - left-aligns

	ret ~= "\t\t"; // padding


	ret ~= op.opcode;
	ret ~= '\t';
	ret ~= cformat(op.format_string, mem.memory[pc .. pc+op.size]);

	return ret;
}


void print_dissasembly(Mem mem) {
	// use our own pc, to avoid disrupting mem's
	ushort pc = 0;

	while (pc < mem.memory.length /* 0x1fff */) {
		writeln(disasemble_instr(mem, pc));

		// skip over arguments and instruction
		pc += opcodes.opcodes[mem.memory[pc]].size + 1;
	}
}
