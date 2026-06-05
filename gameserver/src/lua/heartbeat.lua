local function setTextComponent(path, newText)
    local obj = CS.UnityEngine.GameObject.Find(path)
    if not obj then return false end

    local localized = obj:GetComponentInChildren(typeof(CS.RPG.Client.LocalizedText))
    if localized then
        localized.text = newText
        return true
    end
    return false
end

setTextComponent(
   "UIRoot/AboveDialog/BetaHintDialog(Clone)",
   "<color=#E7DFEB></color>"
)

setTextComponent(
    "VersionText",
    "<color=#9F0000>Rin</color> <color=FFFFFF>Tohsaka</color>"
)
