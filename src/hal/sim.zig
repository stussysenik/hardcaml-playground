//! sim.zig — Mac/SDL2 simulator platform backend.
//!
//! Implements the platform HAL contract using SDL2 for display, mouse for
//! IMU simulation, and keyboard for button input. This lets us develop and
//! test the entire rendering pipeline without physical hardware.
//!
//! ## Window Setup
//! The M5StickC screen is 80×160 — tiny on a desktop monitor. We scale 4×
//! to 320×640 using SDL's texture scaling. The framebuffer stays at native
//! resolution; SDL handles the upscale when we copy the texture to screen.
//!
//! ## Dependencies
//! - SDL2 library (brew install sdl2)
//! - Linked via build.zig system library declaration

const std = @import("std");
const config = @import("../config.zig");
const Framebuffer = @import("../gfx/framebuffer.zig").Framebuffer;
const platform = @import("../platform.zig");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

/// SDL2 simulator platform state.
pub const SimPlatform = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    fb: Framebuffer,
    quit: bool,
    start_ticks: u32,

    // IMU simulation state
    mouse_dx: i32,
    mouse_dy: i32,

    // Button state with edge detection
    btn_a_current: bool,
    btn_b_current: bool,
    btn_c_current: bool,
    btn_v_current: bool,
    btn_space_current: bool,
    btn_p_current: bool,
    btn_g_current: bool,
    btn_s_current: bool,
    btn_d_current: bool,
    btn_a_prev: bool,
    btn_b_prev: bool,
    btn_c_prev: bool,
    btn_v_prev: bool,
    btn_space_prev: bool,
    btn_p_prev: bool,
    btn_g_prev: bool,
    btn_s_prev: bool,
    btn_d_prev: bool,

    // Scroll wheel accumulator for zoom
    scroll_y: i32,

    /// Initialize SDL2, create window and texture at native resolution.
    pub fn init() SimPlatform {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            @panic("SDL_Init failed");
        }

        const win_w: c_int = @as(c_int, config.SCREEN_W) * config.SIM_SCALE;
        const win_h: c_int = @as(c_int, config.SCREEN_H) * config.SIM_SCALE;

        const window = c.SDL_CreateWindow(
            "M5StickC 3D Wireframe Simulator",
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            win_w,
            win_h,
            0,
        ) orelse @panic("SDL_CreateWindow failed");

        const renderer = c.SDL_CreateRenderer(
            window,
            -1,
            c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
        ) orelse @panic("SDL_CreateRenderer failed");

        // Nearest-neighbor scaling for crisp pixel art look
        _ = c.SDL_SetHint(c.SDL_HINT_RENDER_SCALE_QUALITY, "0");

        const texture = c.SDL_CreateTexture(
            renderer,
            c.SDL_PIXELFORMAT_RGB565,
            c.SDL_TEXTUREACCESS_STREAMING,
            config.SCREEN_W,
            config.SCREEN_H,
        ) orelse @panic("SDL_CreateTexture failed");

        return SimPlatform{
            .window = window,
            .renderer = renderer,
            .texture = texture,
            .fb = Framebuffer.init(),
            .quit = false,
            .start_ticks = c.SDL_GetTicks(),
            .mouse_dx = 0,
            .mouse_dy = 0,
            .btn_a_current = false,
            .btn_b_current = false,
            .btn_c_current = false,
            .btn_v_current = false,
            .btn_space_current = false,
            .btn_p_current = false,
            .btn_g_current = false,
            .btn_s_current = false,
            .btn_d_current = false,
            .btn_a_prev = false,
            .btn_b_prev = false,
            .btn_c_prev = false,
            .btn_v_prev = false,
            .btn_space_prev = false,
            .btn_p_prev = false,
            .btn_g_prev = false,
            .btn_s_prev = false,
            .btn_d_prev = false,
            .scroll_y = 0,
        };
    }

    /// Clean up SDL2 resources.
    pub fn deinit(self: *SimPlatform) void {
        c.SDL_DestroyTexture(self.texture);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    /// Get mutable reference to the framebuffer for drawing.
    pub fn getFramebuffer(self: *SimPlatform) *Framebuffer {
        return &self.fb;
    }

    /// Upload the front buffer to SDL texture and present to screen.
    ///
    /// This is the simulator equivalent of SPI DMA transfer on ESP32.
    /// SDL_UpdateTexture copies our RGB565 data into GPU memory, then
    /// SDL_RenderCopy scales it up 4× and displays it.
    pub fn flushDisplay(self: *SimPlatform) void {
        const front = self.fb.swap();
        _ = c.SDL_UpdateTexture(
            self.texture,
            null,
            @ptrCast(front),
            @as(c_int, config.SCREEN_W) * 2, // pitch = width × bytes_per_pixel
        );
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
        c.SDL_RenderPresent(self.renderer);
    }

    /// Read simulated IMU data from mouse movement.
    ///
    /// Mouse delta X → yaw (Z-axis rotation)
    /// Mouse delta Y → pitch (X-axis rotation)
    /// Values are scaled to feel natural in the simulator.
    pub fn readImu(self: *SimPlatform) platform.ImuData {
        const sensitivity = 50; // Tuned for comfortable mouse control
        const result = platform.ImuData{
            .gyro_x = self.mouse_dy * sensitivity,
            .gyro_y = 0,
            .gyro_z = self.mouse_dx * sensitivity,
        };
        // Reset deltas after reading (consumed)
        self.mouse_dx = 0;
        self.mouse_dy = 0;
        return result;
    }

    /// Read button state with edge detection.
    ///
    /// `a_pressed`/`b_pressed` are true only on the frame the button
    /// transitions from released to pressed — useful for toggles.
    pub fn getButtons(self: *SimPlatform) platform.ButtonState {
        const result = platform.ButtonState{
            .a = self.btn_a_current,
            .b = self.btn_b_current,
            .c = self.btn_c_current,
            .v = self.btn_v_current,
            .space = self.btn_space_current,
            .p = self.btn_p_current,
            .g = self.btn_g_current,
            .s = self.btn_s_current,
            .d = self.btn_d_current,
            .a_pressed = self.btn_a_current and !self.btn_a_prev,
            .b_pressed = self.btn_b_current and !self.btn_b_prev,
            .c_pressed = self.btn_c_current and !self.btn_c_prev,
            .v_pressed = self.btn_v_current and !self.btn_v_prev,
            .space_pressed = self.btn_space_current and !self.btn_space_prev,
            .p_pressed = self.btn_p_current and !self.btn_p_prev,
            .g_pressed = self.btn_g_current and !self.btn_g_prev,
            .s_pressed = self.btn_s_current and !self.btn_s_prev,
            .d_pressed = self.btn_d_current and !self.btn_d_prev,
            .scroll_y = self.scroll_y,
        };
        self.btn_a_prev = self.btn_a_current;
        self.btn_b_prev = self.btn_b_current;
        self.btn_c_prev = self.btn_c_current;
        self.btn_v_prev = self.btn_v_current;
        self.btn_space_prev = self.btn_space_current;
        self.btn_p_prev = self.btn_p_current;
        self.btn_g_prev = self.btn_g_current;
        self.btn_s_prev = self.btn_s_current;
        self.btn_d_prev = self.btn_d_current;
        self.scroll_y = 0;
        return result;
    }

    /// Process SDL events: window close, keyboard, mouse motion.
    ///
    /// Must be called once per frame before readImu() or getButtons().
    /// SDL requires event polling on the main thread.
    pub fn pollInput(self: *SimPlatform) void {
        var event: c.SDL_Event = undefined;
        // Reset mouse deltas for this frame
        self.mouse_dx = 0;
        self.mouse_dy = 0;

        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => self.quit = true,
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_z => self.btn_a_current = true,
                        c.SDLK_x => self.btn_b_current = true,
                        c.SDLK_c => self.btn_c_current = true,
                        c.SDLK_v => self.btn_v_current = true,
                        c.SDLK_SPACE => self.btn_space_current = true,
                        c.SDLK_p => self.btn_p_current = true,
                        c.SDLK_g => self.btn_g_current = true,
                        c.SDLK_s => self.btn_s_current = true,
                        c.SDLK_d => self.btn_d_current = true,
                        c.SDLK_UP => self.scroll_y += 1,
                        c.SDLK_DOWN => self.scroll_y -= 1,
                        c.SDLK_ESCAPE => self.quit = true,
                        else => {},
                    }
                },
                c.SDL_KEYUP => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_z => self.btn_a_current = false,
                        c.SDLK_x => self.btn_b_current = false,
                        c.SDLK_c => self.btn_c_current = false,
                        c.SDLK_v => self.btn_v_current = false,
                        c.SDLK_SPACE => self.btn_space_current = false,
                        c.SDLK_p => self.btn_p_current = false,
                        c.SDLK_g => self.btn_g_current = false,
                        c.SDLK_s => self.btn_s_current = false,
                        c.SDLK_d => self.btn_d_current = false,
                        else => {},
                    }
                },
                c.SDL_MOUSEWHEEL => {
                    self.scroll_y += event.wheel.y;
                },
                c.SDL_MOUSEMOTION => {
                    self.mouse_dx += event.motion.xrel;
                    self.mouse_dy += event.motion.yrel;
                },
                else => {},
            }
        }
    }

    /// Milliseconds since platform init.
    pub fn millis(self: *SimPlatform) u32 {
        return c.SDL_GetTicks() - self.start_ticks;
    }

    /// True when the user requested quit (window close or Escape key).
    pub fn shouldQuit(self: *SimPlatform) bool {
        return self.quit;
    }

    /// Sleep for the given number of milliseconds (frame rate limiting).
    pub fn delay(_: *SimPlatform, ms: u32) void {
        c.SDL_Delay(ms);
    }
};
