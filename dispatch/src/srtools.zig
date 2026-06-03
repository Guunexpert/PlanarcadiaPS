const std = @import("std");
const httpz = @import("httpz");

const freesrFile = "freesr-data.json";
const okMessage = "OK";
const invalidJsonMessage = "invalid JSON payload";
const emptyBodyMessage = "empty request body";
const invalidDataMessage = "srtools data must be an object";

fn addCorsHeaders(res: *httpz.Response) void {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.header("Access-Control-Allow-Headers", "content-type, authorization");
    res.header("Access-Control-Max-Age", "86400");
}

pub fn onSrtoolsOptions(_: *httpz.Request, res: *httpz.Response) !void {
    addCorsHeaders(res);
    res.status = 204;
    res.body = "";
}

pub fn onSrtoolsSave(req: *httpz.Request, res: *httpz.Response) !void {
    const allocator = res.arena;
    var status: u16 = 200;
    var message: []const u8 = okMessage;

    addCorsHeaders(res);

    const payload = req.jsonValue() catch |err| blk: {
        status = 400;
        message = invalidJsonMessage;
        std.log.err("srtools payload parsing failed: {any}", .{err});
        break :blk null;
    };

    if (payload == null) {
        status = 400;
        message = emptyBodyMessage;
    } else {
        const root_value = payload.?;
        if (root_value != .object) {
            status = 400;
            message = invalidDataMessage;
        } else {
            const obj = root_value.object;
            const data_value = obj.get("data") orelse root_value;
            if (data_value == .object) {
                const written = try saveFreesrData(allocator, data_value);
                std.log.info("srtools saved freesr-data ({d} bytes)", .{written});
            } else {
                status = 400;
                message = invalidDataMessage;
                std.log.warn("srtools payload has invalid data type", .{});
            }
        }
    }

    res.status = status;
    try res.json(.{
        .status = status,
        .message = message,
    }, .{});
}

fn saveFreesrData(allocator: std.mem.Allocator, value: std.json.Value) !usize {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try std.json.stringify(value, .{}, buffer.writer());

    const file = try std.fs.cwd().createFile(freesrFile, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buffer.items);

    return buffer.items.len;
}
