const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const Config = @import("../data/stage_config.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const AvatatarManager = @import("../manager/avatar_mgr.zig");
const Logic = @import("../utils/logic.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Test Command for Chat\n", allocator);
}
pub fn challengeNode(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, Logic.CustomMode().ChangeNode(), allocator);
}
pub fn FunMode(session: *Session, input: []const u8, allocator: Allocator) !void {
    var args = std.mem.tokenizeAny(u8, input, " ");
    if (args.next()) |subcmd| {
        if (std.mem.eql(u8, subcmd, "on")) {
            Logic.FunMode().SetFunMode(true);
            const misc_funmode = ConfigManager.global_misc_defaults.funmode_lineup;
            if (misc_funmode.len != 0) {
                var ids = std.ArrayList(u32).init(allocator);
                defer ids.deinit();
                try ids.ensureUnusedCapacity(misc_funmode.len);
                for (misc_funmode) |id| {
                    const mapped = if (id >= 8001 and id <= 8010)
                        AvatatarManager.currentMcId()
                    else if (id == 1001 or id == 1224)
                        AvatatarManager.currentM7th()
                    else
                        id;
                    try ids.append(mapped);
                }
                try LineupManager.getFunModeAvatarID(ids.items);
            } else {
                const config = &ConfigManager.global_game_config_cache.game_config;
                var ids = std.ArrayList(u32).init(allocator);
                defer ids.deinit();
                var picked_mc = false;
                var picked_m7th = false;
                for (config.avatar_config.items) |avatarConf| {
                    const id = switch (avatarConf.id) {
                        8001...8010 => if (!picked_mc) blk: {
                            picked_mc = true;
                            break :blk AvatatarManager.currentMcId();
                        } else continue,
                        1224, 1001 => if (!picked_m7th) blk: {
                            picked_m7th = true;
                            break :blk AvatatarManager.currentM7th();
                        } else continue,
                        else => avatarConf.id,
                    };
                    try ids.append(id);
                }
                try LineupManager.getFunModeAvatarID(ids.items);
            }
            try commandhandler.sendMessage(session, "Fun mode ON\n", allocator);
        } else if (std.mem.eql(u8, subcmd, "off")) {
            Logic.FunMode().SetFunMode(false);
            try commandhandler.sendMessage(session, "Fun mode OFF\n", allocator);
        } else if (std.mem.eql(u8, subcmd, "hp")) {
            if (args.next()) |hp_arg| {
                if (std.mem.eql(u8, hp_arg, "max")) {
                    Logic.FunMode().SetHp(std.math.maxInt(i32));
                    try commandhandler.sendMessage(session, "Set HP = MAX (2,147,483,647)\n", allocator);
                    try commandhandler.sendMessage(session, "Remember to set it back to 0 to use actual HP value\n", allocator);
                } else {
                    const parsed = try std.fmt.parseInt(i64, hp_arg, 10);
                    if (parsed < 0 or parsed > std.math.maxInt(i32)) {
                        try commandhandler.sendMessage(session, "Error: HP out of range (0 - 2147483647)\n", allocator);
                    } else {
                        Logic.FunMode().SetHp(@intCast(parsed));
                        try commandhandler.sendMessage(
                            session,
                            try std.fmt.allocPrint(allocator, "Set HP = {d}\n", .{parsed}),
                            allocator,
                        );
                        try commandhandler.sendMessage(session, "Remember to set it back to 0 to use actual HP value\n", allocator);
                    }
                }
            } else {
                try commandhandler.sendMessage(session, "Usage: /funmode hp <max|number>\n", allocator);
            }
        } else {
            try commandhandler.sendMessage(session, "Unknown funmode subcommand\n", allocator);
        }
    } else {
        try commandhandler.sendMessage(session, "Usage: /funmode <on|off|hp>\n", allocator);
    }
}

pub fn setGachaCommand(session: *Session, args: []const u8, allocator: Allocator) !void {
    var arg_iter = std.mem.splitSequence(u8, args, " ");
    const command = arg_iter.next() orelse {
        try commandhandler.sendMessage(session, "Error: Missing sub-command. Usage: /set <sub-command> [arguments]", allocator);
        return;
    };
    if (std.mem.eql(u8, command, "standard")) {
        try standard(session, &arg_iter, allocator);
    } else if (std.mem.eql(u8, command, "rateup")) {
        const next = arg_iter.next();
        if (next) |rateup_number| {
            if (std.mem.eql(u8, rateup_number, "5")) {
                try gacha5Stars(session, &arg_iter, allocator);
            } else if (std.mem.eql(u8, rateup_number, "4")) {
                try gacha4Stars(session, &arg_iter, allocator);
            } else {
                try commandhandler.sendMessage(session, "Error: Invalid rateup number. Please use 4 (four stars) or 5 (5 stars).", allocator);
            }
        } else {
            try commandhandler.sendMessage(session, "Error: Missing number for rateup. Usage: /set rateup <number>", allocator);
        }
    } else {
        try commandhandler.sendMessage(session, "Error: Unknown sub-command. Available: standard, rateup 5, rateup 4", allocator);
    }
}

fn standard(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [6]u32 = undefined;
    var count: usize = 0;
    while (count < 6) {
        if (arg_iter.next()) |avatar_id_str| {
            const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
                return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
            };
            if (!isValidAvatarId(id)) {
                return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
            }
            avatar_ids[count] = id;
            count += 1;
        } else {
            break;
        }
    }
    if (arg_iter.next() != null or count != 6) {
        return sendErrorMessage(session, "Error: You must provide exactly 6 avatar IDs.", allocator);
    }
    @memcpy(Logic.Banner().SetStandardBanner(), &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set standard banner ID to: {d}, {d}, {d}, {d}, {d}, {d}", .{ avatar_ids[0], avatar_ids[1], avatar_ids[2], avatar_ids[3], avatar_ids[4], avatar_ids[5] });
    try commandhandler.sendMessage(session, msg, allocator);
}
fn gacha4Stars(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [3]u32 = undefined;
    var count: usize = 0;
    while (count < 3) {
        if (arg_iter.next()) |avatar_id_str| {
            const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
                return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
            };
            if (!isValidAvatarId(id)) {
                return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
            }
            avatar_ids[count] = id;
            count += 1;
        } else {
            break;
        }
    }
    if (arg_iter.next() != null or count != 3) {
        return sendErrorMessage(session, "Error: You must provide exactly 3 avatar IDs.", allocator);
    }
    @memcpy(Logic.Banner().SetRateUpFourStar(), &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set 4 star rate up ID to: {d}, {d}, {d}", .{ avatar_ids[0], avatar_ids[1], avatar_ids[2] });
    try commandhandler.sendMessage(session, msg, allocator);
}
fn gacha5Stars(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [1]u32 = undefined;
    if (arg_iter.next()) |avatar_id_str| {
        const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
            return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
        };
        if (!isValidAvatarId(id)) {
            return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
        }
        avatar_ids[0] = id;
    } else {
        return sendErrorMessage(session, "Error: You must provide a rate-up avatar ID.", allocator);
    }
    if (arg_iter.next() != null) {
        return sendErrorMessage(session, "Error: Only one rate-up avatar ID is allowed.", allocator);
    }
    @memcpy(Logic.Banner().SetRateUp(), &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set rate up ID to: {d}", .{avatar_ids[0]});
    try commandhandler.sendMessage(session, msg, allocator);
}
fn sendErrorMessage(session: *Session, message: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, message, allocator);
}
fn isValidAvatarId(avatar_id: u32) bool {
    return avatar_id >= 1000 and avatar_id <= 9999;
}
pub fn onBuffId(session: *Session, input: []const u8, allocator: Allocator) !void {
    if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, input, " "), "info")) {
        return try onBuffInfo(session, allocator);
    }
    var tokens = std.ArrayList([]const u8).init(allocator);
    defer tokens.deinit();
    var iter = std.mem.tokenizeScalar(u8, input, ' ');
    while (iter.next()) |tok| {
        try tokens.append(tok);
    }
    if (tokens.items.len == 0) {
        return sendErrorMessage(session, "Error: Missing command arguments.", allocator);
    }
    if (std.ascii.eqlIgnoreCase(tokens.items[0], "off")) {
        Logic.CustomMode().SetCustomMode(false);
        _ = try commandhandler.sendMessage(session, "Custom mode OFF.", allocator);
        return;
    }
    if (tokens.items.len < 6) {
        return sendErrorMessage(session, "Error: Usage: /id <group_id> floor <n> node <1|2>", allocator);
    }
    const group_id = std.fmt.parseInt(u32, tokens.items[0], 10) catch return sendErrorMessage(session, "Error: Invalid group ID.", allocator);
    if (!std.ascii.eqlIgnoreCase(tokens.items[1], "floor")) return sendErrorMessage(session, "Error: Expected 'floor' keyword.", allocator);
    const floor = std.fmt.parseInt(u32, tokens.items[2], 10) catch return sendErrorMessage(session, "Error: Invalid floor number.", allocator);
    if (!std.ascii.eqlIgnoreCase(tokens.items[3], "node")) return sendErrorMessage(session, "Error: Expected 'node' keyword.", allocator);
    const node = std.fmt.parseInt(u8, tokens.items[4], 10) catch return sendErrorMessage(session, "Error: Invalid node number.", allocator);
    if (node != 1 and node != 2) return sendErrorMessage(session, "Error: Node must be 1 or 2.", allocator);
    Logic.CustomMode().SelectCustomNode(node);
    const challenge_mode = switch (group_id / 1000) {
        1 => "MoC",
        2 => "PF",
        3 => "AS",
        else => "Unknown",
    };
    try commandhandler.sendMessage(session, try std.fmt.allocPrint(allocator, "Challenge mode: {s}", .{challenge_mode}), allocator);
    const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;
    const stage_config = &ConfigManager.global_game_config_cache.stage_config;
    const challenge_entry = for (challenge_config.challenge_config.items) |entry| {
        if (entry.group_id == group_id and entry.floor == floor)
            break entry;
    } else {
        return sendErrorMessage(session, "Error: Could not find matching challenge ID.", allocator);
    };
    if (tokens.items.len > 5) {
        const keyword = tokens.items[5];
        if (std.ascii.eqlIgnoreCase(keyword, "buff")) {
            if (tokens.items.len < 7) {
                return sendErrorMessage(session, "Error: Missing buff sub-command (info/set <index>).", allocator);
            }
            const sub = tokens.items[6];
            if (std.ascii.eqlIgnoreCase(sub, "info")) {
                return sendBuffInfo(session, allocator, group_id, node);
            } else if (std.ascii.eqlIgnoreCase(sub, "set")) {
                return sendErrorMessage(session, "Error: Missing buff index for 'set' command.", allocator);
            } else {
                const buff_index = std.fmt.parseInt(usize, sub, 10) catch {
                    return sendErrorMessage(session, "Error: Invalid buff index.", allocator);
                };
                if (tokens.items.len < 8 or !std.ascii.eqlIgnoreCase(tokens.items[7], "set")) {
                    return sendErrorMessage(session, "Error: Expected 'set' after buff index.", allocator);
                }
                return handleBuffSetCommand(session, allocator, group_id, node, buff_index, challenge_entry.id);
            }
        } else if (std.ascii.eqlIgnoreCase(keyword, "set")) {
            if ((group_id / 1000) != 1) {
                return sendErrorMessage(session, "Error: Unexpected 'set' command. Did you mean 'buff <index> set' ?", allocator);
            }
            try handleMoCSelectChallenge(session, allocator, challenge_entry.id);
            return;
        }
    }
    var event_id: ?u32 = null;
    if (node == 1 and challenge_entry.event_id_list1.items.len > 0) {
        event_id = challenge_entry.event_id_list1.items[0];
    } else if (node == 2 and challenge_entry.event_id_list2.items.len > 0) {
        event_id = challenge_entry.event_id_list2.items[0];
    }
    if (event_id == null) {
        return sendErrorMessage(session, "Error: Could not find matching EventID.", allocator);
    }
    if ((group_id / 1000) == 1) {
        try handleMoCSelectChallenge(session, allocator, challenge_entry.id);
        return;
    }
    for (stage_config.stage_config.items) |stage| {
        if (stage.stage_id == event_id.?) {
            try sendStageInfo(session, allocator, group_id, floor, node, stage);
            return;
        }
    }
    return sendErrorMessage(session, "Error: Stage not found for given EventID.", allocator);
}
fn handleMoCSelectChallenge(session: *Session, allocator: Allocator, challenge_id: u32) !void {
    const line = try std.fmt.allocPrint(allocator, "Selected MoC Challenge ID: {d}", .{challenge_id});
    try commandhandler.sendMessage(session, line, allocator);
    Logic.CustomMode().SetCustomChallengeID(challenge_id);
    Logic.CustomMode().SetCustomBuffID(0);
    Logic.CustomMode().SetCustomMode(true);
}
fn handleBuffSetCommand(session: *Session, allocator: Allocator, group_id: u32, node: u8, buff_index: usize, challenge_id: u32) !void {
    const buff_config = &ConfigManager.global_game_config_cache.buff_info_config;
    for (buff_config.text_map_config.items) |entry| {
        if (entry.group_id == group_id) {
            const list = if (node == 1) &entry.buff_list1 else &entry.buff_list2;
            if (buff_index == 0 or buff_index > list.items.len) {
                return sendErrorMessage(session, "Error: Buff index out of range.", allocator);
            }
            const buff = list.items[buff_index - 1];
            const line = try std.fmt.allocPrint(allocator, "Selected Challenge ID: {d}, Buff ID: {d} - {s}", .{ challenge_id, buff.id, buff.name });
            try commandhandler.sendMessage(session, line, allocator);
            Logic.CustomMode().SetCustomChallengeID(challenge_id);
            Logic.CustomMode().SetCustomBuffID(buff.id);
            Logic.CustomMode().SetCustomMode(true);
            return;
        }
    }
    return sendErrorMessage(session, "Error: Buff group ID not found.", allocator);
}
fn sendStageInfo(session: *Session, allocator: Allocator, group_id: u32, floor: u32, node: u8, stage: Config.Stage) !void {
    const header = try std.fmt.allocPrint(allocator, "GroupID: {d}, Floor: {d}, Node: {d}, StageID: {d}", .{ group_id, floor, node, stage.stage_id });
    try commandhandler.sendMessage(session, header, allocator);
    for (stage.monster_list.items, 0..) |wave, i| {
        var msg = try std.fmt.allocPrint(allocator, "wave {d}:", .{i + 1});
        for (wave.items) |monster_id| {
            msg = try std.fmt.allocPrint(allocator, "{s} {d},", .{ msg, monster_id });
        }
        try commandhandler.sendMessage(session, msg, allocator);
    }
}
fn sendBuffInfo(session: *Session, allocator: Allocator, group_id: u32, node: u8) !void {
    const buff_config = &ConfigManager.global_game_config_cache.buff_info_config;
    for (buff_config.text_map_config.items) |entry| {
        if (entry.group_id == group_id) {
            const list = if (node == 1) &entry.buff_list1 else &entry.buff_list2;
            for (list.items) |buff| {
                const line = try std.fmt.allocPrint(allocator, "id: {d} - {s}", .{ buff.id, buff.name });
                try commandhandler.sendMessage(session, line, allocator);
            }
            return;
        }
    }
    return sendErrorMessage(session, "Error: Buff group ID not found.", allocator);
}
pub fn onBuffInfo(session: *Session, allocator: Allocator) !void {
    const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;

    var max_moc: u32 = 0;
    var max_pf: u32 = 0;
    var max_as: u32 = 0;

    for (challenge_config.challenge_config.items) |entry| {
        const id = entry.group_id;
        if (id >= 1000 and id < 2000 and id > max_moc) {
            max_moc = id;
        } else if (id >= 2000 and id < 3000 and id > max_pf) {
            max_pf = id;
        } else if (id >= 3000 and id < 4000 and id > max_as) {
            max_as = id;
        }
    }
    const msg = try std.fmt.allocPrint(allocator, "Current Challenge IDs: MoC: {d}, PF: {d}, AS: {d}", .{ max_moc, max_pf, max_as });
    try commandhandler.sendMessage(session, msg, allocator);
}
