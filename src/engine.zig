const std = @import("std");

const glfw = @import("mach-glfw/src/main.zig");
const zgl = @import("zgl/zgl.zig");

pub var window: glfw.Window = undefined;

const vertexShaderSource = [_][]const u8 {
    \\#version 300 es            
    
    \\in vec4 VertexPosition, VertexColor;
    \\out vec4     TriangleColor;    
    
    \\void main() {
    \\	gl_Position = VertexPosition;
    \\	TriangleColor = VertexColor;
    \\}
};

const fragmentShaderSource = [_][]const u8 {
    \\#version 300 es        
    \\precision mediump float;
    
    \\in  vec4 TriangleColor;
    \\out vec4 FragColor;  
      
    \\void main() {          
    \\	FragColor = TriangleColor;
    \\};
};

var vertexShader: zgl.Shader = undefined;
var fragmentShader: zgl.Shader = undefined;

var program: zgl.Program = undefined;

pub fn onInit() anyerror!void {
    //Clear the color
    zgl.clear(.{ .color = true });
    zgl.clearColor(0, 0, 0, 0);

    vertexShader = zgl.createShader(zgl.ShaderType.vertex);
    zgl.shaderSource(vertexShader, 1, &vertexShaderSource);
    zgl.compileShader(vertexShader);

    fragmentShader = zgl.createShader(zgl.ShaderType.fragment);
    zgl.shaderSource(fragmentShader, 1, &fragmentShaderSource);
    zgl.compileShader(fragmentShader);

    program = zgl.createProgram();
    zgl.attachShader(program, vertexShader);
    zgl.attachShader(program, fragmentShader);
    zgl.linkProgram(program);

    // try glfw.swapInterval(1);
}

pub fn onClose() anyerror!void {
    zgl.deleteProgram(program);
    zgl.deleteShader(vertexShader);
    zgl.deleteShader(fragmentShader);
}

pub fn onUpdate(time: f64) anyerror!void {
    _ = time;
}

pub fn onDraw(time: f64) anyerror!void {
    zgl.clear(.{ .color = true });
    zgl.clearColor(1, 1, 1, 0);

    _ = time;

    std.log.info(comptime "{d} fps", .{ 1 / time });
}
