const std = @import("std");

const Mutex = std.Thread.Mutex;
const AtomicBool = std.atomic.Value(bool);

pub const MaxCommandLen: usize = 512;
pub const QueueCapacity: usize = 32;
pub const MaxOutputLineLen: usize = 2048;
pub const OutputQueueCapacity: usize = 128;

pub const EnqueueError = error{
    QueueFull,
    TooLong,
};

pub const TerminalCommands = struct {
    finish_battle: AtomicBool,
};

var terminal_commands: TerminalCommands = .{
    .finish_battle = AtomicBool.init(false),
};

var cmd_mutex: Mutex = .{};
var cmd_lens: [QueueCapacity]u16 = [_]u16{0} ** QueueCapacity;
var cmd_bufs: [QueueCapacity][MaxCommandLen]u8 = undefined;
var cmd_head: usize = 0;
var cmd_tail: usize = 0;
var cmd_count: usize = 0;

var out_mutex: Mutex = .{};
var out_lens: [OutputQueueCapacity]u16 = [_]u16{0} ** OutputQueueCapacity;
var out_bufs: [OutputQueueCapacity][MaxOutputLineLen]u8 = undefined;
var out_head: usize = 0;
var out_tail: usize = 0;
var out_count: usize = 0;

pub fn requestFinishBattle() void {
    terminal_commands.finish_battle.store(true, .release);
}

pub fn takeFinishBattle() bool {
    return terminal_commands.finish_battle.swap(false, .acq_rel);
}

pub fn enqueueRaw(line: []const u8) EnqueueError!void {
    if (line.len == 0) return;
    if (line.len > MaxCommandLen) return error.TooLong;

    cmd_mutex.lock();
    defer cmd_mutex.unlock();

    if (cmd_count >= QueueCapacity) return error.QueueFull;

    @memcpy(cmd_bufs[cmd_tail][0..line.len], line);
    cmd_lens[cmd_tail] = @intCast(line.len);
    cmd_tail = (cmd_tail + 1) % QueueCapacity;
    cmd_count += 1;
}

pub fn enqueueNormalized(line: []const u8, out_buf: []u8) EnqueueError!void {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return;

    // Normalize to in-game command format: must start with '/'.
    if (trimmed[0] == '/') {
        return enqueueRaw(trimmed);
    }

    if (out_buf.len < trimmed.len + 1) return error.TooLong;
    out_buf[0] = '/';
    @memcpy(out_buf[1 .. 1 + trimmed.len], trimmed);
    return enqueueRaw(out_buf[0 .. 1 + trimmed.len]);
}

pub fn tryDequeue(into: []u8) ?[]const u8 {
    cmd_mutex.lock();
    defer cmd_mutex.unlock();

    if (cmd_count == 0) return null;

    const len: usize = cmd_lens[cmd_head];
    if (len == 0) {
        cmd_head = (cmd_head + 1) % QueueCapacity;
        cmd_count -= 1;
        return null;
    }

    const copy_len = @min(into.len, len);
    @memcpy(into[0..copy_len], cmd_bufs[cmd_head][0..copy_len]);

    cmd_lens[cmd_head] = 0;
    cmd_head = (cmd_head + 1) % QueueCapacity;
    cmd_count -= 1;

    return into[0..copy_len];
}

pub fn queueSize() usize {
    cmd_mutex.lock();
    defer cmd_mutex.unlock();
    return cmd_count;
}

pub fn pushConsoleOutput(line: []const u8) void {
    if (line.len == 0) return;

    out_mutex.lock();
    defer out_mutex.unlock();

    if (out_count >= OutputQueueCapacity) {
        // Drop the oldest to keep the latest outputs.
        out_lens[out_head] = 0;
        out_head = (out_head + 1) % OutputQueueCapacity;
        out_count -= 1;
    }

    const len: usize = @min(line.len, MaxOutputLineLen);
    @memcpy(out_bufs[out_tail][0..len], line[0..len]);
    out_lens[out_tail] = @intCast(len);
    out_tail = (out_tail + 1) % OutputQueueCapacity;
    out_count += 1;
}

pub fn tryDequeueConsoleOutput(into: []u8) ?[]const u8 {
    out_mutex.lock();
    defer out_mutex.unlock();

    if (out_count == 0) return null;

    const len: usize = out_lens[out_head];
    if (len == 0) {
        out_head = (out_head + 1) % OutputQueueCapacity;
        out_count -= 1;
        return null;
    }

    const copy_len = @min(into.len, len);
    @memcpy(into[0..copy_len], out_bufs[out_head][0..copy_len]);

    out_lens[out_head] = 0;
    out_head = (out_head + 1) % OutputQueueCapacity;
    out_count -= 1;

    return into[0..copy_len];
}

pub fn helpText() []const u8 {
    return
        \\Console commands (PlanarcadiaPS):
        \\  help | ?            Show this help
        \\  quit | exit         Stop the server process
        \\  finishbattle        Force-finish a stuck battle (best effort)
        \\
        \\Forwarding to UID=1 (in-game commands):
        \\  - Type any command like:  tp 1050101
        \\  - Or explicitly:          /tp 1050101
        \\  - For list:               /help  (or /help_cn)
        \\
        \\Notes:
        \\  - Commands are executed on the next heartbeat from the client.
        \\  - If no client is online (UID=1), commands stay queued until someone connects.
    ;
}

pub const KnownCommands = [_][]const u8{
    "help",
    "help_cn",
    "test",
    "node",
    "set",
    "tp",
    "move",
    "unstuck",
    "sync",
    "reload",
    "refill",
    "heal",
    "id",
    "buff",
    "funmode",
    "give",
    "level",
    "info",
    "scene",
    "pos",
    "savelineup",
    "lineup",
    "gender",
    "path",
    "mhp",
    "stop",
    "kick",
    "mail",
    "finishbattle",
    "lua",
};

pub fn extractCommandName(line: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return "";
    const input = if (trimmed[0] == '/') trimmed[1..] else trimmed;
    var it = std.mem.tokenizeAny(u8, input, " \t");
    return it.next() orelse "";
}

pub fn isKnownCommand(cmd: []const u8) bool {
    if (cmd.len == 0) return false;
    for (KnownCommands) |name| {
        if (std.mem.eql(u8, name, cmd)) return true;
    }
    return false;
}

pub fn buildSuggestionText(cmd: []const u8, out: []u8) ?[]const u8 {
    if (cmd.len == 0) return null;

    var matches: [5][]const u8 = undefined;
    var count: usize = 0;
    for (KnownCommands) |name| {
        if (std.mem.startsWith(u8, name, cmd) or std.mem.indexOf(u8, name, cmd) != null) {
            matches[count] = name;
            count += 1;
            if (count == matches.len) break;
        }
    }

    var fbs = std.io.fixedBufferStream(out);
    const w = fbs.writer();

    if (count == 0) {
        w.print("Unknown command: {s}. Type 'help' to list commands.\n", .{cmd}) catch return null;
        return fbs.getWritten();
    }

    w.print("Unknown command: {s}. Did you mean: ", .{cmd}) catch return null;
    for (matches[0..count], 0..) |name, i| {
        if (i != 0) w.writeAll(", ") catch return null;
        w.print("{s}", .{name}) catch return null;
    }
    w.writeAll("\n") catch return null;
    return fbs.getWritten();
}

pub fn inGameHelpEnText() []const u8 {
    return
        \\/help_cn for Chinese help
        \\/buff <id|off|info> (challenge custom buff)
        \\/heal to heal your cur lineup
        \\/refill to refill technique point
        \\/mhp <max|number|0|off> to override enemy max HP for battles
        \\/lineup <list|switch|set> for multi-team presets
        \\/set to set gacha banner
        \\/node to chage node in PF, AS, MoC
        \\/id to turn ON custom mode for challenge mode. /id info to check current challenge id. /id off to turn OFF
        \\/funmode <on|off|hp|lineup> (fun settings)
        \\You can enter MoC, PF, AS via F4 menu
        \\/sync reloads freesr-data.json and syncs items/avatars
        \\/reload alias of /sync
        \\/give to give your a Material, such as credits
        \\/level to set your Trailblaze Level
        \\/tp <entryId> | /tp <planeId> <floorId> [entryId] [teleportId]
        \\/move alias of /tp; /pos alias of /scene pos
        \\/scene get to show current scene; /scene <plane> <floor> to teleport; /scene pos to show current position; /scene reload to reload configs
        \\/info to show player basic info (uid/level/currency)
        \\/gender <male|female> (also m/f/1/2) to pick Trailblazer gender; /path <warrior|knight|shaman|memory> to pick path
        \\/kick to force a client-side logout
        \\/mail [content...] [itemId:count ...] to send a system mail
        \\/finishbattle to force a stuck battle to exit
        \\/lua <file.lua> to send/execute a lua script from lua/ folder
    ;
}

pub fn inGameHelpCnText() []const u8 {
    return
        \\===== PlanarcadiaPS =====
        \\/help  英文帮助
        \\
        \\【基础】
        \\/info  查看玩家信息（UID/等级/货币）
        \\/sync  重新加载 freesr-data.json 并同步物品/角色
        \\/reload  等同于 /sync
        \\
        \\【编队】
        \\/lineup list  查看所有队伍预设
        \\/lineup switch <index>  切换到第 index 队（0 开始）
        \\/lineup set <index> <id1> <id2> <id3> <id4>  设置队伍预设
        \\
        \\【治疗/秘技点】
        \\/heal  回复当前队伍血量
        \\/refill  回复当前队伍秘技点
        \\
        \\【战斗/怪物】
        \\/mhp <max|number|0|off>  覆盖“敌方最大血量”（0/off 关闭；新战斗生效）
        \\
        \\【传送】
        \\/tp <entryId>
        \\/tp <planeId> <floorId> [entryId] [teleportId]
        \\/move  等同 /tp
        \\/scene get  查看当前场景
        \\/scene pos  查看当前坐标
        \\/scene <planeId> <floorId>  跨图传送
        \\
        \\【挑战/自定义】
        \\/buff <id|off|info>  挑战自定义 BUFF
        \\/id  开启挑战自定义模式；/id info 查看；/id off 关闭
        \\/node  在 PF/AS/MoC 切换节点，可以用于跳过上半
        \\提示：MoC/PF/AS 可通过 F4 菜单进入
        \\
        \\【趣味模式】
        \\/funmode on|off  开/关 funmode
        \\/funmode hp <max|number>  设置敌方血量覆盖（同 /mhp 的底层值）
        \\/funmode lineup show|clear
        \\/funmode lineup set <id1> <id2> <id3> <id4>
        \\
        \\【其他】
        \\/gender <male|female>（也支持 m/f/1/2）  设置主角性别
        \\/path <warrior|knight|shaman|memory>  设置主角命途
        \\/give  发放材料（例如信用点等；具体用法看英文 help）
        \\/level  设置开拓等级
        \\/kick  强制客户端退出登录
        \\/mail [内容...] [itemId:count ...]  发送系统邮件
        \\/finishbattle  强制结束卡住的战斗
        \\/lua <file.lua>  发送/执行 lua/ 目录下脚本
    ;
}

