const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetFriendAssistList(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFriendAssistListCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetFriendAssistListScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.target_side = req.target_side;

    // Server default friend + single assist avatar 1407.
    var assist_simple_list = std.ArrayList(protocol.AssistSimpleInfo).init(allocator);
    try assist_simple_list.append(.{ .pos = 0, .level = 80, .avatar_id = 1407, .dressed_skin_id = 0 });

    const server_player_info = protocol.PlayerSimpleInfo{
        .nickname = .{ .Const = "Server" },
        .level = 80,
        .uid = 68,
        .assist_simple_info_list = assist_simple_list,
        .platform = protocol.PlatformType.ANDROID,
        .online_status = protocol.FriendOnlineStatus.FRIEND_ONLINE_STATUS_ONLINE,
    };

    var skilltree = std.ArrayList(protocol.AvatarSkillTree).init(allocator);
    try skilltree.appendSlice(&[_]protocol.AvatarSkillTree{
        .{ .point_id = 1407001, .level = 6 },
        .{ .point_id = 1407002, .level = 10 },
        .{ .point_id = 1407003, .level = 10 },
        .{ .point_id = 1407004, .level = 10 },
        .{ .point_id = 1407007, .level = 1 },
        .{ .point_id = 1407101, .level = 1 },
        .{ .point_id = 1407102, .level = 1 },
        .{ .point_id = 1407103, .level = 1 },
        .{ .point_id = 1407201, .level = 1 },
        .{ .point_id = 1407202, .level = 1 },
        .{ .point_id = 1407203, .level = 1 },
        .{ .point_id = 1407204, .level = 1 },
        .{ .point_id = 1407205, .level = 1 },
        .{ .point_id = 1407206, .level = 1 },
        .{ .point_id = 1407207, .level = 1 },
        .{ .point_id = 1407208, .level = 1 },
        .{ .point_id = 1407209, .level = 1 },
        .{ .point_id = 1407210, .level = 1 },
        .{ .point_id = 1407301, .level = 6 },
        .{ .point_id = 1407302, .level = 6 },
    });

    const relics = std.ArrayList(protocol.DisplayRelicInfo).init(allocator);
    // Keep empty for lightweight implementation.

    const equipment: protocol.DisplayEquipmentInfo = .{
        .rank = 5,
        .level = 80,
        .promotion = 6,
        .exp = 0,
        .tid = 23040,
    };

    const assist_avatar: protocol.DisplayAvatarDetailInfo = .{
        .enhanced_id = 0,
        .avatar_id = 1407,
        .exp = 0,
        .level = 80,
        .rank = 6,
        .skilltree_list = skilltree,
        .pos = 0,
        .dressed_skin_id = 0,
        .promotion = 6,
        .equipment = equipment,
        .relic_list = relics,
    };

    try rsp.assist_list.append(.{
        .assist_avatar = assist_avatar,
        .player_info = server_player_info,
    });

    try session.send(CmdID.CmdGetFriendAssistListScRsp, rsp);
}
