const std = @import("std");

const glfw = @import("mach-glfw/src/main.zig");
const zgl = @import("zgl/zgl.zig");

const texture = @import("texture.zig");

pub const renderer_file = @import("renderer.zig");
pub const Renderer = renderer_file.Renderer;
pub const RendererType = renderer_file.RendererType;

pub const GLESRenderer = @import("gles_renderer.zig");

const comp_options = @import("TestGLOptions");
pub var active_renderer: Renderer = undefined;

pub var window: glfw.Window = undefined;

var test_tex: texture.Texture2D = undefined;
var test_tex_2: texture.Texture2D = undefined;

pub const Vector2 = packed struct { x: f32, y: f32 };
pub const Color = packed struct { r: f32, g: f32, b: f32, a: f32 = 1.0 };

pub var ready: bool = false;

pub fn onInit() anyerror!void {
    const selected_renderer: RendererType = @intToEnum(RendererType, comp_options.RENDER_BACKEND);

    std.log.info("Selected renderer {any}!", .{selected_renderer});
    switch(selected_renderer) {
        RendererType.GLES => {
            active_renderer = GLESRenderer.GLESRenderer.Create().interface;
        }
    }

    window.setFramebufferSizeCallback(onResize);

    //Clear the color
    zgl.clear(.{ .color = true });
    zgl.clearColor(0, 0, 0, 0);

    try active_renderer.initialize();

    test_tex = try texture.loadQoi("test.qoi");
    test_tex_2 = try texture.loadQoi("test2.qoi");

    // try glfw.swapInterval(1);
}

pub fn onClose() anyerror!void {
    try active_renderer.deinitialize();
}

pub fn onUpdate(time: f64) anyerror!void {
    _ = time;
}

var passed_time: f64 = 0;
pub fn onDraw(time: f64) anyerror!void {
    zgl.clear(.{ .color = true });
    zgl.clearColor(1, 1, 1, 0);

    try active_renderer.begin();

    var i: f32 = 0;
    while (i < 512) : (i += 4) {
        try active_renderer.drawTexture(.{ .x = i, .y = 512 - i }, .{ .x = @intToFloat(f32, test_tex.width) / 10, .y = @intToFloat(f32, test_tex.height) / 10 }, .{ .r = 1, .g = 1, .b = 1, .a = 1 }, test_tex, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 1 }, 0);
    }
    i = 0;
    while (i < 512) : (i += 4) {
        try active_renderer.drawTexture(.{ .x = i, .y = i }, .{ .x = @intToFloat(f32, test_tex.width) / 10, .y = @intToFloat(f32, test_tex.height) / 10 }, .{ .r = 1, .g = 1, .b = 1, .a = 1 }, test_tex_2, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 1 }, 0);
    }

    // try renderer.drawTexture(0, 0, @intToFloat(f32, test_tex.width), @intToFloat(f32, test_tex.height), test_tex, 0);
    // try renderer.drawTexture(.{.x = 0, .y = 0}, .{.x = @intToFloat(f32, test_tex.width) / 10, .y = @intToFloat(f32, test_tex.height) / 10}, .{.r = 1, .g = 1, .b = 1, .a = 1}, test_tex, .{.x = 0, .y = 0}, .{.x = 1, .y = 1}, 0);
    // try renderer.drawTexture(.{.x = 100, .y = 100}, .{.x = @intToFloat(f32, test_tex.width) / 10, .y = @intToFloat(f32, test_tex.height) / 10}, .{.r = 1, .g = 1, .b = 1, .a = 1}, test_tex, .{.x = 0, .y = 0}, .{.x = 1, .y = 1}, 0);

    try active_renderer.end();

    // _ = time;

    passed_time += time;
    if (passed_time > 1) {
        std.log.info(comptime "{d} fps with {d} objects", .{ 1 / time, active_renderer.last_render_count });
        passed_time = 0;
    }
}

pub fn onResize(event_window: glfw.Window, width: u32, height: u32) void {
    _ = event_window;
    zgl.viewport(0, 0, width, height);
    if (ready)
        active_renderer.updateProjectionMatrix() catch {
            std.log.err("Unable to update projection matrix!", .{});
            return;
        };

    std.log.info("Resizing viewport to {d}x{d}", .{ width, height });
}
