const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Gender = enum { male, female };
pub const TbPath = enum { warrior, knight, shaman, memory, elation };
pub const MarchPath = enum { preservation, hunt };

pub const AvatarDefaults = struct {
    tb_gender: Gender = .female,
    tb_path: TbPath = .elation,
    march_path: MarchPath = .preservation,
    lineup: []u32,
    leader: u32 = 0,

    pub fn tbAvatarId(self: AvatarDefaults) u32 {
        const base: u32 = switch (self.tb_path) {
            .warrior => 0,
            .knight => 1,
            .shaman => 2,
            .memory => 3,
            .elation => 4,
        };
        const gender_offset: u32 = if (self.tb_gender == .female) 1 else 0;
        return 8001 + base * 2 + gender_offset;
    }

    pub fn marchAvatarId(self: AvatarDefaults) u32 {
        return if (self.march_path == .preservation) 1001 else 1224;
    }
};

pub const MiscDefaults = struct {
    avatar: AvatarDefaults,
    funmode_lineup: []u32,

    pub fn deinit(self: *MiscDefaults, allocator: Allocator) void {
        allocator.free(self.avatar.lineup);
        allocator.free(self.funmode_lineup);
    }
};

fn parseU32(v: std.json.Value, fallback: u32) u32 {
    return switch (v) {
        .integer => |x| if (x < 0) fallback else @intCast(x),
        .float => |x| if (x < 0) fallback else @intFromFloat(x),
        else => fallback,
    };
}

fn parseLineup(allocator: Allocator, node: ?std.json.Value, fallback: []const u32) ![]u32 {
    if (node) |n| {
        if (n == .array and n.array.items.len != 0) {
            var out = try allocator.alloc(u32, n.array.items.len);
            for (n.array.items, 0..) |v, i| out[i] = parseU32(v, 0);
            return out;
        }
    }
    const out = try allocator.alloc(u32, fallback.len);
    @memcpy(out, fallback);
    return out;
}

fn parseGender(node: ?std.json.Value) Gender {
    if (node) |n| {
        if (n == .string and std.ascii.eqlIgnoreCase(n.string, "male")) return .male;
    }
    return .female;
}

fn parseTbPath(node: ?std.json.Value) TbPath {
    if (node) |n| {
        if (n == .string) {
            const s = n.string;
            if (std.ascii.eqlIgnoreCase(s, "warrior") or std.ascii.eqlIgnoreCase(s, "destruction")) return .warrior;
            if (std.ascii.eqlIgnoreCase(s, "knight") or std.ascii.eqlIgnoreCase(s, "preservation")) return .knight;
            if (std.ascii.eqlIgnoreCase(s, "shaman") or std.ascii.eqlIgnoreCase(s, "harmony")) return .shaman;
            if (std.ascii.eqlIgnoreCase(s, "memory") or std.ascii.eqlIgnoreCase(s, "remembrance")) return .memory;
            if (std.ascii.eqlIgnoreCase(s, "elation") or std.ascii.eqlIgnoreCase(s, "nihility")) return .elation;
        }
    }
    return .elation;
}

fn parseMarchPath(node: ?std.json.Value) MarchPath {
    if (node) |n| {
        if (n == .string) {
            const s = n.string;
            if (std.ascii.eqlIgnoreCase(s, "hunt") or std.ascii.eqlIgnoreCase(s, "the hunt") or std.ascii.eqlIgnoreCase(s, "rogue")) return .hunt;
        }
    }
    return .preservation;
}

pub fn defaults(allocator: Allocator) !MiscDefaults {
    return .{
        .avatar = .{
            .tb_gender = .female,
            .tb_path = .elation,
            .march_path = .preservation,
            .lineup = try parseLineup(allocator, null, &[_]u32{ 1407, 1409, 1413, 1415 }),
            .leader = 0,
        },
        .funmode_lineup = try parseLineup(allocator, null, &[_]u32{ 1407, 1409, 1413, 1415 }),
    };
}

pub fn loadFromFile(allocator: Allocator, path: []const u8) !MiscDefaults {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const bytes = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(bytes);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    const root = parsed.value;

    var out = try defaults(allocator);
    errdefer out.deinit(allocator);

    if (root != .object) return out;

    if (root.object.get("avatar")) |avatar_node| {
        if (avatar_node == .object) {
            const obj = avatar_node.object;
            out.avatar.tb_gender = parseGender(obj.get("tb_gender"));
            out.avatar.tb_path = parseTbPath(obj.get("tb_path"));
            out.avatar.march_path = parseMarchPath(obj.get("march_path"));
            out.avatar.leader = if (obj.get("leader")) |v| parseU32(v, out.avatar.leader) else out.avatar.leader;

            const parsed_lineup = try parseLineup(allocator, obj.get("lineup"), out.avatar.lineup);
            allocator.free(out.avatar.lineup);
            out.avatar.lineup = parsed_lineup;
        }
    }

    const parsed_funmode = try parseLineup(allocator, root.object.get("funmode_lineup"), out.funmode_lineup);
    allocator.free(out.funmode_lineup);
    out.funmode_lineup = parsed_funmode;

    return out;
}
