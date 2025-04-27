const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const WINDOW_W = 1200;
const WINDOW_H = 1000;
const CELL_SIZE = 20;
const FPS = 144;

const SortType = enum { Bubble, None };
const SortState = struct {
    type: SortType = .None,
    i: usize = 0,
    j: usize = 0,
};

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        try print_sdl_error();
        return;
    }
    defer c.SDL_Quit();

    var window: ?*c.SDL_Window = undefined;
    var renderer: ?*c.SDL_Renderer = undefined;
    if (!c.SDL_CreateWindowAndRenderer("zsrt", WINDOW_W, WINDOW_H, 0, &window, &renderer)) {
        try print_sdl_error();
        return;
    }

    var x256 = std.Random.Xoshiro256.init(std.crypto.random.int(u64));
    const random = x256.random();

    var ns: [WINDOW_W / CELL_SIZE]u16 = undefined;
    for (0..ns.len) |i| {
        const h = 1 + (i * (WINDOW_H - 2) / (ns.len - 1));
        ns[i] = @intCast(h);
    }
    random.shuffle(u16, &ns);

    var quit = false;
    var state = SortState{};
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) quit = true;

            if (event.type == c.SDL_EVENT_KEY_DOWN) {
                if (event.key.scancode == c.SDL_SCANCODE_R) {
                    random.shuffle(u16, &ns);
                    state = SortState{};
                    break;
                }

                if (state.type == .None) {
                    switch (event.key.scancode) {
                        c.SDL_SCANCODE_B => state.type = .Bubble,
                        else => {},
                    }
                }
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

        for (ns, 0..) |n, i| {
            const max_scaled_height = 0.9 * @as(f32, @floatFromInt(WINDOW_H));
            const scale_factor = max_scaled_height / @as(f32, @floatFromInt(WINDOW_H - 1));
            const scaled_height = @as(f32, @floatFromInt(n)) * scale_factor;

            const rect = c.SDL_FRect{
                .x = @floatFromInt(i * CELL_SIZE),
                .y = @as(f32, @floatFromInt(WINDOW_H)) - scaled_height,
                .w = @floatFromInt(CELL_SIZE),
                .h = scaled_height,
            };
            if (!c.SDL_RenderFillRect(renderer, &rect)) {
                try print_sdl_error();
            }
        }

        if (!c.SDL_RenderPresent(renderer)) {
            try print_sdl_error();
        }
        if (state.type != .None) {
            sort_step(&ns, &state);
        }

        c.SDL_Delay(1000 / FPS);
    }
}

fn sort_step(ns: []u16, st: *SortState) void {
    switch (st.type) {
        .Bubble => {
            if (st.i < ns.len - st.j - 1) {
                if (ns[st.i] > ns[st.i + 1]) {
                    const tmp = ns[st.i];
                    ns[st.i] = ns[st.i + 1];
                    ns[st.i + 1] = tmp;
                }
                st.i += 1;
            } else {
                st.i = 0;
                st.j += 1;
                if (st.j >= ns.len - 1) st.type = .None;
            }
        },
        .None => unreachable,
    }
}

fn print_sdl_error() !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("SDL error: {s}", .{c.SDL_GetError()});
}
