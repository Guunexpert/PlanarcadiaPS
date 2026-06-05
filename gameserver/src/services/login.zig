const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const PlayerStateMod = @import("../player_state.zig");
const LineupService = @import("./lineup.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const CmdID = protocol.CmdID;
const embedded_enter_lua: []const u8 = @embedFile("../lua/welcome.lua");
const embedded_freecam_lua: []const u8 = @embedFile("../lua/freecam.lua");

const content = [_]u32{
    200001, 200002, 200003, 200004, 200005, 200006, 200007, 200008,
    150017, 150015, 150021, 150018, 130011, 130012, 130013, 150025,
    140006, 150026, 130014, 150034, 150029, 150035, 150041, 150039,
    150045, 150057, 150042, 150067, 150064, 150063, 150024, 171002,
    150068, 150070, 150071, 150073, 150074, 150075,
};

pub fn onPlayerGetToken(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.PlayerGetTokenScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.uid = 1;

    try session.send(CmdID.CmdPlayerGetTokenScRsp, rsp);
}

pub fn onPlayerLogin(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerLoginCsReq, allocator);
    defer req.deinit();
    const uid: u32 = 1;

    session.player_state = try PlayerStateMod.loadOrCreate(session.allocator, uid);
    LineupService.ensureLeaderDefault();
    if (ConfigManager.global_misc_defaults.avatar.lineup.len != 0) {
        try LineupManager.getSelectedAvatarID(allocator, ConfigManager.global_misc_defaults.avatar.lineup);
    }

    var basic_info = protocol.PlayerBasicInfo.init(allocator);
    basic_info.stamina = session.player_state.?.stamina;
    basic_info.level = session.player_state.?.level;
    basic_info.nickname = .{ .Const = "Planarcadia" };
    basic_info.world_level = session.player_state.?.world_level;
    basic_info.mcoin = session.player_state.?.mcoin;
    basic_info.hcoin = session.player_state.?.hcoin;
    basic_info.scoin = session.player_state.?.scoin;

    var rsp = protocol.PlayerLoginScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.login_random = req.login_random;
    rsp.stamina = session.player_state.?.stamina;
    rsp.basic_info = basic_info;

    try session.send(CmdID.CmdPlayerLoginScRsp, rsp);
}

pub fn onPlayerLoginFinish(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var package_data = protocol.ContentPackageData.init(allocator);
    package_data.cur_content_id = 0;
    for (content) |id| {
        try package_data.content_package_list.append(protocol.ContentPackageInfo{
            .content_id = id,
            .status = protocol.ContentPackageStatus.ContentPackageStatus_Finished,
        });
    }
    try session.send(CmdID.CmdContentPackageSyncDataScNotify, protocol.ContentPackageSyncDataScNotify{
        .data = package_data,
    });
    try session.send(CmdID.CmdPlayerLoginFinishScRsp, protocol.PlayerLoginFinishScRsp{
        .retcode = 0,
    });

    if (session.pending_lua_script == null and embedded_enter_lua.len != 0) {
        const owned = try session.allocator.dupe(u8, embedded_enter_lua);
        session.setPendingLuaScript(owned);
    }
}

pub fn onContentPackageGetData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.ContentPackageGetDataScRsp.init(allocator);
    rsp.retcode = 0;
    var package_data = protocol.ContentPackageData.init(allocator);
    package_data.cur_content_id = 0;
    for (content) |id| {
        try package_data.content_package_list.append(protocol.ContentPackageInfo{
            .content_id = id,
            .status = protocol.ContentPackageStatus.ContentPackageStatus_Finished,
        });
    }
    try session.send(CmdID.CmdContentPackageGetDataScRsp, rsp);
}

pub fn onSetClientPaused(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetClientPausedCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdSetClientPausedScRsp, protocol.SetClientPausedScRsp{
        .retcode = 0,
        .paused = req.paused,
    });
}

pub fn onGetArchiveData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var data = protocol.ArchiveData.init(allocator);
    try data.archive_avatar_id_list.append(1505);
    try data.archive_missing_equipment_id_list.append(23000);
    try session.send(CmdID.CmdGetArchiveDataScRsp, protocol.GetArchiveDataScRsp{
        .retcode = 0,
        .archive_data = data,
    });
}
pub fn onGetUpdatedArchiveData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var data = protocol.ArchiveData.init(allocator);
    try data.archive_avatar_id_list.append(1505);
    try data.archive_missing_equipment_id_list.append(23000);
    try session.send(CmdID.CmdGetUpdatedArchiveDataScRsp, protocol.GetUpdatedArchiveDataScRsp{
        .retcode = 0,
        .archive_data = data,
    });
}
