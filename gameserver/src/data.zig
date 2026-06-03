const std = @import("std");
const ConfigManager = @import("./manager/config_mgr.zig");

// Avatar group
pub var EnhanceAvatarID = [_]u32{ 1005, 1006, 1205, 1212, 1306, 1307, 1306, 1102, 1217, 1310, 1004 };

pub var AllAvatars: []const u32 = &.{};

pub var AvatarSkinMap = [_]struct {
    avatar_id: u32,
    skin_id: u32,
}{
    .{ .avatar_id = 1001, .skin_id = 1100101 },
    .{ .avatar_id = 1303, .skin_id = 1130301 },
    .{ .avatar_id = 1310, .skin_id = 1131001 },
    .{ .avatar_id = 1415, .skin_id = 1141501 },
    .{ .avatar_id = 1407, .skin_id = 1140701 },
};

// Battle group
pub const IgnoreBattle = [_]u32{ 1509, 1504, 1501, 1414, 1405, 1404, 1225, 1321, 1314, 1312, 1305, 1302, 1217, 1108 };
pub const SkipBattle = [_]u32{ 1506, 1408, 1308, 1510 };

//TODO: update id for characters have ignore toughness in their technique in future
pub const IgnoreToughness = [_]u32{ 1006, 1308, 1317 };

// Profile group
pub const OwnedChatBubbles = [_]u32{ 220000, 220001, 220002, 220003, 220004, 220005, 220006, 220007, 220008, 220009, 220010 };
pub const OwnedPhoneThemes = [_]u32{ 221000, 221001, 221002, 221003, 221004, 221005, 221006, 221007, 221008, 221009, 221010, 221011, 221012, 221013 };
pub const OwnedPhoneCases = [_]u32{ 254000, 254001 };
pub const OwnedPersonalCardSkin = [_]u32{ 253000, 253001, 253002, 253003, 253004 };

pub const ItemList = [_]u32{ 251001, 251002, 251003, 251004, 101, 238, 239 };
pub const SkinList = [_]u32{ 1130301, 1100101, 1131001, 1141501, 1140701 };
pub const PlayerOutfitList = [_]u32{ 229001, 227013, 227012, 227010, 227009, 227008, 227007, 227006, 227005, 227003, 227002, 227001 };

pub const LightconeList_3 = [_]u32{
    20000, 20001, 20002, 20003, 20004, 20005, 20006, 20007, 20008, 20009, 20010, 20011, 20012, 20013, 20014, 20015, 20016, 20017, 20018, 20019, 20020, 20021, 20022,
};
pub const LightconeList_4 = [_]u32{
    21000, 21001, 21002, 21003, 21004, 21005, 21006, 21007, 21008, 21009, 21010, 21011, 21012, 21013, 21014, 21015, 21016, 21017, 21018, 21019, 21020, 21021, 21022,
    21023, 21024, 21025, 21026, 21027, 21028, 21029, 21030, 21031, 21032, 21033, 21034, 21035, 21036, 21037, 21038, 21039, 21040, 21041, 21042, 21043, 21044, 21045,
    21046, 21047, 21048, 21050, 21051, 21052, 22000, 22001, 22002, 22003, 22004,
};
pub var AvatarList: []const u32 = &.{};
