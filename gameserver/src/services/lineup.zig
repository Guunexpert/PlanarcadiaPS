const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub var leader_slot: u32 = 0;
var leader_default_loaded: bool = false;

pub fn ensureLeaderDefault() void {
    if (leader_default_loaded) return;
    leader_slot = ConfigManager.global_misc_defaults.avatar.leader;
    leader_default_loaded = true;
}

pub fn onGetCurLineupData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    ensureLeaderDefault();
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdGetCurLineupDataScRsp, protocol.GetCurLineupDataScRsp{
        .retcode = 0,
        .lineup = lineup,
    });
}

pub fn onChangeLineupLeader(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    ensureLeaderDefault();
    const req = try packet.getProto(protocol.ChangeLineupLeaderCsReq, allocator);
    defer req.deinit();

    leader_slot = req.slot;
    try session.send(CmdID.CmdChangeLineupLeaderScRsp, protocol.ChangeLineupLeaderScRsp{
        .slot = req.slot,
        .retcode = 0,
    });
}

pub fn onReplaceLineup(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ReplaceLineupCsReq, allocator);
    defer req.deinit();

    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();

    for (req.lineup_slot_list.items) |ok| {
        try ids.append(ok.id);
    }
    const lineup = try LineupManager.buildLineup(allocator, ids.items, null);
    var rsp = protocol.SyncLineupNotify.init(allocator);
    rsp.lineup = lineup;
    rsp.lineup.?.index = req.index;
    rsp.lineup.?.leader_slot = req.leader_slot;
    rsp.lineup.?.plane_id = req.plane_id;
    rsp.lineup.?.game_story_line_id = req.game_story_line_id;
    rsp.lineup.?.extra_lineup_type = req.extra_lineup_type;
    try rsp.reason_list.append(protocol.SyncLineupReason.SYNC_REASON_NONE);
    try session.send(CmdID.CmdSyncLineupNotify, rsp);
    try session.send(CmdID.CmdReplaceLineupScRsp, protocol.ReplaceLineupScRsp{
        .retcode = 0,
    });
}

pub fn onSetLineupName(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetLineupNameCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdSetLineupNameScRsp, protocol.SetLineupNameScRsp{
        .index = req.index,
        .name = req.name,
        .retcode = 0,
    });
}
