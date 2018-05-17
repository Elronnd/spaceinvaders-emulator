import CPU;
import SDL;
import std.stdio;

enum width = 224;
enum height = 256;
enum start = 0x2400;
enum end = 0x3fff;

/*
 * Start at (223, 0)
 * Reduce y, reduce y, reduce y
 * (1, 0)
 * (0, 0)
 * y = 0: y = 223, x++
 */

void draw_screen(ubyte[] mem) {
	uint x, y = height - 1;

	foreach (i; start .. end+1) {
		foreach (bit; 0 .. 8) {
			if (mem[i] & (1 << bit)) {
				SDL2.drawpx(0xffffff, y, x);
			} else {
				SDL2.drawpx(0x0, y, x);
			}
			if (x == width) {
				assert(0);
			}
			if (y == 0) {
				y = height - 1;
				x++;
			} else {
				y--;
			}
		}
	}
}
