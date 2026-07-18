local util = require("xlua.util")

local function startAnimationSnatcher()
    local isFreecam = false
    local vPos = CS.UnityEngine.Vector3.zero
    local vRot = CS.UnityEngine.Vector3.zero
    local targetPool = {}
    local dynamicSuppressNames = {"VCamera", "CameraAnchor", "CameraCollider", "CameraAnimation"}

    -- Helper: scan scene and suppress matching objects right now
    local function suppressAll()
        local all = CS.UnityEngine.Object.FindObjectsOfType(typeof(CS.UnityEngine.GameObject))
        for i = 0, all.Length - 1 do
            local obj = all[i]
            if obj and obj.activeSelf then
                local name = obj.name
                for _, pattern in ipairs(dynamicSuppressNames) do
                    if name:find(pattern) then
                        obj:SetActive(false)
                        -- Track it so we can restore later
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

        while true do
            if CS.UnityEngine.Input.GetKeyDown(CS.UnityEngine.KeyCode.F10) then
                isFreecam = not isFreecam
                local cam = CS.UnityEngine.Camera.main
                if cam then
                    vPos = cam.transform.position
                    vRot = cam.transform.eulerAngles
                    local brain = cam:GetComponent(typeof(CS.Cinemachine.CinemachineBrain))
                    if brain then brain.enabled = not isFreecam end

                    -- Also kill Animator on the camera itself if any
                    local anim = cam:GetComponent(typeof(CS.UnityEngine.Animator))
                    if anim then anim.enabled = not isFreecam end
                end

                if not isFreecam then
                    -- Restore all suppressed objects on exit
                    for _, obj in ipairs(targetPool) do
                        if obj then obj:SetActive(true) end
                    end
                    targetPool = {}
                    suppressTimer = 0
                else
                    targetPool = {}
                    suppressAll() -- Initial sweep on enable
                end
            end

            if isFreecam then
                -- KEY FIX: Re-scan every ~10 frames to catch newly spawned anim cameras
                suppressTimer = suppressTimer + 1
                if suppressTimer >= 10 then
                    suppressTimer = 0
                    suppressAll()
                end

                -- Snap to CameraAnimation (R key) - search dynamically
                if CS.UnityEngine.Input.GetKeyDown(CS.UnityEngine.KeyCode.R) then
                    local animObj = CS.UnityEngine.GameObject.Find("CameraAnimation")
                    if animObj then
                        vPos = animObj.transform.position
                        vRot = animObj.transform.eulerAngles
                        print("Snapped to CameraAnimation position!")
                    else
                        print("CameraAnimation not found in scene.")
                    end
                end

                local cam = CS.UnityEngine.Camera.main
                if cam then
                    local trans = cam.transform

                    -- Rotation (Arrow Keys)
                    local rotSpeed = 2.0
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.UpArrow) then vRot.x = vRot.x - rotSpeed end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.DownArrow) then vRot.x = vRot.x + rotSpeed end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.LeftArrow) then vRot.y = vRot.y - rotSpeed end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.RightArrow) then vRot.y = vRot.y + rotSpeed end

                    -- Movement (WASD + PageUp/Down)
                    local moveDir = CS.UnityEngine.Vector3.zero
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.W) then moveDir = moveDir + trans.forward end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.S) then moveDir = moveDir - trans.forward end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.A) then moveDir = moveDir - trans.right end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.D) then moveDir = moveDir + trans.right end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.PageUp) then moveDir = moveDir + CS.UnityEngine.Vector3.up end
                    if CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.PageDown) then moveDir = moveDir + CS.UnityEngine.Vector3.down end

                    vPos = vPos + (moveDir.normalized * 0.6)

                    -- Force override every frame so animation can't steal it back
                    trans.position = vPos
                    trans.eulerAngles = CS.UnityEngine.Vector3(vRot.x, vRot.y, 0)
                end
            end

            coroutine.yield(nil)
        end
    end

    CS.RPG.Client.CoroutineUtils.StartCoroutine(util.cs_generator(loop))
end

startAnimationSnatcher()