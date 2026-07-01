local util = require("xlua.util")

local function startAnimationSnatcher()
    local isFreecam = false
    local vPos = CS.UnityEngine.Vector3.zero
    local vRot = CS.UnityEngine.Vector3.zero
    local targetPool = {}
    
    -- Ditambah keywords terkait Timeline dan Playable yang sering mengunci Ultimate
    local dynamicSuppressNames = {
        "VCamera", "CameraAnchor", "CameraCollider", 
        "CameraAnimation", "Timeline", "Playable", "Clips"
    }

    local function suppressAll()
        local all = CS.UnityEngine.Object.FindObjectsOfType(typeof(CS.UnityEngine.GameObject))
        for i = 0, all.Length - 1 do
            local obj = all[i]
            if obj and obj.activeSelf then
                local name = obj.name
                for _, pattern in ipairs(dynamicSuppressNames) do
                    if name:find(pattern) then
                        obj:SetActive(false)
                        local found = false
                        for _, existing in ipairs(targetPool) do
                            if existing == obj then found = true break end
                        end
                        if not found then
                            table.insert(targetPool, obj)
                        end
                        break
                    end
                end
            end
        end
    end

    local function loop()
        local suppressTimer = 0
        -- Cache WaitForEndOfFrame agar eksekusi script kita selalu MENANG paling akhir di setiap frame
        local waitFrame = CS.UnityEngine.WaitForEndOfFrame()

        while true do
            if CS.UnityEngine.Input.GetKeyDown(CS.UnityEngine.KeyCode.F10) then
                isFreecam = not isFreecam
                local cam = CS.UnityEngine.Camera.main
                if cam then
                    vPos = cam.transform.position
                    vRot = cam.transform.eulerAngles
                    
                    -- Matikan Cinemachine
                    local brain = cam:GetComponent(typeof(CS.Cinemachine.CinemachineBrain))
                    if brain then brain.enabled = not isFreecam end

                    -- Matikan Animator
                    local anim = cam:GetComponent(typeof(CS.UnityEngine.Animator))
                    if anim then anim.enabled = not isFreecam end
                    
                    -- LUA REVERSE ENGINEERING TRICK: 
                    -- Matikan script custom RPG Client bawaan HSR yang menempel di kamera utama jika ada
                    local scripts = cam:GetComponents(typeof(CS.UnityEngine.MonoBehaviour))
                    for i = 0, scripts.Length - 1 do
                        local s = scripts[i]
                        -- Jangan matikan script render/post processing penting, cukup yang handle posisi
                        if s and s.GetType().Name:find("Camera") then
                            s.enabled = not isFreecam
                        end
                    end
                end

                if not isFreecam then
                    for _, obj in ipairs(targetPool) do
                        if obj then obj:SetActive(true) end
                    end
                    targetPool = {}
                    suppressTimer = 0
                else
                    targetPool = {}
                    suppressAll()
                end
            end

            if isFreecam then
                suppressTimer = suppressTimer + 1
                if suppressTimer >= 5 then -- Dipercepat ke 5 frame agar lebih agresif menangkap kamera ulti baru
                    suppressTimer = 0
                    suppressAll()
                end

                if CS.UnityEngine.Input.GetKeyDown(CS.UnityEngine.KeyCode.R) then
                    local animObj = CS.UnityEngine.GameObject.Find("CameraAnimation")
                    if animObj then
                        vPos = animObj.transform.position
                        vRot = animObj.transform.eulerAngles
                    end
                end

                local cam = CS.UnityEngine.Camera.main
                if cam then
                    local trans = cam.transform
                    local rotSpeed = 2.0

                    -- Input rotasi & gerakan (Tetap sama seperti logika kamu)
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.UpArrow) then vRot.x = vRot.x - rotSpeed end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.DownArrow) then vRot.x = vRot.x + rotSpeed end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.LeftArrow) then vRot.y = vRot.y - rotSpeed end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.RightArrow) then vRot.y = vRot.y + rotSpeed end

                    local moveDir = CS.UnityEngine.Vector3.zero
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.W) then moveDir = moveDir + trans.forward end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.S) then moveDir = moveDir - trans.forward end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.A) then moveDir = moveDir - trans.right end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.D) then moveDir = moveDir + trans.right end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.PageUp) then moveDir = moveDir + CS.UnityEngine.Vector3.up end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.PageDown) then moveDir = moveDir - CS.UnityEngine.Vector3.up end

                    vPos = vPos + (moveDir.normalized * 0.6)

                    -- FORCE OVERRIDE DI AKHIR FRAME
                    trans.position = vPos
                    trans.eulerAngles = CS.UnityEngine.Vector3(vRot.x, vRot.y, 0)
                end
            end

            -- Mengubah yield(nil) menjadi WaitForEndOfFrame
            coroutine.yield(waitFrame)
        end
    end

    CS.RPG.Client.CoroutineUtils.StartCoroutine(util.cs_generator(loop))
end

startAnimationSnatcher()
