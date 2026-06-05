const std = @import("std");
const protocol = @import("protocol");
const Session = @import("Session.zig");
const Packet = @import("Packet.zig");
const avatar = @import("services/avatar.zig");
const chat = @import("services/chat.zig");
const gacha = @import("services/gacha.zig");
const item = @import("services/item.zig");
const battle = @import("services/battle.zig");
const login = @import("services/login.zig");
const lineup = @import("services/lineup.zig");
const mail = @import("services/mail.zig");
const misc = @import("services/misc.zig");
const mission = @import("services/mission.zig");
const pet = @import("services/pet.zig");
const profile = @import("services/profile.zig");
const scene = @import("services/scene.zig");
const events = @import("services/events.zig");
const challenge = @import("services/challenge.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const CmdID = protocol.CmdID;

const log = std.log.scoped(.handlers);

const Action = *const fn (*Session, *const Packet, Allocator) anyerror!void;
pub const HandlerList = [_]struct { CmdID, Action }{
    .{ CmdID.CmdPlayerGetTokenCsReq, login.onPlayerGetToken },
    .{ CmdID.CmdPlayerLoginCsReq, login.onPlayerLogin },
    .{ CmdID.CmdPlayerHeartBeatCsReq, misc.onPlayerHeartBeat },
    .{ CmdID.CmdPlayerLoginFinishCsReq, login.onPlayerLoginFinish },
    .{ CmdID.CmdContentPackageGetDataCsReq, login.onContentPackageGetData },
    .{ CmdID.CmdSetClientPausedCsReq, login.onSetClientPaused },
    .{ CmdID.CmdGetArchiveDataCsReq, login.onGetArchiveData },
    .{ CmdID.CmdGetUpdatedArchiveDataCsReq, login.onGetUpdatedArchiveData },
    //avatar
    .{ CmdID.CmdGetAvatarDataCsReq, avatar.onGetAvatarData },
    .{ CmdID.CmdSetAvatarPathCsReq, avatar.onSetAvatarPath },
    .{ CmdID.CmdGetBasicInfoCsReq, avatar.onGetBasicInfo },
    .{ CmdID.CmdTakeOffAvatarSkinCsReq, avatar.onTakeOffAvatarSkin },
    .{ CmdID.CmdDressAvatarSkinCsReq, avatar.onDressAvatarSkin },
    .{ CmdID.CmdGetBigDataAllRecommendCsReq, avatar.onGetBigDataAll },
    .{ CmdID.CmdGetBigDataRecommendCsReq, avatar.onGetBigData },
    .{ CmdID.CmdGetPreAvatarGrowthInfoCsReq, avatar.onGetPreAvatarGrowthInfo },
    .{ CmdID.CmdSetPlayerOutfitCsReq, avatar.onSetPlayerOutfit },
    .{ CmdID.CmdSetAvatarEnhancedIdCsReq, avatar.onSetAvatarEnhancedId },
    //bag
    .{ CmdID.CmdGetBagCsReq, item.onGetBag },
    .{ CmdID.CmdUseItemCsReq, item.onUseItem },
    //lineup
    .{ CmdID.CmdChangeLineupLeaderCsReq, lineup.onChangeLineupLeader },
    .{ CmdID.CmdReplaceLineupCsReq, lineup.onReplaceLineup },
    .{ CmdID.CmdGetCurLineupDataCsReq, lineup.onGetCurLineupData },
    //battle
    .{ CmdID.CmdStartCocoonStageCsReq, battle.onStartCocoonStage },
    .{ CmdID.CmdPVEBattleResultCsReq, battle.onPVEBattleResult },
    .{ CmdID.CmdSceneCastSkillCsReq, battle.onSceneCastSkill },
    .{ CmdID.CmdSceneCastSkillCostMpCsReq, battle.onSceneCastSkillCostMp },
    .{ CmdID.CmdQuickStartCocoonStageCsReq, battle.onQuickStartCocoonStage },
    .{ CmdID.CmdQuickStartFarmElementCsReq, battle.onQuickStartFarmElement },
    .{ CmdID.CmdStartBattleCollegeCsReq, battle.onStartBattleCollege },
    .{ CmdID.CmdGetCurBattleInfoCsReq, battle.onGetCurBattleInfo },
    .{ CmdID.CmdSyncClientResVersionCsReq, battle.onSyncClientResVersion },
    //gacha
    .{ CmdID.CmdGetGachaInfoCsReq, gacha.onGetGachaInfo },
    .{ CmdID.CmdBuyGoodsCsReq, gacha.onBuyGoods },
    .{ CmdID.CmdExchangeHcoinCsReq, gacha.onExchangeHcoin },
    .{ CmdID.CmdDoGachaCsReq, gacha.onDoGacha },
    //mail
    .{ CmdID.CmdGetMailCsReq, mail.onGetMail },
    .{ CmdID.CmdTakeMailAttachmentCsReq, mail.onTakeMailAttachment },
    //pet
    .{ CmdID.CmdGetPetDataCsReq, pet.onGetPetData },
    .{ CmdID.CmdRecallPetCsReq, pet.onRecallPet },
    .{ CmdID.CmdSummonPetCsReq, pet.onSummonPet },
    //profile
    .{ CmdID.CmdGetPhoneDataCsReq, profile.onGetPhoneData },
    .{ CmdID.CmdSelectPhoneThemeCsReq, profile.onSelectPhoneTheme },
    .{ CmdID.CmdSelectChatBubbleCsReq, profile.onSelectChatBubble },
    .{ CmdID.CmdGetPlayerBoardDataCsReq, profile.onGetPlayerBoardData },
    .{ CmdID.CmdSetDisplayAvatarCsReq, profile.onSetDisplayAvatar },
    .{ CmdID.CmdSetAssistAvatarCsReq, profile.onSetAssistAvatar },
    .{ CmdID.CmdSetSignatureCsReq, profile.onSetSignature },
    .{ CmdID.CmdSetGameplayBirthdayCsReq, profile.onSetGameplayBirthday },
    .{ CmdID.CmdSetHeadIconCsReq, profile.onSetHeadIcon },
    .{ CmdID.CmdSelectPhoneCaseCsReq, profile.onSelectPhoneCase },
    .{ CmdID.CmdUpdatePlayerSettingCsReq, profile.onUpdatePlayerSetting },
    .{ CmdID.CmdGetPlayerDetailInfoCsReq, profile.onGetPlayerDetailInfo },
    .{ CmdID.CmdSetPersonalCardCsReq, profile.onSetPersonalCard },
    //mission
    .{ CmdID.CmdGetTutorialGuideCsReq, mission.onGetTutorialGuideStatus },
    .{ CmdID.CmdGetMissionStatusCsReq, mission.onGetMissionStatus },
    .{ CmdID.CmdGetTutorialCsReq, mission.onGetTutorialStatus },
    .{ CmdID.CmdUnlockTutorialGuideCsReq, mission.onUnlockTutorialGuide },
    .{ CmdID.CmdUnlockTutorialCsReq, mission.onUnlockTutorial },
    .{ CmdID.CmdFinishTalkMissionCsReq, mission.onFinishTalkMission },
    .{ CmdID.CmdGetQuestDataCsReq, mission.onGetQuestData },
    //chat
    .{ CmdID.CmdGetFriendListInfoCsReq, chat.onGetFriendListInfo },
    .{ CmdID.CmdGetPrivateChatHistoryCsReq, chat.onPrivateChatHistory },
    .{ CmdID.CmdGetChatEmojiListCsReq, chat.onChatEmojiList },
    .{ CmdID.CmdSendMsgCsReq, chat.onSendMsg },
    .{ CmdID.CmdTriggerAiPamSpeakCsReq, chat.onTriggerAiPamSpeak },
    .{ CmdID.CmdGetAiPamChatHistoryCsReq, chat.onGetAiPamChatHistory },
    //scene
    .{ CmdID.CmdGetCurSceneInfoCsReq, scene.onGetCurSceneInfo },
    .{ CmdID.CmdSceneEntityMoveCsReq, scene.onSceneEntityMove },
    .{ CmdID.CmdEnterSceneCsReq, scene.onEnterScene },
    .{ CmdID.CmdGetSceneMapInfoCsReq, scene.onGetSceneMapInfo },
    .{ CmdID.CmdGetUnlockTeleportCsReq, scene.onGetUnlockTeleport },
    .{ CmdID.CmdEnterSectionCsReq, scene.onEnterSection },
    .{ CmdID.CmdSceneEntityTeleportCsReq, scene.onSceneEntityTeleport },
    .{ CmdID.CmdGetFirstTalkNpcCsReq, scene.onGetFirstTalkNpc },
    .{ CmdID.CmdGetFirstTalkByPerformanceNpcCsReq, scene.onGetFirstTalkByPerformanceNp },
    .{ CmdID.CmdGetNpcTakenRewardCsReq, scene.onGetNpcTakenReward },
    .{ CmdID.CmdUpdateGroupPropertyCsReq, scene.onUpdateGroupProperty },
    .{ CmdID.CmdChangePropTimelineInfoCsReq, scene.onChangePropTimeline },
    .{ CmdID.CmdDeactivateFarmElementCsReq, scene.onDeactivateFarmElement },
    .{ CmdID.CmdGetEnteredSceneCsReq, scene.onGetEnteredScene },
    .{ CmdID.CmdInteractPropCsReq, scene.onInteractProp },
    .{ CmdID.CmdChangeEraFlipperDataCsReq, scene.onChangeEraFlipperData },
    .{ CmdID.CmdSetTrainWorldIdCsReq, scene.onSetTrainWorldId },
    //events
    //.{ CmdID.CmdGetActivityScheduleConfigCsReq, events.onGetActivity },
    //.{ CmdID.CmdUpdateServerPrefsDataCsReq, events.onUpdateServerPrefsData },
    //challenge
    .{ CmdID.CmdGetChallengeCsReq, challenge.onGetChallenge },
    .{ CmdID.CmdGetChallengeGroupStatisticsCsReq, challenge.onGetChallengeGroupStatistics },
    .{ CmdID.CmdStartChallengeCsReq, challenge.onStartChallenge },
    .{ CmdID.CmdLeaveChallengeCsReq, challenge.onLeaveChallenge },
    .{ CmdID.CmdLeaveChallengePeakCsReq, challenge.onLeaveChallengePeak },
    .{ CmdID.CmdGetCurChallengeCsReq, challenge.onGetCurChallengeScRsp },
    .{ CmdID.CmdGetChallengePeakDataCsReq, challenge.onGetChallengePeakData },
    .{ CmdID.CmdGetCurChallengePeakCsReq, challenge.onGetCurChallengePeak },
    .{ CmdID.CmdTakeChallengeRewardCsReq, challenge.onTakeChallengeReward },
    .{ CmdID.CmdStartChallengePeakCsReq, challenge.onStartChallengePeak },
    .{ CmdID.CmdReStartChallengePeakCsReq, challenge.onReStartChallengePeak },
    .{ CmdID.CmdSetChallengePeakMobLineupAvatarCsReq, challenge.onSetChallengePeakMobLineupAvatar },
    .{ CmdID.CmdSetChallengePeakBossHardModeCsReq, challenge.onSetChallengePeakBossHardMode },
    .{ CmdID.CmdGetFriendBattleRecordDetailCsReq, challenge.onGetFriendBattleRecordDetail },
};

const SuppressLogList = [_]CmdID{CmdID.CmdSceneEntityMoveCsReq};

pub fn handle(session: *Session, packet: *const Packet) !void {
    var arena = ArenaAllocator.init(session.allocator);
    defer arena.deinit();

    const cmd_id: CmdID = @enumFromInt(packet.cmd_id);

    inline for (HandlerList) |handler| {
        if (handler[0] == cmd_id) {
            try handler[1](session, packet, arena.allocator());
            if (!std.mem.containsAtLeast(CmdID, &SuppressLogList, 1, &[_]CmdID{cmd_id})) {
                log.debug("packet {} was handled", .{cmd_id});
            }
            return;
        }
    }

    log.warn("packet {} was ignored", .{cmd_id});
}
