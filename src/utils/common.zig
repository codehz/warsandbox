pub const Direction = enum {
    Down,
    Up,
    Left,
    Right,
    Backward,
    Forward,
};

pub fn fillRect(origin: [3]u32, dir: Direction, uvbase: [3]u16) [8 * 4]f32 {
    const x = @intToFloat(f32, origin[0]);
    const y = @intToFloat(f32, origin[1]);
    const z = @intToFloat(f32, origin[2]);
    const uv_scale: f32 = 1 / @intToFloat(f32, uvbase[2]);
    const u_1 = @intToFloat(f32, uvbase[0]) * uv_scale;
    const v_1 = @intToFloat(f32, uvbase[1]) * uv_scale;
    const u_2 = u_1 + uv_scale;
    const v_2 = v_1 + uv_scale;

    return switch (dir) {
        .Down => [_]f32{
            x,     y,     z, 0, 0, -1, u_1, v_1,
            x,     y + 1, z, 0, 0, -1, u_1, v_2,
            x + 1, y,     z, 0, 0, -1, u_2, v_1,
            x + 1, y + 1, z, 0, 0, -1, u_2, v_2,
        },
        .Up => [_]f32{
            x,     y,     z + 1, 0, 0, 1, u_1, v_1,
            x + 1, y,     z + 1, 0, 0, 1, u_1, v_2,
            x,     y + 1, z + 1, 0, 0, 1, u_2, v_1,
            x + 1, y + 1, z + 1, 0, 0, 1, u_2, v_2,
        },
        .Left => [_]f32{
            x, y,     z,     -1, 0, 0, u_1, v_1,
            x, y,     z + 1, -1, 0, 0, u_1, v_2,
            x, y + 1, z,     -1, 0, 0, u_2, v_1,
            x, y + 1, z + 1, -1, 0, 0, u_2, v_2,
        },
        .Right => [_]f32{
            x + 1, y,     z,     1, 0, 0, u_1, v_1,
            x + 1, y + 1, z,     1, 0, 0, u_1, v_2,
            x + 1, y,     z + 1, 1, 0, 0, u_2, v_1,
            x + 1, y + 1, z + 1, 1, 0, 0, u_2, v_2,
        },
        .Backward => [_]f32{
            x,     y, z,     0, -1, 0, u_1, v_1,
            x + 1, y, z,     0, -1, 0, u_1, v_2,
            x,     y, z + 1, 0, -1, 0, u_2, v_1,
            x + 1, y, z + 1, 0, -1, 0, u_2, v_2,
        },
        .Forward => [_]f32{
            x,     y + 1, z,     0, 1, 0, u_1, v_1,
            x,     y + 1, z + 1, 0, 1, 0, u_1, v_2,
            x + 1, y + 1, z,     0, 1, 0, u_2, v_1,
            x + 1, y + 1, z + 1, 0, 1, 0, u_2, v_2,
        },
    };
}
