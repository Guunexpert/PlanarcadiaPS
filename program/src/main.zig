const std = @import("std");
const builtin = @import("builtin");

const color = struct {
    const blue = "\x1b[36m"; // cyan / sky blue
    const pink = "\x1b[95;1m"; // bright magenta / hot pink
    const reset = "\x1b[0m";
};

const prompt_prefix = color.pink ++ "<PlanarcadiaPS>" ++ color.reset ++ " ";

const dispatch_main = @import("dispatch_main");
const gameserver_main = @import("gameserver_main");
const terminal_commands = @import("terminal_commands");

extern "kernel32" fn SetCurrentDirectoryW(lpPathName: [*:0]const std.os.windows.WCHAR) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

fn changeCwd(allocator: std.mem.Allocator, dir: []const u8) void {
    switch (builtin.os.tag) {
        .windows => {
            const wdir = std.unicode.utf8ToUtf16LeAllocZ(allocator, dir) catch return;
            defer allocator.free(wdir);
            _ = SetCurrentDirectoryW(wdir.ptr);
        },
        else => {
            std.posix.chdir(dir) catch return;
        },
    }
}

fn fileExists(allocator: std.mem.Allocator, dir: []const u8, name: []const u8) bool {
    _ = allocator;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const sep = std.fs.path.sep;
    const needs_sep = dir.len > 0 and dir[dir.len - 1] != sep;
    const path = if (needs_sep)
        (std.fmt.bufPrint(&buf, "{s}{c}{s}", .{ dir, sep, name }) catch return false)
    else
        (std.fmt.bufPrint(&buf, "{s}{s}", .{ dir, name }) catch return false);
    if (std.fs.path.isAbsolute(path)) {
        std.fs.accessAbsolute(path, .{}) catch return false;
    } else {
        std.fs.cwd().access(path, .{}) catch return false;
    }
    return true;
}

fn pickWorkingDir(allocator: std.mem.Allocator, exe_dir: []const u8) struct { dir: []const u8, ok: bool } {
    const parent = std.fs.path.dirname(exe_dir) orelse exe_dir;
    const grand = std.fs.path.dirname(parent) orelse parent;
    const cwd_path = std.fs.cwd().realpathAlloc(allocator, ".") catch exe_dir;

    const candidates = [_][]const u8{ cwd_path, grand, parent, exe_dir };

    for (candidates) |c| {
        const has_freesr = fileExists(allocator, c, "freesr-data.json");
        const has_resources = fileExists(allocator, c, "resources");
        const has_protocol = fileExists(allocator, c, "protocol");
        if (has_freesr and has_resources and has_protocol) return .{ .dir = c, .ok = true };
    }
    return .{ .dir = exe_dir, .ok = false };
}

fn enableUtf8ConsoleOnWindows() void {
    if (builtin.os.tag != .windows) return;
    _ = SetConsoleOutputCP(65001);
    _ = SetConsoleCP(65001);
}

pub fn enableVT100Terminal() void {
    if (builtin.os.tag != .windows)
        return;
    const stdOutHandle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch return;

    var mode: std.os.windows.DWORD = 0;
    const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
    _ = std.os.windows.kernel32.GetConsoleMode(stdOutHandle, &mode);
    _ = std.os.windows.kernel32.SetConsoleMode(stdOutHandle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

    const stdErrHandle = std.os.windows.GetStdHandle(std.os.windows.STD_ERROR_HANDLE) catch return;
    _ = std.os.windows.kernel32.GetConsoleMode(stdErrHandle, &mode);
    _ = std.os.windows.kernel32.SetConsoleMode(stdErrHandle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
}

fn runDispatch() void {
    if (dispatch_main.main()) |_| {
        std.log.info("{s}[Dispatch]{s} stopped gracefully", .{ color.blue, color.reset });
    } else |err| {
        std.log.err("{s}[Dispatch]{s} exited with error: {s}", .{ color.blue, color.reset, @errorName(err) });
    }
}

fn runGameserver() void {
    if (gameserver_main.main()) |_| {
        std.log.info("{s}[GameServer]{s} stopped gracefully", .{ color.blue, color.reset });
    } else |err| {
        std.log.err("{s}[GameServer]{s} exited with error: {s}", .{ color.blue, color.reset, @errorName(err) });
    }
}

var io_mutex: std.Thread.Mutex = .{};

fn pumpConsoleOutputs() void {
    var stdout = std.io.getStdOut().writer();
    var buf: [terminal_commands.MaxOutputLineLen]u8 = undefined;
    while (true) {
        const line = terminal_commands.tryDequeueConsoleOutput(&buf) orelse {
            std.time.sleep(50 * std.time.ns_per_ms);
            continue;
        };

        io_mutex.lock();
        defer io_mutex.unlock();

        // Print output and re-show prompt.
        _ = stdout.write("\n") catch {};
        _ = stdout.write(line) catch {};
        if (line.len == 0 or line[line.len - 1] != '\n') {
            _ = stdout.write("\n") catch {};
        }
        _ = stdout.write(prompt_prefix) catch {};
    }
}

fn computeHwId(allocator: std.mem.Allocator) ![]u8 {
    var hasher = std.crypto.hash.Blake3.init(.{});

    const host_env = std.process.getEnvVarOwned(allocator, "COMPUTERNAME") catch null;
    if (host_env) |h| {
        defer allocator.free(h);
        hasher.update(h);
    }

    const self_path = std.fs.selfExePathAlloc(allocator) catch null;
    if (self_path) |p| {
        defer allocator.free(p);
        hasher.update(p);
    }

    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return try std.fmt.allocPrint(allocator, "{s}", .{std.fmt.fmtSliceHexLower(digest[0..16])});
}

fn collectIpStrings(allocator: std.mem.Allocator) ![]const []const u8 {
    _ = allocator;
    return &[_][]const u8{};
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    enableUtf8ConsoleOnWindows();
    enableVT100Terminal();

    var workdir: []const u8 = ".";
    var exe_dir: []const u8 = ".";
    var has_full_paths = false;
    if (std.fs.selfExePathAlloc(allocator)) |self_path| {
        if (std.fs.path.dirname(self_path)) |exe_dir_path| {
            exe_dir = exe_dir_path;
            const pick = pickWorkingDir(allocator, exe_dir_path);
            workdir = pick.dir;
            has_full_paths = pick.ok;
            changeCwd(allocator, workdir);
        }
    } else |_| {}

    if (!has_full_paths) {
        std.log.warn("[Program] could not find complete freesr-data/resources/protocol; continuing with cwd '{s}'", .{workdir});
        std.log.warn("[Program] ensure freesr-data.json, resources/, protocol/ are present in cwd or parent directories", .{});
    }

    // Pink notices at the very start.
    std.debug.print("{s}PlanarcadiaPS by gugun , reimplementation game server from EvanesciaSR{s}\n", .{ color.blue, color.reset });
    std.debug.print("{s}Welcome to PlanarcadiaPS!{s}\n", .{ color.blue, color.reset });
    std.debug.print("{s}Enjoy the game!{s}\n", .{ color.blue, color.reset });

    // Device info: HWID and IP addresses.
    const hwid_opt: ?[]u8 = computeHwId(allocator) catch |err| blk: {
        std.log.err("Failed to compute HWID: {s}", .{@errorName(err)});
        break :blk null;
    };
    defer if (hwid_opt) |v| allocator.free(v);
    const hwid = hwid_opt orelse "unknown";

    const ip_list_opt: ?[]const []const u8 = collectIpStrings(allocator) catch |err| blk: {
        std.log.err("Failed to collect IP addresses: {s}", .{@errorName(err)});
        break :blk null;
    };
    defer if (ip_list_opt) |list| {
        for (list) |item| allocator.free(item);
        allocator.free(list);
    };
    const ip_list = ip_list_opt orelse &[_][]const u8{"unknown"};

    std.log.info("Device HWID: {s}", .{hwid});
    for (ip_list) |ip| {
        std.log.info("Detected IP: {s}", .{ip});
    }

    std.log.info("Starting embedded servers (dispatch + gameserver)...", .{});

    const dispatch_thread = try std.Thread.spawn(.{}, runDispatch, .{});
    const gameserver_thread = try std.Thread.spawn(.{}, runGameserver, .{});
    const output_thread = try std.Thread.spawn(.{}, pumpConsoleOutputs, .{});

    dispatch_thread.detach();
    gameserver_thread.detach();
    output_thread.detach();

    // REPL loop: allow user to type commands without being disrupted by logs.
    io_mutex.lock();
    try stdout.print("{s}", .{prompt_prefix});
    io_mutex.unlock();
    while (true) {
        var buf: [256]u8 = undefined;
        const line = stdin.readUntilDelimiterOrEof(&buf, '\n') catch |err| {
            std.log.err("Input error: {s}", .{@errorName(err)});
            break;
        };
        if (line == null) break;
        const trimmed = std.mem.trim(u8, line.?, " \r\n");
        if (trimmed.len == 0) {
            io_mutex.lock();
            try stdout.print("{s}", .{prompt_prefix});
            io_mutex.unlock();
            continue;
        }
        if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) break;
        if (std.mem.eql(u8, trimmed, "help") or std.mem.eql(u8, trimmed, "?")) {
            io_mutex.lock();
            try stdout.print("{s}\n", .{terminal_commands.helpText()});
            try stdout.print("{s}", .{prompt_prefix});
            io_mutex.unlock();
            continue;
        }
        if (std.mem.eql(u8, trimmed, "finishbattle") or std.mem.eql(u8, trimmed, "/finishbattle")) {
            terminal_commands.requestFinishBattle();
        }

        // Forward to UID=1 command executor (gameserver reads from queue on heartbeats).
        const cmd_name = terminal_commands.extractCommandName(trimmed);

        // For help commands, show output directly in terminal (same as in-game sendMessage output).
        if (std.mem.eql(u8, cmd_name, "help")) {
            io_mutex.lock();
            try stdout.print("{s}\n{s}", .{ terminal_commands.inGameHelpEnText(), prompt_prefix });
            io_mutex.unlock();
            continue;
        }
        if (std.mem.eql(u8, cmd_name, "help_cn")) {
            io_mutex.lock();
            try stdout.print("{s}\n{s}", .{ terminal_commands.inGameHelpCnText(), prompt_prefix });
            io_mutex.unlock();
            continue;
        }

        if (!terminal_commands.isKnownCommand(cmd_name)) {
            var msg_buf: [512]u8 = undefined;
            if (terminal_commands.buildSuggestionText(cmd_name, &msg_buf)) |msg| {
                io_mutex.lock();
                try stdout.print("{s}{s}", .{ prompt_prefix, msg });
                io_mutex.unlock();
            } else {
                io_mutex.lock();
                try stdout.print("{s}Unknown command. Type 'help'.\n", .{prompt_prefix});
                io_mutex.unlock();
            }
            io_mutex.lock();
            try stdout.print("{s}", .{prompt_prefix});
            io_mutex.unlock();
            continue;
        }

        var normalized: [terminal_commands.MaxCommandLen + 1]u8 = undefined;
        const res = terminal_commands.enqueueNormalized(trimmed, &normalized) catch |err| {
            switch (err) {
                error.QueueFull => {
                    io_mutex.lock();
                    try stdout.print("{s} command queue is full.\n", .{prompt_prefix});
                    io_mutex.unlock();
                },
                error.TooLong => {
                    io_mutex.lock();
                    try stdout.print("{s} command is too long (max {d}).\n", .{ prompt_prefix, terminal_commands.MaxCommandLen });
                    io_mutex.unlock();
                },
            }
            io_mutex.lock();
            try stdout.print("{s}", .{prompt_prefix});
            io_mutex.unlock();
            continue;
        };
        _ = res;

        io_mutex.lock();
        try stdout.print("{s} queued for UID=1: {s}\n", .{ prompt_prefix, if (trimmed[0] == '/') trimmed else normalized[0 .. 1 + trimmed.len] });
        try stdout.print("{s}", .{prompt_prefix});
        io_mutex.unlock();
    }
}
