local util = require("xlua.util")

local function startJumpSystem()
    local isJumping = false
    local verticalVelocity = 0
    local gravity = -9.81 * 2
    local jumpForce = 12
    local groundY = 0
    local isGrounded = true
    
    local function findPlayerAvatar()
        local all = CS.UnityEngine.Object.FindObjectsOfType(typeof(CS.UnityEngine.GameObject))
        for i = 0, all.Length - 1 do
            local obj = all[i]
            if obj and obj.activeSelf then
                local name = obj.name
                if name:find("Avatar") or name:find("Player") or name:find("MainChar") then
                    local anim = obj:GetComponent(typeof(CS.UnityEngine.Animator))
                    if anim and anim.isHuman then
                        return obj
                    end
                end
            end
        end
        return nil
    end

    local function findPlayerController()
        local all = CS.UnityEngine.Object.FindObjectsOfType(typeof(CS.UnityEngine.MonoBehaviour))
        for i = 0, all.Length - 1 do
            local comp = all[i]
            if comp then
                local typeName = comp.GetType().Name
                if typeName:find("PlayerController") or typeName:find("AvatarController") or typeName:find("CharacterController") then
                    return comp
                end
            end
        end
        return nil
    end

    local function loop()
        local waitFrame = CS.UnityEngine.WaitForEndOfFrame()
        local playerObj = nil
        local findTimer = 0

        while true do
            if CS.UnityEngine.Input.GetKeyDown(CS.UnityEngine.KeyCode.Space) then
                if not playerObj then
                    playerObj = findPlayerAvatar()
                    if playerObj then
                        groundY = playerObj.transform.position.y
                        print("Jump system: Found player avatar - " .. playerObj.name)
                    end
                end

                if playerObj and isGrounded then
                    isJumping = true
                    isGrounded = false
                    verticalVelocity = jumpForce
                    groundY = playerObj.transform.position.y
                    print("Jump!")
                end
            end

            if playerObj and isJumping then
                local pos = playerObj.transform.position
                verticalVelocity = verticalVelocity + gravity * CS.UnityEngine.Time.deltaTime
                pos.y = pos.y + verticalVelocity * CS.UnityEngine.Time.deltaTime

                if pos.y <= groundY then
                    pos.y = groundY
                    verticalVelocity = 0
                    isJumping = false
                    isGrounded = true
                end

                playerObj.transform.position = pos
            end

            if not playerObj then
                findTimer = findTimer + 1
                if findTimer >= 60 then
                    findTimer = 0
                    playerObj = findPlayerAvatar()
                end
            end

            coroutine.yield(waitFrame)
        end
    end

    CS.RPG.Client.CoroutineUtils.StartCoroutine(util.cs_generator(loop))
end

startJumpSystem()