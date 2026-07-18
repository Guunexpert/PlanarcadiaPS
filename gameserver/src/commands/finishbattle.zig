const std = @import("std");
const commandhandler = @import("../command.zig");
const Session = @import("../Session.zig");
const BattleService = @import("../services/battle.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try BattleService.forceFinishBattle(session, allocator);
    try commandhandler.sendMessage(session, "Battle force-finished.", allocator);
}
