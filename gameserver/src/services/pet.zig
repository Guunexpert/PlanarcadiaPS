const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const OwnedPet = [_]u32{ 251001, 251002, 251003, 251004 };

pub fn onGetPetData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPetDataScRsp.init(allocator);
    rsp.retcode = 0;
    try rsp.unlocked_pet_id.appendSlice(&OwnedPet);
    try session.send(CmdID.CmdGetPetDataScRsp, rsp);
}
pub fn onRecallPet(session: *Session, _: *const Packet, _: Allocator) !void {
    try session.send(CmdID.CmdRecallPetScRsp, protocol.RecallPetScRsp{
        .retcode = 0,
    });
}
pub fn onSummonPet(session: *Session, _: *const Packet, _: Allocator) !void {
    try session.send(CmdID.CmdSummonPetScRsp, protocol.SummonPetScRsp{
        .retcode = 0,
    });
}
