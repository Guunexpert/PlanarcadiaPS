--local function onDialogClosed()
    --CS.UnityEngine.Application.OpenURL("https://github.com/Guunexpert/EvanesciaPlapPlap")
--end

local function show_hint()
    local text = "Welcome to PlanarcadiaPS!\n"
    text = text .. "This server is reimplementation of the original YaoguangPS\n"
    text = text .. "Enjoy the game!\n"
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint(text, onDialogClosed)
end

show_hint()