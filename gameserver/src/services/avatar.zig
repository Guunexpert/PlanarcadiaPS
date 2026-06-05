const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const Uid = @import("../utils/uid.zig");

const AvatarManager = @import("../manager/avatar_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;

pub fn onGetAvatarData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    Uid.resetGlobalUidGen(0);

    const req = try packet.getProto(protocol.GetAvatarDataCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetAvatarDataScRsp.init(allocator);
    try rsp.skin_list.appendSlice(&Data.SkinList);
    rsp.is_get_all = req.is_get_all;
    for (Data.AllAvatars) |id| {
        const avatar = try AvatarManager.createAllAvatar(allocator, id);
        try rsp.avatar_list.append(avatar);
    }
    for (Data.AllAvatars) |id| {
        const avatar = try AvatarManager.createAllAvatarPathData(allocator, id);
        try rsp.avatar_path_data_info_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try AvatarManager.createAvatar(allocator, avatarConf);
        try rsp.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try AvatarManager.createAvatarPathData(allocator, avatarConf);
        try rsp.avatar_path_data_info_list.append(avatar);
    }
    try session.send(CmdID.CmdGetAvatarDataScRsp, rsp);
}

pub fn onGetBasicInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetBasicInfoScRsp.init(allocator);
    rsp.gender = if (ConfigManager.global_misc_defaults.avatar.tb_gender == .female) 2 else 1;
    rsp.is_gender_set = true;
    rsp.player_setting_info = .{
        .OKAHMFOINPM = std.ArrayList(protocol.KVP).init(allocator),
    };
    try session.send(CmdID.CmdGetBasicInfoScRsp, rsp);
}

pub fn onSetAvatarPath(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.SetAvatarPathScRsp.init(allocator);
    const req = try packet.getProto(protocol.SetAvatarPathCsReq, allocator);
    defer req.deinit();
    rsp.avatar_id = req.avatar_id;
    switch (rsp.avatar_id) {
        protocol.MultiPathAvatarType.Mar_7thKnightType => AvatarManager.setM7th(1001),
        protocol.MultiPathAvatarType.Mar_7thRogueType => AvatarManager.setM7th(1224),
        else => AvatarManager.setMcId(@intCast(@intFromEnum(rsp.avatar_id))),
    }
    var change = protocol.AvatarPathChangedNotify.init(allocator);
    switch (req.avatar_id) {
        protocol.MultiPathAvatarType.Mar_7thKnightType => change.base_avatar_id = 1001,
        protocol.MultiPathAvatarType.Mar_7thRogueType => change.base_avatar_id = 1224,
        else => change.base_avatar_id = @intCast(@intFromEnum(req.avatar_id)),
    }
    change.cur_multi_path_avatar_type = req.avatar_id;
    try session.send(CmdID.CmdAvatarPathChangedNotify, change);
    try AvatarManager.syncAvatarData(session, allocator);
    var lineup = protocol.SyncLineupNotify.init(allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const refresh = try lineup_mgr.createLineup();
    lineup.lineup = refresh;
    try session.send(CmdID.CmdSyncLineupNotify, lineup);
    try session.send(CmdID.CmdSetAvatarPathScRsp, rsp);
}
pub fn onSetPlayerOutfit(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetPlayerOutfitCsReq, allocator);
    defer req.deinit();
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    sync.DHKFCDAGHDM = req.DHKFCDAGHDM;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
    try session.send(CmdID.CmdSetPlayerOutfitScRsp, protocol.SetPlayerOutfitScRsp{
        .retcode = 0,
    });
}
pub fn onSetAvatarEnhancedId(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetAvatarEnhancedIdCsReq, allocator);
    defer req.deinit();
    if (req.enhanced_id == 0) {
        for (&Data.EnhanceAvatarID) |*id| {
            if (id.* == req.avatar_id) {
                id.* = 0;
                break;
            }
        }
    } else {
        const exists = for (&Data.EnhanceAvatarID) |id| {
            if (id == req.avatar_id) break true;
        } else false;

        if (!exists) {
            for (&Data.EnhanceAvatarID) |*id| {
                if (id.* == 0) {
                    id.* = req.avatar_id;
                    break;
                }
            }
        }
    }
    try AvatarManager.syncAvatarData(session, allocator);
    try session.send(CmdID.CmdSetAvatarEnhancedIdScRsp, protocol.SetAvatarEnhancedIdScRsp{
        .growth_avatar_id = req.avatar_id,
        .retcode = 0,
        .unk_enhanced_id = req.enhanced_id,
    });
}
pub fn onDressAvatarSkin(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.DressAvatarSkinCsReq, allocator);
    defer req.deinit();
    AvatarManager.updateSkinId(req.avatar_id, req.skin_id);
    try AvatarManager.syncAvatarData(session, allocator);
    try session.send(CmdID.CmdDressAvatarSkinScRsp, protocol.DressAvatarSkinScRsp{
        .retcode = 0,
    });
}
pub fn onTakeOffAvatarSkin(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TakeOffAvatarSkinCsReq, allocator);
    defer req.deinit();
    AvatarManager.updateSkinId(req.avatar_id, 0);
    try AvatarManager.syncAvatarData(session, allocator);
    try session.send(CmdID.CmdTakeOffAvatarSkinScRsp, protocol.TakeOffAvatarSkinScRsp{
        .retcode = 0,
    });
}
pub fn onGetBigDataAll(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetBigDataAllRecommendCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetBigDataAllRecommendScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.big_data_recommend_type = req.big_data_recommend_type;
    try session.send(CmdID.CmdGetBigDataAllRecommendScRsp, rsp);
}
pub fn onGetBigData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetBigDataRecommendCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetBigDataRecommendScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.big_data_recommend_type = req.big_data_recommend_type;
    rsp.equip_avatar = req.equip_avatar;
    try session.send(CmdID.CmdGetBigDataRecommendScRsp, rsp);
}
pub fn onGetPreAvatarGrowthInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPreAvatarGrowthInfoScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetPreAvatarGrowthInfoScRsp, rsp);
}
