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
	// the 'nothing' command
	"": Dbgcmd((State state, string[] args) {}, (string[] args, string err_msg) => true, set(-1)),
	"m": Dbgcmd(
			(State state, string[] args) {
				import std.stdio: writefln;
				writefln("%02x", state.mem.memory[(string x) {
						ushort ret;
						while (x.length > 0) {
							ret *= 16;
							ret += x[0] - '0';
							x = x[1 .. $];
						}
						return ret;
					}(args[0][2 .. $])]);
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
