const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "/tp to teleport, /sync to sync data from config\n", allocator);
    try commandhandler.sendMessage(session, "/refill to refill technique point after battle\n", allocator);
    try commandhandler.sendMessage(session, "/set to set gacha banner\n", allocator);
    try commandhandler.sendMessage(session, "/node to chage node in PF, AS, MoC\n", allocator);
    try commandhandler.sendMessage(session, "/id to turn ON custom mode for challenge mode. /id info to check current challenge id. /id off to turn OFF\n", allocator);
    try commandhandler.sendMessage(session, "/funmode to Sillyism\n", allocator);
    try commandhandler.sendMessage(session, "/lua <file.lua> to queue a client lua script\n", allocator);
    try commandhandler.sendMessage(session, "You can enter MoC, PF, AS via F4 menu\n", allocator);
    try commandhandler.sendMessage(session, "(If your Castorice technique enabled, you must enter battle by using Castorice's technique)\n", allocator);
}
