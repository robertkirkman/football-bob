-----------
-- utils --
-----------

function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

function vec3f_degrees_between(a, b)
    local ansAgain = math.acos(vec3f_dot(a, b) / (vec3f_length(a) * vec3f_length(b)))
    return math.deg(ansAgain)
end

function my_global_index()
    return gNetworkPlayers[gMarioStates[0].playerIndex].globalIndex
end

function my_location()
    local np = gNetworkPlayers[gMarioStates[0].playerIndex]
    return tostring(np.currCourseNum) ..
        '-' .. tostring(np.currLevelNum) .. '-' .. tostring(np.currAreaIndex) .. '-' .. tostring(np.currActNum)
end

function active_player(m)
    local np = gNetworkPlayers[m.playerIndex]
    if m.playerIndex == 0 then
        return true
    end
    if not np.connected then
        return false
    end
    return is_player_active(m)
end

function get_cached_ball(obj)
    local key = my_location() .. '-' .. tostring(obj.oSyncID)
    if gCachedBalls[key] == nil then
        local cb = {}
        cb.oGlobalOwner = obj.oGlobalOwner
        cb.oHitTime = obj.oHitTime
        cb.oNetworkTime = obj.oNetworkTime
        cb.oPosX = obj.oPosX
        cb.oPosY = obj.oPosY
        cb.oPosZ = obj.oPosZ
        cb.oVelX = obj.oVelX
        cb.oVelY = obj.oVelY
        cb.oVelZ = obj.oVelZ
        gCachedBalls[key] = cb
    end
    return gCachedBalls[key]
end

function should_reject_packet(obj)
    local cb = get_cached_ball(obj)
    if obj.oHitTime < cb.oHitTime then
        return true
    end

    if obj.oHitTime == cb.oHitTime and obj.oGlobalOwner > cb.oGlobalOwner then
        return true
    end

    if obj.oHitTime == cb.oHitTime and obj.oGlobalOwner == cb.oGlobalOwner and obj.oNetworkTime < cb.oNetworkTime then
        return true
    end

    return false
end

function find_ball()
    local obj = obj_get_first(OBJ_LIST_DEFAULT)
    while obj ~= nil do
        if get_id_from_behavior(obj.behavior) == id_bhvBall then
            return obj
        end
        obj = obj_get_next(obj)
    end
    return nil
end

function spawn_or_move_ball(x, y, z)
    -- search for ball
    local obj = find_ball()
    if obj ~= nil then
        -- move ball
        obj.oPosX = x
        obj.oPosY = y
        obj.oPosZ = z
        obj.oVelX = 0
        obj.oVelY = 0
        obj.oVelZ = 0

        obj.oGlobalOwner = my_global_index()
        obj.oHitTime = get_network_area_timer()
        obj.oNetworkTime = get_network_area_timer()
        network_send_object(obj, false)

        return obj
    end

    -- don't spawn unless server
    if my_global_index() ~= 0 then
        return nil
    end

    -- spawn ball
    return spawn_sync_object(
        id_bhvBall,
        E_MODEL_SPINY_BALL,
        x, y, z,

        function(obj)
            obj.oGlobalOwner = my_global_index()
        end)
end
