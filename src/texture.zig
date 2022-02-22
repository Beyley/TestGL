const std = @import("std");
const zgl = @import("zgl/zgl.zig");
const qoi = @import("zig-qoi/src/qoi.zig");
const main = @import("main.zig");

pub const Texture2D = struct { texture: zgl.Texture, width: u32, height: u32 };

pub fn loadQoi(filename: []const u8) anyerror!Texture2D {
    var exe_path: []u8 = try std.fs.selfExeDirPathAlloc(main.allocator);
    defer main.allocator.free(exe_path);

    var file_path: []u8 = try std.fmt.allocPrint(main.allocator, "{s}/{s}", .{ exe_path, filename });
    defer main.allocator.free(file_path);

    std.log.info("Loading Qoi file at path {s}", .{file_path});

    var file = try std.fs.openFileAbsolute(file_path, .{});
    defer file.close();

    var file_buffer = try file.readToEndAlloc(main.allocator, 10000000);
    defer main.allocator.free(file_buffer);

    var image: qoi.Image = try qoi.decodeBuffer(main.allocator, file_buffer);
    defer image.deinit(main.allocator);

    std.log.info("Loaded qoi image size:{d}x{d}", .{ image.width, image.height });

    var texture: zgl.Texture = zgl.genTexture();
    zgl.bindTexture(texture, zgl.TextureTarget.@"2d");

    zgl.texParameter(zgl.TextureTarget.@"2d", zgl.TextureParameter.min_filter, zgl.TextureParameterType(zgl.TextureParameter.min_filter).linear);
    zgl.texParameter(zgl.TextureTarget.@"2d", zgl.TextureParameter.mag_filter, zgl.TextureParameterType(zgl.TextureParameter.mag_filter).linear);
    zgl.texParameter(zgl.TextureTarget.@"2d", zgl.TextureParameter.wrap_s, zgl.TextureParameterType(zgl.TextureParameter.wrap_s).repeat);
    zgl.texParameter(zgl.TextureTarget.@"2d", zgl.TextureParameter.wrap_t, zgl.TextureParameterType(zgl.TextureParameter.wrap_t).repeat);

    zgl.textureImage2D(zgl.TextureTarget.@"2d", 0, zgl.PixelFormat.rgba, image.width, image.height, zgl.PixelFormat.rgba, zgl.PixelType.unsigned_byte, @bitCast([]u8, image.pixels).ptr);

    return Texture2D{ .texture = texture, .width = image.width, .height = image.height };
}
