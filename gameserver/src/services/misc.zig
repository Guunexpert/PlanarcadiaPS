const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const script = blk: {
    const encoded = "ICAgICAgICBsb2NhbCBmdW5jdGlvbiBzZXRUZXh0Q29tcG9uZW50KHBhdGgsIG5ld1RleHQpDQogICAgICAgICAgICBsb2NhbCBvYmogPSBDUy5Vbml0eUVuZ2luZS5HYW1lT2JqZWN0LkZpbmQocGF0aCkNCiAgICAgICAgICAgIGlmIG9iaiB0aGVuDQogICAgICAgICAgICAgICAgbG9jYWwgdGV4dENvbXBvbmVudCA9IG9iajpHZXRDb21wb25lbnRJbkNoaWxkcmVuKHR5cGVvZihDUy5SUEcuQ2xpZW50LkxvY2FsaXplZFRleHQpKQ0KICAgICAgICAgICAgICAgIGlmIHRleHRDb21wb25lbnQgdGhlbg0KICAgICAgICAgICAgICAgICAgICB0ZXh0Q29tcG9uZW50LnRleHQgPSBuZXdUZXh0DQogICAgICAgICAgICAgICAgZW5kDQogICAgICAgICAgICBlbmQNCiAgICAgICAgZW5kDQogICAgICAgIA0KICAgICAgICBzZXRUZXh0Q29tcG9uZW50KCJVSVJvb3QvQWJvdmVEaWFsb2cvQmV0YUhpbnREaWFsb2coQ2xvbmUpIiwgIjxjb2xvcj0jRTgxRTM5PkhpbWVrb+KAok5vdmFTUiBpcyBhIGZyZWUgYW5kIG9wZW4gc291cmNlIHNvZnR3YXJlLjwvY29sb3I+IikNCiAgICAgICAgc2V0VGV4dENvbXBvbmVudCgiVmVyc2lvblRleHQiLCAiPGNvbG9yPSNFODFFMzk+VmlzaXQgZGlzY29yZC5nZy9yZXZlcnNlZHJvb21zIGZvciBtb3JlIGluZm8hPC9jb2xvcj4iKQ0K";
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch unreachable;
    var decoded: [1024]u8 = undefined;
    _ = std.base64.standard.Decoder.decode(decoded[0..decoded_len], encoded) catch unreachable;
    break :blk decoded[0..decoded_len].*;
};

pub fn onPlayerHeartBeat(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerHeartBeatCsReq, allocator);
    defer req.deinit();
    const dest_buf = try allocator.dupe(u8, &script);
    const managed_str = protocol.ManagedString.move(dest_buf, allocator);

    const download_data = protocol.ClientDownloadData{
        .version = 51,
        .time = @intCast(std.time.milliTimestamp()),
        .data = managed_str,
    };
    try session.send(CmdID.CmdPlayerHeartBeatScRsp, protocol.PlayerHeartBeatScRsp{
        .retcode = 0,
        .client_time_ms = req.client_time_ms,
        .server_time_ms = @intCast(std.time.milliTimestamp()),
        .download_data = download_data,
    });
}
