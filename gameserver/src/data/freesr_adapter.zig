const std = @import("std");
const json = std.json;

const GameConfig = @import("game_config.zig").GameConfig;
const Avatar = @import("game_config.zig").Avatar;
const Relic = @import("game_config.zig").Relic;
const Allocator = std.mem.Allocator;

pub fn loadFromFreesr(allocator: Allocator) !GameConfig {
    const file = try std.fs.cwd().openFile("freesr-data.json", .{});
    defer file.close();

    const data = try file.readToEndAlloc(allocator, 16 * 1024 * 1024);
    defer allocator.free(data);

    var parsed = try json.parseFromSlice(json.Value, allocator, data, .{});
    defer parsed.deinit();
    const root = parsed.value;

    var game_cfg = GameConfig{
        .battle_config = .{
            .battle_id = 0,
            .stage_id = 0,
            .cycle_count = 0,
            .monster_wave = std.ArrayList(std.ArrayList(u32)).init(allocator),
            .monster_level = 1,
            .blessings = std.ArrayList(u32).init(allocator),
        },
        .avatar_config = std.ArrayList(Avatar).init(allocator),
    };

    var avatar_map = std.AutoHashMap(u32, usize).init(allocator);
    defer avatar_map.deinit();

    if (root.object.get("avatars")) |avs| {
        var it = avs.object.iterator();
        while (it.next()) |entry| {
            const av = entry.value_ptr.*;

            const avatar_id: u32 = @intCast(av.object.get("avatar_id").?.integer);
            const level: u32 = @intCast(av.object.get("level").?.integer);
            const promotion: u32 = @intCast(av.object.get("promotion").?.integer);
            const hp_val: u32 = @intCast((av.object.get("max_hp") orelse json.Value{ .integer = 10000 }).integer);
            const sp_max_val: u32 = @intCast((av.object.get("sp_max") orelse json.Value{ .integer = 100 }).integer);
            const sp_cur_val: u32 = @intCast((av.object.get("sp_value") orelse json.Value{ .integer = sp_max_val }).integer);

            var rank: u32 = 0;
            if (av.object.get("data")) |dv| {
                if (dv.object.get("rank")) |rv| rank = @intCast(rv.integer);
            }

            const techniques_enabled = blk: {
                if (av.object.get("techniques")) |tv| {
                    if (tv == .array) break :blk tv.array.items.len != 0;
                }
                break :blk false;
            };

            const idx = game_cfg.avatar_config.items.len;
            try game_cfg.avatar_config.append(.{
                .id = avatar_id,
                .hp = hp_val,
                .sp = sp_cur_val,
                .level = level,
                .promotion = promotion,
                .rank = rank,
                .lightcone = .{ .id = 0, .rank = 1, .level = 1, .promotion = 0 },
                .relics = std.ArrayList(Relic).init(allocator),
                .use_technique = techniques_enabled,
            });
            try avatar_map.put(avatar_id, idx);
        }
    }

    if (root.object.get("lightcones")) |lcs| {
        for (lcs.array.items) |lc| {
            const avatar_id: u32 = @intCast(lc.object.get("equip_avatar").?.integer);
            const idx = avatar_map.get(avatar_id) orelse continue;
            game_cfg.avatar_config.items[idx].lightcone = .{
                .id = @intCast(lc.object.get("item_id").?.integer),
                .rank = @intCast(lc.object.get("rank").?.integer),
                .level = @intCast(lc.object.get("level").?.integer),
                .promotion = @intCast(lc.object.get("promotion").?.integer),
            };
        }
    }

    if (root.object.get("relics")) |rels| {
        for (rels.array.items) |r| {
            const avatar_id: u32 = @intCast(r.object.get("equip_avatar").?.integer);
            const idx = avatar_map.get(avatar_id) orelse continue;

            var sub_count: u32 = 0;
            var s1: u32 = 0;
            var c1: u32 = 0;
            var t1: u32 = 0;
            var s2: u32 = 0;
            var c2: u32 = 0;
            var t2: u32 = 0;
            var s3: u32 = 0;
            var c3: u32 = 0;
            var t3: u32 = 0;
            var s4: u32 = 0;
            var c4: u32 = 0;
            var t4: u32 = 0;

            if (r.object.get("sub_affixes")) |subs| {
                sub_count = @intCast(subs.array.items.len);
                for (subs.array.items, 0..) |sv, i| {
                    const sid: u32 = @intCast(sv.object.get("sub_affix_id").?.integer);
                    const cnt: u32 = @intCast(sv.object.get("count").?.integer);
                    const step: u32 = @intCast(sv.object.get("step").?.integer);
                    switch (i) {
                        0 => {
                            s1 = sid;
                            c1 = cnt;
                            t1 = step;
                        },
                        1 => {
                            s2 = sid;
                            c2 = cnt;
                            t2 = step;
                        },
                        2 => {
                            s3 = sid;
                            c3 = cnt;
                            t3 = step;
                        },
                        3 => {
                            s4 = sid;
                            c4 = cnt;
                            t4 = step;
                        },
                        else => {},
                    }
                }
            }

            try game_cfg.avatar_config.items[idx].relics.append(.{
                .id = @intCast(r.object.get("relic_id").?.integer),
                .level = @intCast(r.object.get("level").?.integer),
                .main_affix_id = @intCast(r.object.get("main_affix_id").?.integer),
                .sub_count = sub_count,
                .stat1 = s1,
                .cnt1 = c1,
                .step1 = t1,
                .stat2 = s2,
                .cnt2 = c2,
                .step2 = t2,
                .stat3 = s3,
                .cnt3 = c3,
                .step3 = t3,
                .stat4 = s4,
                .cnt4 = c4,
                .step4 = t4,
            });
        }
    }

    if (root.object.get("battle_config")) |bc| {
        if (bc.object.get("battle_id")) |v| game_cfg.battle_config.battle_id = @intCast(v.integer);
        if (bc.object.get("stage_id")) |v| game_cfg.battle_config.stage_id = @intCast(v.integer);
        if (bc.object.get("cycle_count")) |v| game_cfg.battle_config.cycle_count = @intCast(v.integer);
        if (bc.object.get("monster_level")) |v| game_cfg.battle_config.monster_level = @intCast(v.integer);

        if (bc.object.get("blessings")) |bless| {
            for (bless.array.items) |b| {
                if (b == .integer) {
                    try game_cfg.battle_config.blessings.append(@intCast(b.integer));
                } else if (b == .object) {
                    if (b.object.get("id")) |id_val| {
                        try game_cfg.battle_config.blessings.append(@intCast(id_val.integer));
                    }
                }
            }
        }

        if (bc.object.get("monster_wave")) |waves| {
            for (waves.array.items) |wave| {
                var w = std.ArrayList(u32).init(allocator);
                for (wave.array.items) |m| {
                    if (m == .integer) {
                        try w.append(@intCast(m.integer));
                    } else if (m == .object) {
                        const mid_val = m.object.get("monster_id") orelse m.object.get("id") orelse continue;
                        const mid: u32 = @intCast(mid_val.integer);
                        const amt: u32 = if (m.object.get("amount")) |v| @intCast(v.integer) else 1;
                        var i: u32 = 0;
                        while (i < amt) : (i += 1) try w.append(mid);
                    }
                }
                try game_cfg.battle_config.monster_wave.append(w);
            }
        } else if (bc.object.get("monsters")) |waves| {
            for (waves.array.items) |wave| {
                var w = std.ArrayList(u32).init(allocator);
                for (wave.array.items) |m| {
                    const mid_val = m.object.get("monster_id") orelse m.object.get("id") orelse continue;
                    const mid: u32 = @intCast(mid_val.integer);
                    const amt: u32 = if (m.object.get("amount")) |v| @intCast(v.integer) else 1;
                    if (m.object.get("level")) |v| {
                        const lvl: u32 = @intCast(v.integer);
                        if (lvl > game_cfg.battle_config.monster_level) game_cfg.battle_config.monster_level = lvl;
                    }
                    var i: u32 = 0;
                    while (i < amt) : (i += 1) try w.append(mid);
                }
                try game_cfg.battle_config.monster_wave.append(w);
            }
        }
    }

    return game_cfg;
}
