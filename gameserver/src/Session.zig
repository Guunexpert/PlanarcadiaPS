const std = @import("std");
const protocol = @import("protocol");
const handlers = @import("handlers.zig");
const Packet = @import("Packet.zig");
const ConfigManager = @import("../src/manager/config_mgr.zig");
const PlayerState = @import("player_state.zig").PlayerState;

const Allocator = std.mem.Allocator;
const Stream = std.net.Stream;
const Address = std.net.Address;

const Self = @This();
const log = std.log.scoped(.session);

player_state: ?PlayerState = null,
address: Address,
stream: Stream,
allocator: Allocator,
main_allocator: Allocator,
game_config_cache: *ConfigManager.GameConfigCache,
pending_lua_script: ?[]u8 = null,
last_starlite_sent_ms: u64 = 0,
last_seen_game_config_mtime: i128 = 0,

pub fn init(
    address: Address,
    stream: Stream,
    session_allocator: Allocator,
    main_allocator: Allocator,
    game_config_cache: *ConfigManager.GameConfigCache,
) Self {
    return .{
        .player_state = null,
        .address = address,
        .stream = stream,
        .allocator = session_allocator,
        .main_allocator = main_allocator,
        .game_config_cache = game_config_cache,
        .pending_lua_script = null,
        .last_starlite_sent_ms = 0,
        .last_seen_game_config_mtime = ConfigManager.getGameConfigMtime(),
    };
}

pub fn run(self: *Self) !void {
    defer self.stream.close();
    defer {
        if (self.player_state) |*state| {
            state.deinit();
            self.player_state = null;
        }
        if (self.pending_lua_script) |buf| {
            self.allocator.free(buf);
            self.pending_lua_script = null;
        }
    }

    var reader = self.stream.reader();
    while (true) {
        var packet = Packet.read(&reader, self.allocator) catch break;
        defer packet.deinit();
        try handlers.handle(self, &packet);
    }
}

pub fn setPendingLuaScript(self: *Self, buf: []u8) void {
    if (self.pending_lua_script) |old| self.allocator.free(old);
    self.pending_lua_script = buf;
}

pub fn takePendingLuaScript(self: *Self) ?[]u8 {
    const buf = self.pending_lua_script orelse return null;
    self.pending_lua_script = null;
    return buf;
}

pub fn send(self: *Self, cmd_id: protocol.CmdID, proto: anytype) !void {
    const data = try proto.encode(self.allocator);
    defer self.allocator.free(data);

    const packet = try Packet.encode(@intFromEnum(cmd_id), &.{}, data, self.allocator);
    defer self.allocator.free(packet);

    _ = try self.stream.write(packet);
}

pub fn send_empty(self: *Self, cmd_id: protocol.CmdID) !void {
    const packet = try Packet.encode(@intFromEnum(cmd_id), &.{}, &.{}, self.allocator);
    defer self.allocator.free(packet);

    _ = try self.stream.write(packet);
    log.debug("sent EMPTY packet with id {}", .{cmd_id});
}
