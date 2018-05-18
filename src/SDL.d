import derelict.sdl2.sdl;
import std.string: toStringz, fromStringz;

enum width = 224, height = 256;

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
		SDL_DisplayMode mode;
		mode.refresh_rate = 60;
		if (SDL_SetWindowDisplayMode(window, &mode) < 0) {
			return false;
		}

		renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
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
		pixels[(y * width) + x] = clr | 0xff_000000; // set alpha to 0
	}
	void clearpx() {
		pixels[] = 0;
	}
	void refresh() {
		SDL_UpdateTexture(framebuffer, null, pixels.ptr, width * uint.sizeof);
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

	SDL_Event *poll_event() {
		SDL_Event *ret = new SDL_Event;
		if (SDL_PollEvent(ret)) {
			if ((ret.type == SDL_KEYDOWN) && (ret.key.repeat)) {
				return null;
			}
			return ret;
		} else {
			return null;
		}
	}
}}
