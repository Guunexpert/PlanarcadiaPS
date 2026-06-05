const std = @import("std");
const protocol = @import("protocol");
const Config = @import("../data/game_config.zig");
const Session = @import("../Session.zig");
const Data = @import("../data.zig");
const Logic = @import("../utils/logic.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Uid = @import("../utils/uid.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;
const skill_config = &ConfigManager.global_game_config_cache.avatar_skill_config;

pub var m7th: u32 = 1224;
pub var mc_id: u32 = 8010;
var mc_overridden: bool = false;
var m7_overridden: bool = false;

fn stableItemUid(tag: []const u8, avatar_id: u32, seed_tid: u32, slot: u32) u32 {
    var h = std.hash.Wyhash.init(0);
    h.update(tag);
    h.update(std.mem.asBytes(&avatar_id));
    h.update(std.mem.asBytes(&seed_tid));
    h.update(std.mem.asBytes(&slot));
    const v = h.final();
    return @as(u32, @intCast(1 + (v % 0xFFFF_FFFE)));
}

fn resolveItemUid(tag: []const u8, avatar_id: u32, tid: u32, slot: u32, internal_uid: u32) u32 {
    if (avatar_id == 0) return Uid.nextGlobalId();
    const seed_tid = if (internal_uid != 0) internal_uid else tid;
    return stableItemUid(tag, avatar_id, seed_tid, slot);
}

pub fn currentMcId() u32 {
    if (mc_overridden) return mc_id;
    return ConfigManager.global_misc_defaults.avatar.tbAvatarId();
}

pub fn currentM7th() u32 {
    if (m7_overridden) return m7th;
    return ConfigManager.global_misc_defaults.avatar.marchAvatarId();
}

pub fn setMcId(id: u32) void {
    mc_id = id;
    mc_overridden = true;
}

pub fn setM7th(id: u32) void {
    m7th = id;
    m7_overridden = true;
}

pub fn createAvatar(
    allocator: Allocator,
    avatarConf: Config.Avatar,
) !protocol.Avatar {
    var avatar = protocol.Avatar.init(allocator);
    avatar.base_avatar_id = switch (avatarConf.id) {
        8001...8010 => 8001,
        1224 => 1001,
        else => avatarConf.id,
    };
    avatar.level = avatarConf.level;
    avatar.promotion = avatarConf.promotion;
    avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
    for (1..6) |i| {
        try avatar.has_taken_promotion_reward_list.append(@intCast(i));
    }
    avatar.cur_multi_path_avatar_type = avatarConf.id;
    return avatar;
}
pub fn createAllAvatar(
    allocator: Allocator,
    Avatar_id: u32,
) !protocol.Avatar {
    var avatar = protocol.Avatar.init(allocator);
    avatar.base_avatar_id = Avatar_id;
    avatar.level = 80;
    avatar.promotion = 6;
    avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
    for (1..6) |i| {
        try avatar.has_taken_promotion_reward_list.append(@intCast(i));
    }
    avatar.cur_multi_path_avatar_type = Avatar_id;
    return avatar;
}
pub fn createAvatarPathData(
    allocator: Allocator,
    avatarConf: Config.Avatar,
) !protocol.AvatarPathData {
    var avatar = protocol.AvatarPathData.init(allocator);
    avatar.avatar_id = avatarConf.id;
    avatar.rank = avatarConf.rank;
    avatar.dressed_skin_id = getSkinId(avatar.avatar_id);
    if (Logic.inlist(avatar.avatar_id, &Data.EnhanceAvatarID)) {
        avatar.unk_enhanced_id = 1;
    }
    avatar.path_equipment_id = if (avatarConf.lightcone.id == 0)
        0
    else
        resolveItemUid("LC", avatar.avatar_id, avatarConf.lightcone.id, 0, avatarConf.lightcone.internal_uid);
    avatar.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
    for (0..6) |i| {
        const has_relic = i < avatarConf.relics.items.len and avatarConf.relics.items[i].id != 0;
        try avatar.equip_relic_list.append(.{
            .relic_unique_id = if (has_relic)
                resolveItemUid("RELIC", avatar.avatar_id, avatarConf.relics.items[i].id, @as(u32, @intCast(i)), avatarConf.relics.items[i].internal_uid)
            else
                0,
            .type = @intCast(i),
        });
    }
    try createSkillTree(avatar.avatar_id, &avatar.avatar_path_skill_tree);
    return avatar;
}
pub fn createAllAvatarPathData(
    allocator: Allocator,
    Avatar_id: u32,
) !protocol.AvatarPathData {
    var avatar = protocol.AvatarPathData.init(allocator);
    avatar.avatar_id = Avatar_id;
    avatar.rank = 6;
    avatar.dressed_skin_id = getSkinId(avatar.avatar_id);
    if (Logic.inlist(avatar.avatar_id, &Data.EnhanceAvatarID)) {
        avatar.unk_enhanced_id = 1;
    }
    try createSkillTree(avatar.avatar_id, &avatar.avatar_path_skill_tree);
    return avatar;
}
fn createSkillTree(
    base_avatar_id: u32,
    skilltree_list: *std.ArrayList(protocol.AvatarPathSkillTree),
) !void {
    for (skill_config.avatar_skill_tree_config.items) |skill| {
        if (skill.avatar_id == base_avatar_id) {
            if (skill.level == skill.max_level) {
                try skilltree_list.append(.{
                    .point_id = skill.anchor_type,
                    .level = skill.max_level,
                });
            }
        }
    }
}

pub fn createEquipment(
    lightconeConf: Config.Lightcone,
    dress_avatar_id: u32,
) !protocol.Equipment {
    return protocol.Equipment{
        .unique_id = if (lightconeConf.id == 0)
            0
        else
            resolveItemUid("LC", dress_avatar_id, lightconeConf.id, 0, lightconeConf.internal_uid),
        .tid = lightconeConf.id,
        .is_protected = true,
        .level = lightconeConf.level,
        .rank = lightconeConf.rank,
        .promotion = lightconeConf.promotion,
        .dress_avatar_id = dress_avatar_id,
    };
}

pub fn createRelic(
    allocator: Allocator,
    relicConf: Config.Relic,
    dress_avatar_id: u32,
    relic_slot_index: usize,
) !protocol.Relic {
    var r = protocol.Relic{
        .tid = relicConf.id,
        .main_affix_id = relicConf.main_affix_id,
        .unique_id = resolveItemUid("RELIC", dress_avatar_id, relicConf.id, @as(u32, @intCast(relic_slot_index)), relicConf.internal_uid),
        .exp = 0,
        .dress_avatar_id = dress_avatar_id,
        .is_protected = true,
        .level = relicConf.level,
        .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
        .reforge_sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
        .preview_sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
    };
    if (relicConf.stat1 != 0) try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat1, .cnt = relicConf.cnt1, .step = relicConf.step1 });
    if (relicConf.stat2 != 0) try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat2, .cnt = relicConf.cnt2, .step = relicConf.step2 });
    if (relicConf.stat3 != 0) try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat3, .cnt = relicConf.cnt3, .step = relicConf.step3 });
    if (relicConf.stat4 != 0) try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat4, .cnt = relicConf.cnt4, .step = relicConf.step4 });
    return r;
}

fn getAvatarType(id: u32) protocol.MultiPathAvatarType {
    return switch (id) {
        1001 => .Mar_7thKnightType,
        1224 => .Mar_7thRogueType,
        else => {
            if (id < 8001 or id > 8010) return .MultiPathAvatarTypeNone; // fallback
            const base = (id - 8001) / 2;
            const is_boy = (id % 2) == 1;

            return switch (base) {
                0 => if (is_boy) .BoyWarriorType else .GirlWarriorType,
                1 => if (is_boy) .BoyKnightType else .GirlKnightType,
                2 => if (is_boy) .BoyShamanType else .GirlShamanType,
                3 => if (is_boy) .BoyMemoryType else .GirlMemoryType,
                4 => if (is_boy) .BoyElationType else .GirlElationType,
                else => .GirlElationType,
            };
        },
    };
}
pub fn getSkinId(avatar_id: u32) u32 {
    for (Data.AvatarSkinMap) |entry| {
        if (entry.avatar_id == avatar_id) return entry.skin_id;
    }
    return 0;
}
pub fn updateSkinId(avatar_id: u32, new_skin_id: u32) void {
    for (&Data.AvatarSkinMap) |*entry| {
        if (entry.avatar_id == avatar_id) {
            entry.skin_id = new_skin_id;
            return;
        }
    }
}
pub fn syncAvatarData(session: *Session, allocator: Allocator) !void {
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    defer sync.deinit();
    Uid.resetGlobalUidGens();
    var char = protocol.AvatarSync.init(allocator);
    for (Data.AllAvatars) |id| {
        const avatar = try createAllAvatar(allocator, id);
        try char.avatar_list.append(avatar);
    }
    for (Data.AllAvatars) |id| {
        const avatar = try createAllAvatarPathData(allocator, id);
        try char.avatar_path_data_info_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try createAvatar(allocator, avatarConf);
        try char.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try createAvatarPathData(allocator, avatarConf);
        try char.avatar_path_data_info_list.append(avatar);
    }
    sync.avatar_sync = char;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}
