const std = @import("std");
const BattleManager = @import("./manager/battle_mgr.zig");
const ConfigManager = @import("./manager/config_mgr.zig");
const LineupManager = @import("./manager/lineup_mgr.zig");

const Allocator = std.mem.Allocator;

pub const LineupSlots: usize = 4;
pub const MaxLineups: usize = 6;
pub const LineupPreset = [LineupSlots]u32;

pub const PlayerState = struct {
    uid: u32,
    level: u32,
    world_level: u32,
    stamina: u32,
    mcoin: u32,
    hcoin: u32,
    scoin: u32,
    cur_lineup_index: u32,
    lineups: [MaxLineups]LineupPreset,

    pub fn init(uid: u32) PlayerState {
        return .{
            .uid = uid,
            .level = 70,
            .world_level = 6,
            .stamina = 300,
            .mcoin = 99_999_990,
            .hcoin = 99_999_990,
            .scoin = 99_999_990,
            .cur_lineup_index = 0,
            .lineups = std.mem.zeroes([MaxLineups]LineupPreset),
        };
    }

    pub fn deinit(_: *PlayerState) void {}
};

fn writeU32Array(writer: anytype, items: []const u32) !void {
    try writer.writeAll("[");
    for (items, 0..) |v, i| {
        if (i != 0) try writer.writeAll(", ");
        try writer.print("{d}", .{v});
    }
    try writer.writeAll("]");
}

pub fn save(state: *PlayerState) !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile("misc.json", .{ .truncate = true });
    defer file.close();

    var writer = file.writer();
    const active_index: usize = @min(state.cur_lineup_index, MaxLineups - 1);

    try writer.writeAll("{\n");
    try writer.writeAll("  \"avatar\": {\n");
    try writer.print("    \"tb_gender\": \"{s}\",\n", .{if (ConfigManager.global_misc_defaults.avatar.tb_gender == .female) "Female" else "Male"});
    try writer.print("    \"tb_path\": \"{s}\",\n", .{switch (ConfigManager.global_misc_defaults.avatar.tb_path) {
        .warrior => "Warrior",
        .knight => "Knight",
        .shaman => "Shaman",
        .memory => "Memory",
        .elation => "Elation",
    }});
    try writer.print("    \"march_path\": \"{s}\",\n", .{if (ConfigManager.global_misc_defaults.avatar.march_path == .preservation) "Preservation" else "Hunt"});
    try writer.writeAll("    \"lineup\": ");
    try writeU32Array(&writer, state.lineups[active_index][0..]);
    try writer.print(",\n    \"leader\": {d}\n", .{@import("./services/lineup.zig").leader_slot});
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"funmode_lineup\": ");
    try writeU32Array(&writer, BattleManager.funmodeAvatarID.items);
    try writer.writeAll("\n}\n");
}

pub fn saveLineupToConfig(state: *PlayerState) !void {
    try save(state);
}

pub fn loadOrCreate(allocator: Allocator, uid: u32) !PlayerState {
    var state = PlayerState.init(uid);

    const avatar_defaults = ConfigManager.global_misc_defaults.avatar;
    BattleManager.funmodeAvatarID.clearRetainingCapacity();
    try BattleManager.funmodeAvatarID.appendSlice(ConfigManager.global_misc_defaults.funmode_lineup);

    for (state.lineups[0][0..], 0..) |*slot, i| {
        slot.* = if (i < avatar_defaults.lineup.len) avatar_defaults.lineup[i] else 0;
    }
    for (state.lineups[1..]) |*preset| {
        preset.* = std.mem.zeroes(LineupPreset);
    }

    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();
    for (state.lineups[0]) |id| {
        if (id != 0) try ids.append(id);
    }
    try LineupManager.getSelectedAvatarID(allocator, ids.items);

    return state;
}

pub fn applySavedLineup(_: *PlayerState) !void {}
