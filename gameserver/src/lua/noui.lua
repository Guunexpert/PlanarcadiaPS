function UpdateNoUI()
    if CS.UnityEngine.Input.GetKeyDown(CS.UnityEngine.KeyCode.F11) then
        CS.UnityEngine.GameObject.Find("/UICamera"):SetActive(not CS.UnityEngine.GameObject.Find("/UICamera").activeSelf)
    end
end