const engine = @import("engine.zig");

const texture = @import("texture.zig");

const Vector2 = engine.Vector2;
const Color = engine.Color;

const Texture2D = texture.Texture2D;

// zig fmt: off
pub const RendererType = enum(u8){
    GLES = 0
};


pub const Renderer = struct {
    initializeFn: fn (*Renderer) anyerror!void,
    deinitializeFn: fn (*Renderer) anyerror!void,
    beginFn: fn (*Renderer) anyerror!void,
    endFn: fn (*Renderer) anyerror!void,
    drawTextureFn: fn (*Renderer, Vector2, Vector2, Color, Texture2D, Vector2, Vector2, f32) anyerror!void,
    updateProjectionMatrixFn: fn (*Renderer) anyerror!void,
    
    initialized: bool = false,
    started: bool = false,
    last_render_count: u64 = 0,

    pub fn initialize(iface: *Renderer) anyerror!void {
        return iface.initializeFn(iface);
    }
    pub fn deinitialize(iface: *Renderer) anyerror!void {
        return iface.deinitializeFn(iface);
    }
    pub fn begin(iface: *Renderer) anyerror!void {
        return iface.beginFn(iface);
    }
    pub fn end(iface: *Renderer) anyerror!void {
        return iface.endFn(iface);
    }
    pub fn drawTexture(iface: *Renderer, pos: Vector2, size: Vector2, color: Color, tex: Texture2D, tex_pos: Vector2, tex_size: Vector2, rot: f32) anyerror!void {
        return iface.drawTextureFn(iface, pos, size, color, tex, tex_pos, tex_size, rot);
    }
    pub fn updateProjectionMatrix(iface: *Renderer) anyerror!void {
        return iface.updateProjectionMatrixFn(iface);
    }
};
// zig fmt: on