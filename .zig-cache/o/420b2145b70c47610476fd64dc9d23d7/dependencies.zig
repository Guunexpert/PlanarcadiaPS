pub const packages = struct {
    pub const @"12201a2aeb55d0c4a112c5a1806e4d90d734e0e4c21301d4b289f734c3412a883312" = struct {
        pub const build_root = "C:\\Users\\Gugun\\AppData\\Local\\zig\\p\\tls-0.1.0-ER2e0sR3BQAaKutV0MShEsWhgG5NkNc04OTCEwHUson3";
        pub const build_zig = @import("12201a2aeb55d0c4a112c5a1806e4d90d734e0e4c21301d4b289f734c3412a883312");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"122052e8e9e4233621ebeba2215df92dbb78387be6193bdc24da3f44532ddeeb25ab" = struct {
        pub const build_root = "C:\\Users\\Gugun\\AppData\\Local\\zig\\p\\protobuf-2.0.0-0e82asubGwBS6OnkIzYh6-uiIV35Lbt4OHvmGTvcJNo_";
        pub const build_zig = @import("122052e8e9e4233621ebeba2215df92dbb78387be6193bdc24da3f44532ddeeb25ab");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"1220cf9b8944def0907a43f208a004d9322c6f1972f86792d7f82527965020eb5fba" = struct {
        pub const build_root = "C:\\Users\\Gugun\\AppData\\Local\\zig\\p\\httpz-0.0.0-PNVzrAvCBgDPm4lE3vCQekPyCKAE2TIsbxly-GeS1_gl";
        pub const build_zig = @import("1220cf9b8944def0907a43f208a004d9322c6f1972f86792d7f82527965020eb5fba");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "metrics", "N-V-__8AAHOzAQBh8wB371GN1DXTl1mKs8Rdqj0sJea0U4P7" },
            .{ "websocket", "websocket-0.1.0-ZPISdXNIAwCXG7oHBj4zc1CfmZcDeyR6hfTEOo8_YI4r" },
        };
    };
    pub const @"N-V-__8AAHOzAQBh8wB371GN1DXTl1mKs8Rdqj0sJea0U4P7" = struct {
        pub const build_root = "C:\\Users\\Gugun\\AppData\\Local\\zig\\p\\N-V-__8AAHOzAQBh8wB371GN1DXTl1mKs8Rdqj0sJea0U4P7";
        pub const build_zig = @import("N-V-__8AAHOzAQBh8wB371GN1DXTl1mKs8Rdqj0sJea0U4P7");
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const dispatch = struct {
        pub const build_root = "H:\\GAME\\Project\\hsr\\pearl-sr\\dispatch";
        pub const build_zig = @import("dispatch");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "httpz", "1220cf9b8944def0907a43f208a004d9322c6f1972f86792d7f82527965020eb5fba" },
            .{ "protocol", "protocol" },
            .{ "tls", "12201a2aeb55d0c4a112c5a1806e4d90d734e0e4c21301d4b289f734c3412a883312" },
        };
    };
    pub const gameserver = struct {
        pub const build_root = "H:\\GAME\\Project\\hsr\\pearl-sr\\gameserver";
        pub const build_zig = @import("gameserver");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "protocol", "protocol" },
        };
    };
    pub const protocol = struct {
        pub const build_root = "H:\\GAME\\Project\\hsr\\pearl-sr\\protocol";
        pub const build_zig = @import("protocol");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "protobuf", "122052e8e9e4233621ebeba2215df92dbb78387be6193bdc24da3f44532ddeeb25ab" },
        };
    };
    pub const @"websocket-0.1.0-ZPISdXNIAwCXG7oHBj4zc1CfmZcDeyR6hfTEOo8_YI4r" = struct {
        pub const build_root = "C:\\Users\\Gugun\\AppData\\Local\\zig\\p\\websocket-0.1.0-ZPISdXNIAwCXG7oHBj4zc1CfmZcDeyR6hfTEOo8_YI4r";
        pub const build_zig = @import("websocket-0.1.0-ZPISdXNIAwCXG7oHBj4zc1CfmZcDeyR6hfTEOo8_YI4r");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "dispatch", "dispatch" },
    .{ "gameserver", "gameserver" },
    .{ "protocol", "protocol" },
    .{ "protobuf", "122052e8e9e4233621ebeba2215df92dbb78387be6193bdc24da3f44532ddeeb25ab" },
};
