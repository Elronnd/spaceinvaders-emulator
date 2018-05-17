import derelict.sdl2.sdl;
import std.string: toStringz, fromStringz;

enum width = 256, height = 224;

struct SDL2 { static {
private:
	SDL_Window *window;
	SDL_Renderer *renderer;
	SDL_Texture *framebuffer;
	uint[width * height] pixels;
public:

	bool init(string title) {
		DerelictSDL2.load();
		if (SDL_Init(SDL_INIT_VIDEO|SDL_INIT_EVENTS) == -1) {
			return false;
		}

		window = SDL_CreateWindow(toStringz(title), SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_SHOWN);
		if (!window) {
			return false;
		}

		renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
		if (!renderer) {
			return false;
		}

		framebuffer = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, width, height);
		if (!framebuffer) {
			return false;
		}

		return true;
	}
	string err_msg() {
		return cast(string)fromStringz(SDL_GetError());
	}
	void drawpx(uint clr, uint y, uint x) {
		pixels[(y * height) + x] = clr | 0xff_000000; // set alpha to 0
	}
	void clearpx() {
		pixels[] = 0;
	}
	void refresh() {
		SDL_UpdateTexture(framebuffer, null, pixels.ptr, height * uint.sizeof);
		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, framebuffer, null, null);
		SDL_RenderPresent(renderer);
	}
	void close() {
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
		SDL_QuitSubSystem(SDL_INIT_VIDEO|SDL_INIT_EVENTS);
		SDL_Quit();
	}
}}
