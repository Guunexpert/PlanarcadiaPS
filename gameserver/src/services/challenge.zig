const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const ChallengeManager = @import("../manager/challenge_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Logic = @import("../utils/logic.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;
const challenge_tierce = &ConfigManager.global_game_config_cache.challenge_tierce_config;
const peak_group = &ConfigManager.global_game_config_cache.challenge_peak_group_config;
const peak_boss = &ConfigManager.global_game_config_cache.challenge_peak_boss_config;

pub fn onGetChallenge(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChallengeScRsp.init(allocator);
    rsp.retcode = 0;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try rsp.max_level_list.ensureTotalCapacity(challenge_config.challenge_config.items.len);
    try rsp.challenge_list.ensureTotalCapacity(challenge_config.challenge_config.items.len);

    for (challenge_config.challenge_config.items) |ids| {
        var challenge = protocol.Challenge.init(a);
        var history = protocol.ChallengeHistoryMaxLevel.init(a);

        challenge.challenge_id = ids.id;
        challenge.star = 7;
        challenge.taken_reward = 42;

        history.level = 12;
        history.reward_display_type = 101212;

        if (ids.id > 20000) {
            history.level = 4;
            history.reward_display_type = 101404;
            if (ids.id < 30000) {
                challenge.score_id = 40000;
                challenge.score_two = 40000;
            }
        }

        try rsp.max_level_list.append(history);
        try rsp.challenge_list.append(challenge);
    }

    try session.send(CmdID.CmdGetChallengeScRsp, rsp);
}
pub fn onGetChallengeGroupStatistics(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetChallengeGroupStatisticsCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetChallengeGroupStatisticsScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.group_id = req.group_id;
    try session.send(CmdID.CmdGetChallengeGroupStatisticsScRsp, rsp);
}
pub fn onLeaveChallenge(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20503, 20503001, 2050301, 1029);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    Logic.Challenge().resetChallengeState();
    try session.send(CmdID.CmdLeaveChallengeScRsp, protocol.LeaveChallengeScRsp{
        .retcode = 0,
    });
}

pub fn onLeaveChallengePeak(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20503, 20503001, 2050301, 1029);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    Logic.Challenge().resetChallengeState();
    try session.send(CmdID.CmdLeaveChallengePeakScRsp, protocol.LeaveChallengePeakScRsp{
        .retcode = 0,
    });
}

pub fn onLeaveChallengeTierce(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20503, 20503001, 2050301, 1029);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    Logic.Challenge().resetChallengeState();
    try session.send(CmdID.CmdLeaveChallengeTierceScRsp, protocol.LeaveChallengeTierceScRsp{
        .retcode = 0,
    });
}

pub fn onGetCurChallengeScRsp(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetCurChallengeScRsp.init(allocator);
    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(Logic.Challenge().GetAvatarIDs());
    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallenge(
        Logic.Challenge().GetChallengeID(),
        Logic.Challenge().GetChallengeBuffID(),
    );

    rsp.retcode = 0;
    if (Logic.Challenge().ChallengeMode()) {
        rsp.cur_challenge = cur_challenge_info;
        try rsp.lineup_list.append(lineup_info);
        Logic.Challenge().GetCurChallengeStatus();
    } else {
        LineupManager.deinitLineupInfo(&lineup_info);
        ChallengeManager.deinitCurChallenge(&cur_challenge_info);
        std.debug.print("NOT ON CHALLENGE\n", .{});
    }

    try session.send(CmdID.CmdGetCurChallengeScRsp, rsp);
}
pub fn onStartChallenge(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartChallengeCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.StartChallengeScRsp.init(allocator);
    var first_lineup = ArrayList(u32).init(allocator);
    var second_lineup = ArrayList(u32).init(allocator);
    if (Logic.CustomMode().CustomMode()) {
        Logic.Challenge().SetChallengeID(Logic.CustomMode().GetCustomChallengeID());
        Logic.Challenge().SetChallengeBuffID(Logic.CustomMode().GetCustomBuffID());
        if (Logic.CustomMode().FirstNode()) {
            for (req.avatar_lineup_first.items) |first| {
                try first_lineup.append(first.id);
            }
            try Logic.Challenge().AddAvatar(first_lineup.items);
        } else {
            for (req.avatar_lineup_second.items) |second| {
                try second_lineup.append(second.id);
            }
            try Logic.Challenge().AddAvatar(second_lineup.items);
        }
    } else {
        Logic.Challenge().SetChallengeID(req.challenge_id);
        if (Logic.CustomMode().FirstNode()) {
            for (req.avatar_lineup_first.items) |first| {
                try first_lineup.append(first.id);
            }
            try Logic.Challenge().AddAvatar(first_lineup.items);
            if (Logic.Challenge().GameModePF())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.KKNBOACNCON.?.story_info.buff_one);
            if (Logic.Challenge().GameModeAS())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.KKNBOACNCON.?.boss_info.buff_one);
        } else {
            for (req.avatar_lineup_second.items) |second| {
                try second_lineup.append(second.id);
            }
            try Logic.Challenge().AddAvatar(second_lineup.items);
            if (Logic.Challenge().GameModePF())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.KKNBOACNCON.?.story_info.buff_two);
            if (Logic.Challenge().GameModeAS())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.KKNBOACNCON.?.boss_info.buff_two);
        }
    }
    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(Logic.Challenge().GetAvatarIDs());
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallenge(
        Logic.Challenge().GetChallengeID(),
        Logic.Challenge().GetChallengeBuffID(),
    );
    _ = &cur_challenge_info;

    const ids = Logic.Challenge().GetSceneIDs();
    var scene_challenge_manager = SceneManager.ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createScene(
        Logic.Challenge().GetAvatarIDs(),
        ids[0],
        ids[1],
        ids[2],
        ids[3],
        ids[4],
        ids[5],
        ids[6],
    );
    _ = &scene_info;

    rsp.retcode = 0;
    rsp.scene = scene_info;
    rsp.cur_challenge = cur_challenge_info;
    try rsp.lineup_list.append(lineup_info);

    Logic.Challenge().SetChallenge();
    try session.send(CmdID.CmdStartChallengeScRsp, rsp);
    Logic.Challenge().GetCurSceneStatus();
    const anchor_motion = SceneManager.ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
    if (anchor_motion) |motion| {
        for (scene_info.entity_group_list.items) |*group| {
            for (group.entity_list.items) |*entity| {
                if (entity.entity) |ent| if (ent == .actor) {
                    try session.send(
                        CmdID.CmdSceneEntityMoveScNotify,
                        protocol.SceneEntityMoveScNotify{
                            .entity_id = entity.entity_id,
                            .entry_id = scene_info.entry_id,
                            .motion = motion,
                        },
                    );
                };
            }
        }
    }
}
pub fn onTakeChallengeReward(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TakeChallengeRewardCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.TakeChallengeRewardScRsp.init(allocator);
    var reward = protocol.TakenChallengeRewardInfo.init(allocator);
    if (req.group_id > 2000) reward.star_count = 12 else reward.star_count = 36;
    try rsp.taken_reward_list.append(reward);
    rsp.retcode = 0;
    rsp.group_id = req.group_id;
    try session.send(CmdID.CmdTakeChallengeRewardScRsp, rsp);
}

pub fn onGetCurChallengePeak(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetCurChallengePeakScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetCurChallengePeakScRsp, rsp);
}
pub fn onGetChallengePeakData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChallengePeakDataScRsp.init(allocator);
    rsp.retcode = 0;
    const target_king = [_]u32{ 3003, 3004, 3005 };
    var reward = ArrayList(u32).init(allocator);
    for (1..13) |i| {
        try reward.append(@intCast(i));
    }
    var ava = ArrayList(u32).init(allocator);
    try ava.appendSlice(&[_]u32{1508});

    const BossType = @TypeOf(peak_boss.challenge_peak_boss_config.items[0]);
    var boss_map = std.AutoHashMap(u32, *const BossType).init(allocator);
    defer boss_map.deinit();
    for (peak_boss.challenge_peak_boss_config.items) |*boss| {
        try boss_map.put(boss.id, boss);
    }
    for (peak_group.challenge_peak_group.items) |id| {
        if (boss_map.get(id.boss_level_id)) |boss| {
            var data = protocol.ChallengePeakGroup.init(allocator);
            const unk = ArrayList(protocol.ABCHBKBKCDF).init(allocator);
            data.peak_group_id = id.id;
            data.taken_star_rewards = reward;
            data.count_of_peaks = 3;
            data.obtained_stars = 9;
            data.peak_boss = .{
                .finished_target_list = blk: {
                    var list = std.ArrayList(u32).init(allocator);
                    try list.appendSlice(&target_king);
                    break :blk list;
                },
                .hard_mode_has_passed = true,
                .hard_mode = .{
                    .has_passed = true,
                    .best_cycle_count = 0,
                    .buff_id = boss.buff_list.items[0],
                    .peak_avatar_id_list = ava,
                    .LAMPCACOCHP = ava,
                    .EBNNJAEPBGD = unk,
                },
            };
            try rsp.challenge_peak_groups.append(data);
            rsp.current_peak_group_id = id.id;
        }
    }
    try session.send(CmdID.CmdGetChallengePeakDataScRsp, rsp);
}
pub fn onGetChallengeTierceController(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChallengeTierceControllerScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetChallengeTierceControllerScRsp, rsp);
}
pub fn onGetChallengeTierceData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChallengeTierceDataScRsp.init(allocator);
    rsp.retcode = 0;

    for (challenge_tierce.challenge_tierce.items) |info| {
        var data = protocol.ChallengeTierceData.init(allocator);
        data.challenge_id = info.id;
        data.is_passed = true;
        for (info.target_id.items) |target| {
            try data.finished_target_list.append(target);
        }
        try data.finished_target_list.append(info.tierce_target_id);
        for (0..3) |index| {
            var result = protocol.ChallengeTierceStageData.init(allocator);
            result.end_status = .BATTLE_END_WIN;
            result.stage_index = @intCast(index);
            if (info.id > 20000 and info.id < 30000) {
                result.score_id = 40000;
            } else if (info.id > 30000) {
                result.score_id = 4000;
            }
            var stage_info = protocol.ChallengeTierceStageInfo.init(allocator);
            stage_info.stage_index = @intCast(index);
            var lineup = protocol.AvatarIdentifier.init(allocator);
            lineup.id = 1508 + @as(u32, @intCast(index));
            lineup.avatar_type = .AVATAR_FORMAL_TYPE;
            try stage_info.lineup.append(lineup);
            try data.stage_info_list.append(stage_info);
            try data.result_list.append(result);
        }
        try rsp.challenge_info_list.append(data);
    }
    try session.send(CmdID.CmdGetChallengeTierceDataScRsp, rsp);
}

pub fn onReStartChallengePeak(session: *Session, _: *const Packet, _: Allocator) !void {
    try session.send(CmdID.CmdReStartChallengePeakScRsp, protocol.ReStartChallengePeakScRsp{
        .retcode = 0,
    });
}
pub fn onSetChallengePeakMobLineupAvatar(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetChallengePeakMobLineupAvatarCsReq, allocator);
    defer req.deinit();
    var update = protocol.ChallengePeakGroup.init(allocator);
    update.peak_group_id = req.peak_group_id;
    update.count_of_peaks = 3;
    update.obtained_stars = 9;
    for (req.lineup_list.items) |list| {
        var build = protocol.ChallengePeak.init(allocator);
        build.peak_id = list.peak_id;
        build.peak_avatar_id_list = list.peak_avatar_id_list;
        try Logic.Challenge().SavePeakLineup(list.peak_id, list.peak_avatar_id_list.items);
        try update.peaks.append(build);
    }
    var rsp = protocol.SetChallengePeakMobLineupAvatarScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdChallengePeakGroupDataUpdateScNotify, protocol.ChallengePeakGroupDataUpdateScNotify{
        .challenge_peak_group = update,
    });
    try session.send(CmdID.CmdSetChallengePeakMobLineupAvatarScRsp, rsp);
}
pub fn onStartChallengePeak(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartChallengePeakCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.StartChallengePeakScRsp.init(allocator);
    rsp.retcode = 0;
    if (req.peak_avatar_id_list.items.len != 0) {
        Logic.Challenge().SetPeakBoss(true);
        try Logic.Challenge().AddAvatar(req.peak_avatar_id_list.items);
    } else {
        Logic.Challenge().SetPeakBoss(false);
        try Logic.Challenge().LoadPeakLineup(req.peak_id);
    }
    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createPeakLineup(Logic.Challenge().GetAvatarIDs());
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallengePeak(req.peak_id, req.boss_buff_id);
    _ = &cur_challenge_info;

    const ids = Logic.Challenge().GetPeakSceneIDs();
    var scene_challenge_manager = SceneManager.ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createPeakScene(
        Logic.Challenge().GetAvatarIDs(),
        ids[0],
        ids[1],
        ids[2],
        ids[3],
        ids[4],
        ids[5],
    );
    _ = &scene_info;
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup_info,
        .scene = scene_info,
    });
    Logic.Challenge().SetChallenge();
    Logic.Challenge().GetCurSceneStatus();
    const anchor_motion = SceneManager.ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
    if (anchor_motion) |motion| {
        for (scene_info.entity_group_list.items) |*group| {
            for (group.entity_list.items) |*entity| {
                if (entity.entity) |ent| if (ent == .actor) {
                    try session.send(
                        CmdID.CmdSceneEntityMoveScNotify,
                        protocol.SceneEntityMoveScNotify{
                            .entity_id = entity.entity_id,
                            .entry_id = scene_info.entry_id,
                            .motion = motion,
                        },
                    );
                };
            }
        }
    }
    try session.send(CmdID.CmdStartChallengePeakScRsp, rsp);
}
pub fn onSetChallengePeakBossHardMode(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetChallengePeakBossHardModeCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.SetChallengePeakBossHardModeScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.is_hard_mode = req.is_hard_mode;
    rsp.peak_group_id = req.peak_group_id;
    Logic.Challenge().SetChallengePeakHard(req.is_hard_mode);
    try session.send(CmdID.CmdSetChallengePeakBossHardModeScRsp, rsp);
}
pub fn onGetFriendBattleRecordDetail(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFriendBattleRecordDetailCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetFriendBattleRecordDetailScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.uid = req.uid;
    var record_list = ArrayList(protocol.ChallengeAvatarInfo).init(allocator);
    try record_list.appendSlice(&[_]protocol.ChallengeAvatarInfo{
        .{ .level = 80, .index = 0, .id = 1508, .avatar_type = protocol.AvatarType.AVATAR_UPGRADE_AVAILABLE_TYPE },
    });

    const BossType = @TypeOf(peak_boss.challenge_peak_boss_config.items[0]);
    var boss_map = std.AutoHashMap(u32, *const BossType).init(allocator);
    defer boss_map.deinit();
    for (peak_boss.challenge_peak_boss_config.items) |*boss| {
        try boss_map.put(boss.id, boss);
    }

    for (peak_group.challenge_peak_group.items) |group| {
        if (boss_map.get(group.boss_level_id)) |boss| {
            var peak_record = protocol.DBFHOCOBPMK.init(allocator);
            peak_record.group_id = group.id;
            peak_record.CDFFIGJLGMM = .{
                .buff_id = boss.buff_list.items[0],
                .peak_id = group.boss_level_id,
                .HAMDKIHGKGO = true,
                .CFLDOMPACKI = true,
                .MCJNLLBBDHN = std.ArrayList(u32).init(allocator),
                .lineup = .{ .avatar_list = record_list },
            };
            try rsp.LGIBJLFBFCG.append(peak_record);
        }
    }
    try session.send(CmdID.CmdGetFriendBattleRecordDetailScRsp, rsp);
}
//CHALLENGE TIERCE WIP
pub fn onStartChallengeTierce(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartChallengeTierceCsReq, allocator);
    defer req.deinit();
    std.log.debug("REQ CHALLENGE ID: {}, IS SINGLE STAGE: {}, STAGE INDEX: {}", .{ req.challenge_id, req.is_single_stage, req.stage_index });

    Logic.Challenge().SetChallengeID(req.challenge_id);

    if (req.is_single_stage == false) {
        try Logic.Challenge().SaveStageInfoList(req.challenge_id, req.stage_info_list);
    }

    try Logic.Challenge().LoadStageInfo(req.challenge_id, req.stage_index);

    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(Logic.Challenge().GetAvatarIDs());
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallengeTierce(
        Logic.Challenge().GetChallengeID(),
        req.is_single_stage,
        req.stage_index,
        Logic.Challenge().GetChallengeBuffID(),
        lineup_info,
    );
    _ = &cur_challenge_info;

    const ids = Logic.Challenge().GetSceneIDs();
    var scene_challenge_manager = SceneManager.ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createScene(
        Logic.Challenge().GetAvatarIDs(),
        ids[0],
        ids[1],
        ids[2],
        ids[3],
        ids[4],
        ids[5],
        ids[6],
    );
    _ = &scene_info;

    var rsp = protocol.StartChallengeTierceScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.scene = scene_info;
    rsp.challenge_tierce_info = cur_challenge_info;
    Logic.Challenge().SetChallenge();
    const anchor_motion = SceneManager.ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
    if (anchor_motion) |motion| {
        for (scene_info.entity_group_list.items) |*group| {
            for (group.entity_list.items) |*entity| {
                if (entity.entity) |ent| if (ent == .actor) {
                    try session.send(
                        CmdID.CmdSceneEntityMoveScNotify,
                        protocol.SceneEntityMoveScNotify{
                            .entity_id = entity.entity_id,
                            .entry_id = scene_info.entry_id,
                            .motion = motion,
                        },
                    );
                };
            }
        }
    }
    try session.send(CmdID.CmdStartChallengeTierceScRsp, rsp);
}

pub fn onSetChallengeTierceLineup(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetChallengeTierceLineupCsReq, allocator);
    defer req.deinit();
    try Logic.Challenge().SaveStageInfoList(req.challenge_id, req.stage_info_list);
    try session.send(CmdID.CmdSetChallengeTierceLineupScRsp, protocol.SetChallengeTierceLineupScRsp{
        .retcode = 0,
    });
}
