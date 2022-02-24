const std = @import("std");
const zgl = @import("zgl/zgl.zig");
const zmath = @import("zig-gamedev/libs/zmath/zmath.zig");

const engine = @import("engine.zig");
const texture = @import("texture.zig");
const renderer = @import("renderer.zig");

const main = @import("main.zig");

const vertexShaderSource = [_][]const u8{
    \\#version 300 es            
    \\
    \\layout (location = 0) in vec2 VertexPosition;
    \\layout (location = 1) in vec2 VertexTextureCoordinate;
    \\
    \\//Instance data
    \\layout (location = 2) in vec2  InstancePos;
    \\layout (location = 3) in vec2  InstanceSize;
    \\layout (location = 4) in vec4  InstanceColor;
    \\layout (location = 5) in vec2  InstanceTexturePosition;
    \\layout (location = 6) in vec2  InstanceTextureSize;
    \\layout (location = 7) in float InstanceRotation;
    \\layout (location = 8) in int   InstanceTextureId;
    \\
    \\uniform mat4 ProjectionMatrix;
    \\
    \\     out vec4 fs_in_col;    
    \\     out vec2 fs_in_tex;
    \\flat out int  fs_in_texid;
    \\
    \\void main() {
    \\  mat2 rotation_matrix = mat2(cos(InstanceRotation),sin(InstanceRotation),
    \\                         -sin(InstanceRotation),cos(InstanceRotation));
    \\
    \\  vec2 _VertexPosition = (vec2(mat4(rotation_matrix) * vec4(VertexPosition, 0, 0)) * InstanceSize) + InstancePos;
    \\
    \\	gl_Position = ProjectionMatrix * vec4(_VertexPosition, 0, 1);
    \\  gl_Position -= vec4(1, 1, 0, 0);
    \\
    \\  fs_in_col = InstanceColor;
    \\  fs_in_tex = (VertexTextureCoordinate * InstanceTextureSize) + InstanceTexturePosition;
    \\  fs_in_texid = InstanceTextureId;
    \\}
};

const fragmentShaderSource = [_][]const u8{
    \\#version 300 es        
    \\precision mediump float;
    \\
    \\     in vec4 fs_in_col;
    \\     in vec2 fs_in_tex;
    \\flat in int  fs_in_texid;
    \\
    \\out vec4 FragColor;  
    \\
    \\uniform sampler2D tex_0;
    \\uniform sampler2D tex_1;
    \\uniform sampler2D tex_2;
    \\uniform sampler2D tex_3;
    \\
    \\void main() {          
    \\  sampler2D tex;
    \\  tex = tex_0;
    \\
    \\  if(fs_in_texid == 0)
    \\    tex = tex_0;
    \\  else if(fs_in_texid == 1)
    \\    tex = tex_1;
    \\  else if(fs_in_texid == 2)
    \\    tex = tex_2;
    \\  else if(fs_in_texid == 3)
    \\    tex = tex_3;
    \\
    \\	FragColor = texture(tex, fs_in_tex) * fs_in_col;
    \\};
};

const Vector2 = engine.Vector2;
const Color = engine.Color;

const Texture2D = texture.Texture2D;

const Renderer = renderer.Renderer;

const Vertex = packed struct { pos: Vector2, tex_pos: Vector2 };
// zig fmt: off
const Instance = packed struct { 
    pos: Vector2, 
    size: Vector2, 
    color: Color, 
    tex_pos: Vector2, 
    tex_size: Vector2, 
    rotation: f32, 
    tex_id: i32 
};
// zig fmt: on

//baseline
// const vertices: [4]Vertex align(1) = [_]Vertex{
//     //Bottom left
//     .{ .pos = .{ .x = 0, .y = 0 }, .tex_pos = .{ .x = 0, .y = 1 } },
//     //Bottom right
//     .{ .pos = .{ .x = 1, .y = 0 }, .tex_pos = .{ .x = 1, .y = 1 } },
//     //Top right
//     .{ .pos = .{ .x = 1, .y = 1 }, .tex_pos = .{ .x = 1, .y = 0 } },
//     //Top left
//     .{ .pos = .{ .x = 0, .y = 1 }, .tex_pos = .{ .x = 0, .y = 0 } },
// };
const vertices: [6]Vertex align(1) = [_]Vertex{
    .{ .pos = .{ .x = 0, .y = 0 }, .tex_pos = .{ .x = 0, .y = 1 } },
    .{ .pos = .{ .x = 1, .y = 0 }, .tex_pos = .{ .x = 1, .y = 1 } },
    .{ .pos = .{ .x = 1, .y = 1 }, .tex_pos = .{ .x = 1, .y = 0 } },
    .{ .pos = .{ .x = 1, .y = 1 }, .tex_pos = .{ .x = 1, .y = 0 } },
    .{ .pos = .{ .x = 0, .y = 1 }, .tex_pos = .{ .x = 0, .y = 0 } },
    .{ .pos = .{ .x = 0, .y = 0 }, .tex_pos = .{ .x = 0, .y = 1 } },
};

const indicies = [_]u16{
    //Tri 1
    0, 1, 2,
    //Tri 2
    2, 3, 0,
};

pub const GLESRenderer = struct { 
    vertexShader: zgl.Shader = undefined,
    fragmentShader: zgl.Shader = undefined,

    vao: zgl.VertexArray = undefined,
    vbo: zgl.Buffer = undefined,
    instance_vbo: zgl.Buffer = undefined,

    program: zgl.Program = undefined,

    used_textures: usize = 0,
    instances: usize = 0,

    instance_data: []align(1) Instance = undefined,
    texture_array: []Texture2D = undefined,

    interface: Renderer,

    pub fn Create() GLESRenderer {
        return .{
            .interface = Renderer{
                .initializeFn = initialize,
                .deinitializeFn = deinitialize,
                .beginFn = begin,
                .endFn = end,
                .drawTextureFn = drawTexture,
                .updateProjectionMatrixFn = updateProjectionMatrix,
            }
        };
    }

    fn initialize(iface: *Renderer) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);

        self.vertexShader = zgl.createShader(zgl.ShaderType.vertex);
        zgl.shaderSource(self.vertexShader, 1, &vertexShaderSource);
        zgl.compileShader(self.vertexShader);

        //Get the vertex shader compile log
        var shaderCompileLog = try zgl.getShaderInfoLog(self.vertexShader, main.allocator);
        if (shaderCompileLog.len > 0)
            std.log.err("Vertex shader compile log: {s}", .{shaderCompileLog});
        main.allocator.free(shaderCompileLog);

        self.fragmentShader = zgl.createShader(zgl.ShaderType.fragment);
        zgl.shaderSource(self.fragmentShader, 1, &fragmentShaderSource);
        zgl.compileShader(self.fragmentShader);

        //Get the fragment shader compile log
        shaderCompileLog = try zgl.getShaderInfoLog(self.fragmentShader, main.allocator);
        if (shaderCompileLog.len > 0)
            std.log.err("Fragment shader compile log: {s}", .{shaderCompileLog});
        main.allocator.free(shaderCompileLog);

        self.program = zgl.createProgram();
        zgl.attachShader(self.program, self.vertexShader);
        zgl.attachShader(self.program, self.fragmentShader);
        zgl.linkProgram(self.program);

        self.vao = zgl.genVertexArray();

        self.vbo = zgl.genBuffer();
        self.instance_vbo = zgl.genBuffer();

        //Bind the VAO
        zgl.bindVertexArray(self.vao);
        //Bind the VBO
        zgl.bindBuffer(self.vbo, zgl.BufferTarget.array_buffer);

        //Load the data into the buffer
        zgl.bufferData(zgl.BufferTarget.array_buffer, Vertex, &vertices, zgl.BufferUsage.static_draw);

        //Use our program
        zgl.useProgram(self.program);

        //Set the vertex attributes
        zgl.vertexAttribPointer(0, 2, zgl.Type.float, false, @sizeOf(Vertex), 0);
        zgl.vertexAttribPointer(1, 2, zgl.Type.float, false, @sizeOf(Vertex), @sizeOf(f32) * 2);

        //Enable the vertex attributes
        zgl.enableVertexAttribArray(0);
        zgl.enableVertexAttribArray(1);

        //The instance vertex buffer
        zgl.bindBuffer(self.instance_vbo, zgl.BufferTarget.array_buffer);

        var offset: usize = 0;
        zgl.vertexAttribPointer(2, 2, zgl.Type.float, false, @sizeOf(Instance), offset);
        offset += @sizeOf(Vector2);
        zgl.vertexAttribPointer(3, 2, zgl.Type.float, false, @sizeOf(Instance), offset);
        offset += @sizeOf(Vector2);
        zgl.vertexAttribPointer(4, 4, zgl.Type.float, false, @sizeOf(Instance), offset);
        offset += @sizeOf(Color);
        zgl.vertexAttribPointer(5, 2, zgl.Type.float, false, @sizeOf(Instance), offset);
        offset += @sizeOf(Vector2);
        zgl.vertexAttribPointer(6, 2, zgl.Type.float, false, @sizeOf(Instance), offset);
        offset += @sizeOf(Vector2);
        zgl.vertexAttribPointer(7, 1, zgl.Type.float, false, @sizeOf(Instance), offset);
        offset += @sizeOf(f32);
        zgl.vertexAttribIPointer(8, 1, zgl.Type.int, @sizeOf(Instance), offset);
        // offset += @sizeOf(i32);
        // std.log.info("{d}:{d}", .{offset, @sizeOf(Instance)});

        zgl.enableVertexAttribArray(2);
        zgl.vertexAttribDivisor(2, 1);
        zgl.enableVertexAttribArray(3);
        zgl.vertexAttribDivisor(3, 1);
        zgl.enableVertexAttribArray(4);
        zgl.vertexAttribDivisor(4, 1);
        zgl.enableVertexAttribArray(5);
        zgl.vertexAttribDivisor(5, 1);
        zgl.enableVertexAttribArray(6);
        zgl.vertexAttribDivisor(6, 1);
        zgl.enableVertexAttribArray(7);
        zgl.vertexAttribDivisor(7, 1);
        zgl.enableVertexAttribArray(8);
        zgl.vertexAttribDivisor(8, 1);

        try updateProjectionMatrix(iface);

        zgl.uniform1i(zgl.getUniformLocation(self.program, "tex_0"), 0);
        zgl.uniform1i(zgl.getUniformLocation(self.program, "tex_1"), 1);
        zgl.uniform1i(zgl.getUniformLocation(self.program, "tex_2"), 2);
        zgl.uniform1i(zgl.getUniformLocation(self.program, "tex_3"), 3);

        //Allocate the array that will store our instance data
        self.instance_data = try main.allocator.alloc(Instance, 256);
        self.texture_array = try main.allocator.alloc(Texture2D, 4);

        self.interface.initialized = true;
    }

    fn deinitialize(iface: *Renderer) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);

        zgl.deleteShader(self.vertexShader);
        zgl.deleteShader(self.fragmentShader);
        zgl.deleteProgram(self.program);

        zgl.deleteVertexArray(self.vao);
        zgl.deleteBuffer(self.vbo);
        zgl.deleteBuffer(self.instance_vbo);

        //Free our instance data
        main.allocator.free(self.instance_data);
        main.allocator.free(self.texture_array);

        self.interface.initialized = false;
    }

    pub fn begin(iface: *Renderer) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);

        if (self.interface.started) return error{RendererAlreadyStarted}.RendererAlreadyStarted;

        self.interface.last_render_count = 0;

        self.interface.started = true;
    }

    pub fn end(iface: *Renderer) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);
        
        if (!self.interface.started) return error{RendererNotStarted}.RendererNotStarted;

        try flush(iface);

        self.interface.started = false;
    }

    pub fn drawTexture(iface: *Renderer, pos: Vector2, size: Vector2, color: Color, tex: Texture2D, tex_pos: Vector2, tex_size: Vector2, rot: f32) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);
        
        if (self.instances >= self.instance_data.len or self.used_textures >= self.texture_array.len) try flush(iface);

        self.instance_data[self.instances] = .{ .pos = pos, .size = size, .color = color, .tex_pos = tex_pos, .tex_size = tex_size, .tex_id = @intCast(i32, try getTextureId(iface, tex)), .rotation = rot };

        self.instances += 1;
    }

    fn getTextureId(iface: *Renderer, tex: Texture2D) anyerror!usize {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);
        
        if (self.used_textures != 0) {
            var i: usize = 0;

            for (self.texture_array) |tex2| {
                if (i == self.used_textures) break;

                if (tex.texture == tex2.texture) return i;

                i += 1;
            }
        }

        self.texture_array[self.used_textures] = tex;
        self.used_textures += 1;
        return self.used_textures - 1;
    }

    fn flush(iface: *Renderer) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);
        
        if (self.instances == 0 or self.used_textures == 0) return;

        zgl.useProgram(self.program);
        zgl.bindVertexArray(self.vao);

        var i: i32 = 0;
        for (self.texture_array) |tex| {
            //Make sure we only iterate the textures we used
            if (i == self.used_textures) break;

            //Set the active texture unit
            switch (i) {
                0 => {
                    zgl.activeTexture(zgl.TextureUnit.texture_0);
                },
                1 => {
                    zgl.activeTexture(zgl.TextureUnit.texture_1);
                },
                2 => {
                    zgl.activeTexture(zgl.TextureUnit.texture_2);
                },
                3 => {
                    zgl.activeTexture(zgl.TextureUnit.texture_3);
                },
                else => {
                    return error{InvalidTextureUnit}.InvalidTextureUnit;
                },
            }

            //Bind the texture to the texture unit
            zgl.bindTexture(tex.texture, zgl.TextureTarget.@"2d");

            i += 1;
        }

        zgl.bindBuffer(self.instance_vbo, zgl.BufferTarget.array_buffer);
        zgl.bufferData(zgl.BufferTarget.array_buffer, Instance, self.instance_data, zgl.BufferUsage.static_draw);

        zgl.drawArraysInstanced(zgl.PrimitiveType.triangle_strip, 0, 6, self.instances);

        self.interface.last_render_count += self.instances;

        self.used_textures = 0;
        self.instances = 0;
    }

    pub fn updateProjectionMatrix(iface: *Renderer) anyerror!void {
        const self = @fieldParentPtr(GLESRenderer, "interface", iface);
        
        var framebufferSize = try engine.window.getFramebufferSize();

        var mat: zmath.Mat = zmath.orthographicLh(@intToFloat(f32, framebufferSize.width), @intToFloat(f32, framebufferSize.height), 0, 1);

        var mat_row_1: @Vector(4, f32) = mat[0];
        var mat_row_2: @Vector(4, f32) = mat[1];
        var mat_row_3: @Vector(4, f32) = mat[2];
        var mat_row_4: @Vector(4, f32) = mat[3];

        const proj_matrix_raw = [4][4]f32{ [4]f32{
            mat_row_1[0],
            mat_row_1[1],
            mat_row_1[2],
            mat_row_1[3],
        }, [4]f32{
            mat_row_2[0],
            mat_row_2[1],
            mat_row_2[2],
            mat_row_2[3],
        }, [4]f32{
            mat_row_3[0],
            mat_row_3[1],
            mat_row_3[2],
            mat_row_3[3],
        }, [4]f32{
            mat_row_4[0],
            mat_row_4[1],
            mat_row_4[2],
            mat_row_4[3],
        } };

        const proj_matrix = [_][4][4]f32{proj_matrix_raw};

        var proj_matrix_pos: ?u32 = zgl.getUniformLocation(self.program, "ProjectionMatrix");
        zgl.uniformMatrix4fv(proj_matrix_pos, false, &proj_matrix);
    }
};