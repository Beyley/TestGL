const std = @import("std");

const glfw = @import("mach-glfw/src/main.zig");
const zgl = @import("zgl/zgl.zig");

const engine = @import("engine.zig");

pub fn main() anyerror!void {
    try glfw.init(.{});
    defer glfw.terminate();

    // Create our window
    engine.window = try glfw.Window.create(640, 480, "Test window!", null, null, .{ .context_version_major = 3, .context_version_minor = 0, .client_api = glfw.Window.Hints.ClientAPI.opengl_es_api });
    defer engine.window.destroy();

    //This makes the context current
    try glfw.makeContextCurrent(engine.window);

    try engine.onInit();

    var last_time: f64 = 0;
    var time: f64 = glfw.getTime();
    var time_diff: f64 = 0;

    // Wait for the user to close the window.
    while (!engine.window.shouldClose()) {
        try glfw.pollEvents();

        time = glfw.getTime();
        time_diff = time - last_time;

        engine.onUpdate(time_diff) catch |err| {
            std.log.err("Got error {any} in update!", .{err});
            //this destroy causes a segfault >:(
            engine.window.destroy();
            break;
        };

        engine.onDraw(time_diff) catch |err| {
            std.log.err("Got error {any} in draw!", .{err});
            //this destroy causes a segfault >:(
            engine.window.destroy();
            break;
        };

        try engine.window.swapBuffers();

        last_time = time;
    }

    try engine.onClose();
}
