import CPU;
import std.container.rbtree: set = redBlackTree, Set = RedBlackTree;


struct Dbgcmd {
	void function(State state, string[] args) cmd;
	bool function(string[] args, string err_msg) veriflags;
	Set!int argnums;
}

Dbgcmd[string] dbg_cmds;

shared static this() {
	dbg_cmds = [
	"m": Dbgcmd(
			(State state, string[] args) {
				import std.stdio: writefln;
				import std.conv: parse;
				string x = args[0][2 .. $];
				writefln("%02x", state.mem.memory[x.parse!int(16)]);
			},
			(string[] args, string err_msg) {
				if (args[0][0 .. 2] != "0x") {
					err_msg = "not hexadecimal";
					return false;
				}
				foreach (char c; args[0][2 .. $]) {
					if (!((('0' <= c) && (c <= '9')) ||
						(('a' <= c) && (c <= 'f')) ||
						(('A' <= c) && (c <= 'F')))) {
					err_msg = "malformed hexadecimal";
						return false;
					}
				}
				return true;
			},
			set(1)),
	];
}
