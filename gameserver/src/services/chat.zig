const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const commandhandler = @import("../command.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const B64Decoder = std.base64.standard.Decoder;

const EmojiList = [_]u32{};

pub fn onGetFriendListInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetFriendListInfoScRsp.init(allocator);
    rsp.retcode = 0;

    var assist_list = ArrayList(protocol.AssistSimpleInfo).init(allocator);
    try assist_list.appendSlice(&[_]protocol.AssistSimpleInfo{
        .{ .pos = 0, .level = 80, .avatar_id = 1505, .dressed_skin_id = 0 },
        .{ .pos = 1, .level = 80, .avatar_id = 1502, .dressed_skin_id = 0 },
        .{ .pos = 2, .level = 80, .avatar_id = 1506, .dressed_skin_id = 0 },
    });

    var friend = protocol.FriendSimpleInfo.init(allocator);
    friend.playing_state = .PLAYING_CHALLENGE_PEAK;
    friend.create_time = 0; //timestamp
    friend.remark_name = .{ .Const = "PlanarcadiaPS" }; //friend_custom_nickname
    friend.is_marked = true;
    friend.player_info = protocol.PlayerSimpleInfo{
        .personal_card = 253001,
        .signature = .{ .Const = "Hai Trailblazer" },
        .nickname = .{ .Const = "PlanarcadiaPS" },
        .level = 70,
        .uid = 2000,
        .head_icon = 200139,
        .head_frame_info = .{
            .head_frame_expire_time = 4294967295,
            .head_frame_item_id = 226004,
        },
        .chat_bubble_id = 220008,
        .assist_simple_info_list = assist_list,
        .platform = protocol.PlatformType.ANDROID,
        .online_status = protocol.FriendOnlineStatus.FRIEND_ONLINE_STATUS_ONLINE,
    };
    try rsp.friend_list.append(friend);
    try session.send(CmdID.CmdGetFriendListInfoScRsp, rsp);
}
pub fn onChatEmojiList(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChatEmojiListScRsp.init(allocator);

    rsp.retcode = 0;
    try rsp.chat_emoji_list.appendSlice(&EmojiList);

    try session.send(CmdID.CmdGetChatEmojiListScRsp, rsp);
}
pub fn onPrivateChatHistory(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPrivateChatHistoryScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.target_side = 1;
    rsp.contact_side = 2000;
    try rsp.chat_message_list.appendSlice(&[_]protocol.ChatMessageData{
        try makeTextChat(allocator, 2000, "Use https://srtools.neonteam.dev/ to setup config"),
        try makeTextChat(allocator, 2000, "/help for command list"),
        try makeTextChat(allocator, 2000, "to use command, use '/' first"),
    });

    try session.send(CmdID.CmdGetPrivateChatHistoryScRsp, rsp);
}

pub fn onGetAiPamChatHistory(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetAiPamChatHistoryScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.target_side = 1;
    try rsp.JPCMGNGNONJ.appendSlice(&[_]protocol.ChatMessageData{
        try makeTextChat(allocator, 2000, "Nothing here yet"),
    });

    try session.send(CmdID.CmdGetAiPamChatHistoryScRsp, rsp);
}

fn makeTextChat(
    allocator: Allocator,
    uid: u32,
    text: []const u8,
) !protocol.ChatMessageData {
    var datas = std.ArrayList(protocol.MessageChatData).init(allocator);
    try datas.append(.{
        .message_type = .MSG_TYPE_CUSTOM_TEXT,
        .chat_data = .{
            .extend_type = .{
                .message_text = .{ .Const = text },
            },
        },
    });

    return .{
        .message_datas = datas,
        .CKHPFFENOBE = .{
            .role_id = uid,
        },
    };
}

pub fn onSendMsg(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SendMsgCsReq, allocator);
    defer req.deinit();

    var msg_text: []const u8 = "";
    if (req.message_datas) |message| {
        if (message.chat_data) |chat_data| {
            if (chat_data.extend_type) |extend_type| {
                switch (extend_type) {
                    .message_text => |text| msg_text = text.getSlice(),
                    else => {},
                }
            }
        }
    }

    if (msg_text.len > 0) {
        if (std.mem.indexOf(u8, msg_text, "/") != null) {
            try commandhandler.handleCommand(session, msg_text, allocator);
        } else {
            try commandhandler.sendMessage(session, msg_text, allocator);
        }
    }

    var rsp = protocol.SendMsgScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdSendMsgScRsp, rsp);
}

pub fn onTriggerAiPamSpeak(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TriggerAiPamSpeakCsReq, allocator);
    defer req.deinit();
    try session.send(CmdID.CmdTriggerAiPamSpeakScRsp, protocol.TriggerAiPamSpeakScRsp{
        .JMPPMNAONHM = req.JMPPMNAONHM,
        .retcode = 0,
    });
}
