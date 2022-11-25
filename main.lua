-- name: Football (soccer) in BoB
-- description: Play football in BoB.
-- incompatible: gamemode
-- fork of https://github.com/djoslin0/sm64ex-coop/blob/coop/mods/football.lua
---------------
-- constants --
---------------

ballGravity = 1.5
ballRadius = 50
ballFriction = 0.988
ballRestitution = 0.65
ballWaterDrag = 0.9
ballParallelInertia = 0.3
ballPerpendicularInertia = 1

ballActionValues = {
    [ACT_WATER_PUNCH] = { xz = 20, y = 40, directionless = false },
    [ACT_MOVE_PUNCHING] = { xz = 35, y = 0, directionless = false },
    [ACT_PUNCHING] = { xz = 35, y = 0, directionless = false },
    [ACT_GROUND_POUND] = { xz = 40, y = 40, directionless = true },
    [ACT_GROUND_POUND_LAND] = { xz = 40, y = 40, directionless = true },
    [ACT_JUMP_KICK] = { xz = 10, y = 32, directionless = false },
    [ACT_SLIDE_KICK_SLIDE] = { xz = -7, y = 25, directionless = false },
    [ACT_SLIDE_KICK] = { xz = -7, y = 25, directionless = false },
    [ACT_LONG_JUMP] = { xz = 0, y = 0, directionless = false },
    [ACT_CROUCH_SLIDE] = { xz = 0, y = 0, directionless = false },
}

---------------
-- globals --
---------------

gBallTouchedLocal = false
gCachedBalls = {}

--------------
-- gamemode --
--------------

GAME_STATE_WAIT = 0
GAME_STATE_ACTIVE = 1
GAME_STATE_SCORE = 2
GAME_STATE_OOB = 3
GAME_STATE_OVER = 4

sSoccerBall = nil
sBallSpawnPos = { x = -1950, y = 100, z = 1400 }
sBallHidePos = { x = sBallSpawnPos.x, y = -10000, z = sBallSpawnPos.z }
sPlayerSpawnHeight = 50

sGameModeInitialized = false
sLevelInitialized = false
sWaitTimeout = 30 * 5
sOobTimeout = 30 * 5
sScoreTimeout = 30 * 5
sOverTimeout = 30 * 15
sStateTimer = sWaitTimeout
sMaxScore = 5

gGlobalSyncTable.gameState = GAME_STATE_WAIT
gGlobalSyncTable.displayText = ' '
gGlobalSyncTable.displayFont = FONT_HUD
gGlobalSyncTable.displayColor = 0xFFFFFF
gGlobalSyncTable.scoreRed = 0
gGlobalSyncTable.scoreBlue = 0

function gamemode_initialize()
    -- hide the SM64 HUD
    hud_hide()

    warp_to_level(LEVEL_BOB, 1, 3)

    sGameModeInitialized = true
end

function level_initialize()
    local wasRefreshed = false
    local obj = obj_get_first(OBJ_LIST_SURFACE)
    while obj ~= nil do
        local behaviorId = get_id_from_behavior(obj.behavior)

        -- hide exclamation box
        if behaviorId == id_bhvExclamationBox then
            obj.oPosX = sBallHidePos.x
            obj.oPosY = sBallHidePos.y
            obj.oPosZ = sBallHidePos.z
        end

        -- open grill door
        if behaviorId == id_bhvFloorSwitchGrills then
            obj.oAction = 2
        end

        if behaviorId == id_bhvLllHexagonalMesh then
            wasRefreshed = true
        end
        obj = obj_get_next(obj)
    end
    -- hide bob-ombs and corkbox
    local obj = obj_get_first(OBJ_LIST_DESTRUCTIVE)
    while obj ~= nil do
        obj.oPosX = sBallHidePos.x
        obj.oPosY = sBallHidePos.y
        obj.oPosZ = sBallHidePos.z
        obj = obj_get_next(obj)
    end
    -- hide goombas
    local obj = obj_get_first(OBJ_LIST_PUSHABLE)
    while obj ~= nil do
        obj.oPosX = sBallHidePos.x
        obj.oPosY = sBallHidePos.y
        obj.oPosZ = sBallHidePos.z
        obj = obj_get_next(obj)
    end

    -- server spawns objects
    if my_global_index() == 0 and not wasRefreshed then

        -- block area near elevator
        for i = 0, 3 do
            local obj = spawn_sync_object(
                id_bhvStaticCheckeredPlatform,
                E_MODEL_CHECKERBOARD_PLATFORM,
                1200 + i * 160, 1000, 3700 + i * 160,
                function(obj)
                    obj.oOpacity = 255
                    obj.oFaceAngleYaw = 0x2500
                    obj.oFaceAngleRoll = 0x4000
                end)
            network_init_object(obj, true, nil)
        end

        -- block area near elevator
        for i = 0, 1 do
            local obj = spawn_sync_object(
                id_bhvStaticCheckeredPlatform,
                E_MODEL_CHECKERBOARD_PLATFORM,
                1800, 1000, 4400 + i * 305,
                function(obj)
                    obj.oOpacity = 255
                    obj.oFaceAngleYaw = 0x0
                    obj.oFaceAngleRoll = 0x4000
                end)
            network_init_object(obj, true, nil)
        end

        -- block area between ramp and elevator
        for i = 0, 4 do
            local obj = spawn_sync_object(
                id_bhvStaticCheckeredPlatform,
                E_MODEL_CHECKERBOARD_PLATFORM,
                1700 - i * 200, 1000, 4925 + i * 100,
                function(obj)
                    obj.oOpacity = 255
                    obj.oFaceAngleYaw = -0x2980
                    obj.oFaceAngleRoll = 0x4000
                end)
            network_init_object(obj, true, nil)
        end

        -- block area near ramp
        for i = 0, 6 do
            local obj = spawn_sync_object(
                id_bhvStaticCheckeredPlatform,
                E_MODEL_CHECKERBOARD_PLATFORM,
                777, 1000, 5500 + i * 305,
                function(obj)
                    obj.oOpacity = 255
                    obj.oFaceAngleYaw = 0x0
                    obj.oFaceAngleRoll = 0x4000
                end)
            network_init_object(obj, true, nil)
        end

        -- block area behind gate
        for i = 0, 1 do
            local obj = spawn_sync_object(
                id_bhvStaticCheckeredPlatform,
                E_MODEL_CHECKERBOARD_PLATFORM,
                -2800 - i * 260, 256, -4900 + i * 130,
                function(obj)
                    obj.oOpacity = 255
                    obj.oFaceAngleYaw = -0x2980
                    obj.oFaceAngleRoll = 0x4000
                end)
            network_init_object(obj, true, nil)
        end

        -- block cannon
        local obj = spawn_sync_object(
            id_bhvLllHexagonalMesh,
            E_MODEL_TRAMPOLINE,
            -5694, 126, 5600,
            function(obj)
                obj.oOpacity = 255
                obj.header.gfx.scale.x = 0.9
                obj.header.gfx.scale.z = 0.9
            end)
        network_init_object(obj, true, nil)
    end

    sLevelInitialized = true
end

function gamemode_shuffle()
    local t = {}
    local count = 0
    -- create table of players
    for i = 0, (MAX_PLAYERS - 1) do
        local m = gMarioStates[i]
        local s = gPlayerSyncTable[i]
        if active_player(m) then
            table.insert(t, s)
            count = count + 1
        end
    end

    -- shuffle
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end

    -- assign teams
    local team1Count = 0
    local team2Count = 0
    local oddS = nil
    for i, s in ipairs(t) do
        if (i - 1) < count / 2 then
            s.team = 1
            team1Count = team1Count + 1
            oddS = s
        else
            s.team = 2
            team2Count = team2Count + 1
        end
    end

    -- shuffle odd player
    if team1Count > team2Count then
        oddS.team = math.random(1, 2)
    end
end

function gamemode_wait()
    sSoccerBall = spawn_or_move_ball(sBallSpawnPos.x, sBallSpawnPos.y, sBallSpawnPos.z)

    -- server only
    if my_global_index() == 0 then
        -- claim the ball
        if sSoccerBall.oGlobalOwner ~= my_global_index() then
            sSoccerBall.oGlobalOwner = my_global_index()
            sSoccerBall.oHitTime = get_network_area_timer()
            sSoccerBall.oNetworkTime = get_network_area_timer()
            network_send_object(sSoccerBall, false)
        end

        -- clear sparkles
        for i = 0, (MAX_PLAYERS - 1) do
            local sm = gPlayerSyncTable[i]
            sm.sparkle = false
        end

        -- decrement timer
        sStateTimer = sStateTimer - 1

        -- update the visible timer
        if math.floor(sStateTimer / 30) ~= math.floor((sStateTimer + 1) / 30) then
            gGlobalSyncTable.displayFont = FONT_HUD
            gGlobalSyncTable.displayText = tostring(1 + math.floor(sStateTimer / 30))
            gGlobalSyncTable.displayColor = 0xFFFFFF
        end

        -- start the round
        if sStateTimer <= 0 then
            gGlobalSyncTable.gameState = GAME_STATE_ACTIVE
            gGlobalSyncTable.displayFont = FONT_HUD
            gGlobalSyncTable.displayText = ' '
            gGlobalSyncTable.displayColor = 0xFFFFFF
        end
    end
end

function gamemode_active()
    -- server only
    if my_global_index() == 0 then
        local validGoalX = (sSoccerBall.oPosX > sBallSpawnPos.x and sSoccerBall.oPosX > -870 and sSoccerBall.oPosX < 719
            ) or
            (sSoccerBall.oPosX < sBallSpawnPos.x and sSoccerBall.oPosX > -4000 and sSoccerBall.oPosX < -2025)
        local validGoalY = (sSoccerBall.oPosY + ballRadius) >= 0 and (sSoccerBall.oPosY + ballRadius) < 256
        local validGoalZ = (
            sSoccerBall.oPosX > sBallSpawnPos.x and sSoccerBall.oPosZ > 5380 and sSoccerBall.oPosZ < 5900) or
            (sSoccerBall.oPosX < sBallSpawnPos.x and sSoccerBall.oPosZ > -5800 and sSoccerBall.oPosZ < -3000)
        if validGoalX and validGoalY and validGoalZ then
            spawn_sync_object(id_bhvExplosion, E_MODEL_EXPLOSION, sSoccerBall.oPosX, sSoccerBall.oPosY, sSoccerBall.oPosZ
                , nil)

            local scoringTeam = 0
            if sSoccerBall.oPosX < sBallSpawnPos.x then
                scoringTeam = 2
            else
                scoringTeam = 1
            end

            local gameOver = false
            local displayName = ''
            local scorerNp = network_player_from_global_index(sSoccerBall.oGlobalOwner)
            if scorerNp ~= nil then
                local scorerS = gPlayerSyncTable[scorerNp.localIndex]
                if scorerS.team == scoringTeam then
                    displayName = ' (' .. scorerNp.name .. ')'
                end
            end

            if scoringTeam == 1 then
                gGlobalSyncTable.scoreRed = gGlobalSyncTable.scoreRed + 1
                gGlobalSyncTable.displayFont = FONT_NORMAL
                gGlobalSyncTable.displayColor = 0xFF9999
                if gGlobalSyncTable.scoreRed >= sMaxScore then
                    gGlobalSyncTable.displayText = 'red team wins!'
                    gameOver = true
                else
                    gGlobalSyncTable.displayText = 'red team scored' .. displayName
                end
            else
                gGlobalSyncTable.scoreBlue = gGlobalSyncTable.scoreBlue + 1
                gGlobalSyncTable.displayFont = FONT_NORMAL
                gGlobalSyncTable.displayColor = 0x9999FF
                if gGlobalSyncTable.scoreBlue >= sMaxScore then
                    gGlobalSyncTable.displayText = 'blue team wins!'
                    gameOver = true
                else
                    gGlobalSyncTable.displayText = 'blue team scored' .. displayName
                end
            end

            if gameOver then
                -- set sparkle
                for i = 0, (MAX_PLAYERS - 1) do
                    local im = gMarioStates[i]
                    local sm = gPlayerSyncTable[i]
                    if active_player(im) then
                        if sm.team == scoringTeam then
                            sm.sparkle = true
                        end
                    end
                end

                gGlobalSyncTable.gameState = GAME_STATE_OVER
                sStateTimer = sOverTimeout
            else
                -- set sparkle
                local scorerS = gPlayerSyncTable[scorerNp.localIndex]
                if scorerNp ~= nil and scorerS.team == scoringTeam then
                    scorerS.sparkle = true
                end
                gGlobalSyncTable.gameState = GAME_STATE_SCORE
                sStateTimer = sScoreTimeout
            end
        end

        -- check for oob
        local ignoreOob = (
            sSoccerBall.oPosX >= 3230 and sSoccerBall.oPosX <= 4460 and sSoccerBall.oPosZ >= -6230 and
                sSoccerBall.oPosZ <= -2725) -- ramp near bridge
        -- if not ignoreOob and sSoccerBall.oPosY > 0 then
        --     local floorHeight = find_floor_height(sSoccerBall.oPosX, sSoccerBall.oPosY, sSoccerBall.oPosZ)
        --     if sSoccerBall.oPosY - ballRadius - 10 < floorHeight then
        --         gGlobalSyncTable.gameState = GAME_STATE_OOB
        --         sStateTimer = sOobTimeout
        --     end
        -- end

        -- check for other OOB
        -- if validGoalY and not validGoalZ then
        --     gGlobalSyncTable.gameState = GAME_STATE_OOB
        --     sStateTimer = sOobTimeout
        -- end
    end
end

function gamemode_score()
    sSoccerBall = spawn_or_move_ball(sBallHidePos.x, sBallHidePos.y, sBallHidePos.z)

    -- server only
    if my_global_index() == 0 then
        -- decrement timer
        sStateTimer = sStateTimer - 1

        -- start the round
        if sStateTimer <= 0 then
            gGlobalSyncTable.gameState = GAME_STATE_WAIT
            sStateTimer = sWaitTimeout
        end
    end
end

function gamemode_oob()
    sSoccerBall = spawn_or_move_ball(sBallHidePos.x, sBallHidePos.y, sBallHidePos.z)

    -- server only
    if my_global_index() == 0 then
        -- decrement timer
        sStateTimer = sStateTimer - 1

        gGlobalSyncTable.displayFont = FONT_NORMAL
        gGlobalSyncTable.displayText = 'out of bounds'
        gGlobalSyncTable.displayColor = 0xFFFFFF

        -- start the round
        if sStateTimer <= 0 then
            gGlobalSyncTable.gameState = GAME_STATE_WAIT
            sStateTimer = sWaitTimeout
        end
    end
end

function gamemode_over()
    sSoccerBall = spawn_or_move_ball(sBallHidePos.x, sBallHidePos.y, sBallHidePos.z)

    -- server only
    if my_global_index() == 0 then
        -- decrement timer
        sStateTimer = sStateTimer - 1

        -- start the round
        if sStateTimer <= 0 then
            -- shuffle teams
            gamemode_shuffle()
            gGlobalSyncTable.scoreRed = 0
            gGlobalSyncTable.scoreBlue = 0
            gGlobalSyncTable.gameState = GAME_STATE_WAIT
            sStateTimer = sWaitTimeout
        end
    end
end

function gamemode_update()
    if not sGameModeInitialized then
        gamemode_initialize()
    end

    if gNetworkPlayers[0].currLevelNum == LEVEL_BOB and not sLevelInitialized then
        level_initialize()
    end

    -- move all black balls to the containment pit as soon as they spawn
    -- if they are moved to sBallHidePos something bad happens
    local obj = obj_get_first(OBJ_LIST_GENACTOR)
    while obj ~= nil do
        local behaviorId = get_id_from_behavior(obj.behavior)
        if behaviorId == id_bhvBowlingBall then
            obj.oPosX = -1000
            obj.oPosY = 800
            obj.oPosZ = -3866
        end
        obj = obj_get_next(obj)
    end

    if sSoccerBall == nil then
        sSoccerBall = find_ball()
    else
        if gGlobalSyncTable.gameState == GAME_STATE_WAIT then
            sSoccerBall.oFrozen = 1
        else
            sSoccerBall.oFrozen = 0
        end
    end

    if gGlobalSyncTable.gameState == GAME_STATE_WAIT then
        gamemode_wait()
    elseif gGlobalSyncTable.gameState == GAME_STATE_ACTIVE then
        gamemode_active()
    elseif gGlobalSyncTable.gameState == GAME_STATE_SCORE then
        gamemode_score()
    elseif gGlobalSyncTable.gameState == GAME_STATE_OOB then
        gamemode_oob()
    elseif gGlobalSyncTable.gameState == GAME_STATE_OVER then
        gamemode_over()
    end
end

--- @param m MarioState
function on_player_connected(m)
    -- only run on server
    if not network_is_server() then
        return
    end

    -- figure out team
    local selectTeam = math.random(1, 2)
    local playersTeam1 = 0
    local playersTeam2 = 0
    for i = 0, (MAX_PLAYERS - 1) do
        local im = gMarioStates[i]
        local sm = gPlayerSyncTable[i]
        if active_player(im) and i ~= m.playerIndex then
            if sm.team == 1 then
                playersTeam1 = playersTeam1 + 1
            elseif sm.team == 2 then
                playersTeam2 = playersTeam2 + 1
            end
        end
    end
    if playersTeam1 < playersTeam2 then
        selectTeam = 1
    elseif playersTeam2 < playersTeam1 then
        selectTeam = 2
    end

    -- set team
    local s = gPlayerSyncTable[m.playerIndex]
    local np = gNetworkPlayers[m.playerIndex]
    s.team = selectTeam
end

--- @param m1 MarioState
--- @param m2 MarioState
function allow_pvp_attack(m1, m2)
    local s1 = gPlayerSyncTable[m1.playerIndex]
    local s2 = gPlayerSyncTable[m2.playerIndex]
    if s1.team == s2.team then
        return false
    end
    return true
end

function hud_score_render()
    djui_hud_set_font(FONT_HUD)

    -- get width of screen and text
    local screenWidth = djui_hud_get_screen_width()

    local width = 32
    local height = 16
    local x = (screenWidth - width) / 2.0
    local y = 5
    local xOffset = 20
    local textOffset = 8

    if gPlayerSyncTable[0].team == 2 then
        xOffset = xOffset * -1
    end

    -- render
    djui_hud_set_color(255, 100, 100, 180);
    djui_hud_render_rect(x - xOffset, y, width, height + 4);

    djui_hud_set_color(100, 100, 255, 180);
    djui_hud_render_rect(x + xOffset, y, width, height + 4);

    djui_hud_set_color(255, 255, 255, 255);
    djui_hud_print_text(tostring(gGlobalSyncTable.scoreRed), x - xOffset + textOffset, y + 2, 1);
    djui_hud_print_text(tostring(gGlobalSyncTable.scoreBlue), x + xOffset + textOffset, y + 2, 1);
end

function on_hud_render()
    -- render to N64 screen space, with the HUD font
    djui_hud_set_resolution(RESOLUTION_N64)

    hud_score_render()

    if gGlobalSyncTable.displayText == ' ' then
        return
    end
    djui_hud_set_font(gGlobalSyncTable.displayFont)

    -- set text
    local text = gGlobalSyncTable.displayText

    -- set scale
    local scale = 1

    local height = 1
    if gGlobalSyncTable.displayFont == FONT_HUD then
        height = 16 * scale
    elseif gGlobalSyncTable.displayFont == FONT_NORMAL then
        scale = 0.5
        height = 32 * scale
    end

    -- get width of screen and text
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local width = djui_hud_measure_text(text) * scale

    local x = (screenWidth - width) / 2.0
    local y = (screenHeight * 0.6 - height) / 2.0

    -- render
    djui_hud_set_color(0, 0, 0, 128);
    djui_hud_render_rect(x - 6 * scale, y - 6 * scale, width + 12 * scale, height + 12 * scale);

    local r = (gGlobalSyncTable.displayColor & 0xFF0000) >> (8 * 2)
    local g = (gGlobalSyncTable.displayColor & 0x00FF00) >> (8 * 1)
    local b = (gGlobalSyncTable.displayColor & 0x0000FF) >> (8 * 0)
    djui_hud_set_color(r, g, b, 255);
    djui_hud_print_text(text, x, y, scale);

end

function on_football_reset_command(msg)
    if msg == 'ball' then
        djui_chat_message_create('Resetting the ball.')
        sSoccerBall = spawn_or_move_ball(sBallSpawnPos.x, sBallSpawnPos.y, sBallSpawnPos.z)
        return true
    elseif msg == 'game' then
        djui_chat_message_create('Resetting the game.')
        gamemode_shuffle()
        gGlobalSyncTable.scoreRed = 0
        gGlobalSyncTable.scoreBlue = 0
        gGlobalSyncTable.displayText = ' '
        gGlobalSyncTable.gameState = GAME_STATE_WAIT
        sStateTimer = sWaitTimeout
        return true
    end
    return false
end

------------------
-- update stuff --
------------------

--- @param m MarioState
function mario_update_local(m)
    local np = gNetworkPlayers[m.playerIndex]
    local s = gPlayerSyncTable[m.playerIndex]

    if (m.controller.buttonPressed & D_JPAD) ~= 0 then
        --print(m.pos.x, m.pos.y, m.pos.z)
        --sSoccerBall = spawn_or_move_ball(m.pos.x, m.pos.y, m.pos.z)
    end

    -- force players into certain positions and angles
    if gGlobalSyncTable.gameState == GAME_STATE_WAIT then
        -- figure out team index
        local teamIndex = 0
        for i = 1, (MAX_PLAYERS - 1) do
            local mi = gMarioStates[i]
            local ni = gNetworkPlayers[i]
            local si = gPlayerSyncTable[i]
            if active_player(mi) and si.team == s.team then
                if ni.globalIndex < np.globalIndex then
                    teamIndex = teamIndex + 1
                end
            end
        end

        -- center camera
        m.controller.buttonDown = m.controller.buttonDown | L_TRIG

        -- figure out spawn position
        local teamTheta = (3.14 / 50)
        local teamDistance = 5200
        if (teamIndex % 2) == 0 then
            teamTheta = teamTheta - (teamIndex % 4) * 0.1
            teamDistance = teamDistance + math.floor(teamIndex / 4) * 500
        else
            teamTheta = teamTheta + (teamIndex % 4) * 0.1
            teamDistance = teamDistance + math.floor(teamIndex / 4) * 500
        end

        -- set spawn position
        local playerPos = { x = sBallSpawnPos.x, y = sPlayerSpawnHeight, z = sBallSpawnPos.z }
        if s.team == 1 then
            playerPos.x = playerPos.x - math.sin(teamTheta) * teamDistance
            playerPos.z = playerPos.z - math.cos(teamTheta) * teamDistance
            m.faceAngle.y = 0x0
        elseif s.team == 2 then
            playerPos.x = playerPos.x + math.sin(teamTheta) * teamDistance
            playerPos.z = playerPos.z + math.cos(teamTheta) * teamDistance
            m.faceAngle.y = 0x8000
        end
        m.faceAngle.x = 0
        m.faceAngle.z = 0
        m.pos.x = playerPos.x
        m.pos.y = playerPos.y
        m.pos.z = playerPos.z
        m.vel.x = 0
        m.vel.y = 0
        m.vel.z = 0
        m.forwardVel = 0
        m.slideVelX = 0
        m.slideVelZ = 0
        set_mario_action(m, ACT_READING_AUTOMATIC_DIALOG, 0)

        -- fix vanilla camera
        if m.area.camera.mode == CAMERA_MODE_WATER_SURFACE then
            set_camera_mode(m.area.camera, CAMERA_MODE_FREE_ROAM, 1)
        end
    elseif m.action == ACT_READING_AUTOMATIC_DIALOG then
        set_mario_action(m, ACT_IDLE, 0)
    end
end

--- @param m MarioState
function mario_update(m)
    if m.playerIndex == 0 then
        mario_update_local(m)
    end

    -- update pos/angle
    if m.action == ACT_READING_AUTOMATIC_DIALOG then
        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        vec3s_set(m.marioObj.header.gfx.angle, -m.faceAngle.x, m.faceAngle.y, m.faceAngle.z)
    end

    -- set metal state and health
    local s = gPlayerSyncTable[m.playerIndex]
    local np = gNetworkPlayers[m.playerIndex]
    if s.team == 2 then
        np.overridePaletteIndex = 7
        m.marioBodyState.modelState = 0
    elseif s.team == 1 then
        np.overridePaletteIndex = 15
        m.marioBodyState.modelState = 0
    else
        np.overridePaletteIndex = np.paletteIndex
        m.marioBodyState.modelState = MODEL_STATE_NOISE_ALPHA
    end
    m.health = 0x880

    -- update description
    if s.team == 1 then
        network_player_set_description(np, "red", 255, 64, 64, 255)
    elseif s.team == 2 then
        network_player_set_description(np, "blue", 64, 64, 255, 255)
    else
        network_player_set_description(np, "unknown", 64, 64, 64, 255)
    end

    if gPlayerSyncTable[m.playerIndex].sparkle then
        m.particleFlags = m.particleFlags | PARTICLE_SPARKLES
    else
        m.particleFlags = (m.particleFlags & (~PARTICLE_SPARKLES))
    end
end

function update()
    local m = gMarioStates[0]
    local np = gNetworkPlayers[m.playerIndex]

    if np.currAreaSyncValid then
        gamemode_update()
    end
end

function on_level_init()

end

-----------
-- hooks --
-----------

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
hook_event(HOOK_ALLOW_PVP_ATTACK, allow_pvp_attack)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
if network_is_server() then
    hook_chat_command('football-reset', "[game|ball] resets the game or ball", on_football_reset_command)
end

for i = 0, (MAX_PLAYERS - 1) do
    local s = gPlayerSyncTable[i]
    s.team = 0
    s.sparkle = false
end
