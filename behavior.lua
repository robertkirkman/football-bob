--------------
-- behavior --
--------------

-- define ball's custom fields
define_custom_obj_fields({
    oNetworkTime = 'u32',
    oHitTime = 'u32',
    oGlobalOwner = 'u32',
    oFrozen = 'u32',
})

--- @param obj Object
function bhv_ball_particle_trail(obj)
    local spi = obj_get_temp_spawn_particles_info(E_MODEL_SPARKLES)
    if spi == nil then
        return nil
    end

    spi.behParam = 2
    spi.count = 1
    spi.offsetY = -1 * ballRadius
    spi.forwardVelBase = 8
    spi.forwardVelRange = 0
    spi.velYBase = 6
    spi.velYRange = 0
    spi.gravity = 0
    spi.dragStrength = 5
    spi.sizeBase = 10
    spi.sizeRange = 30

    cur_obj_spawn_particles(spi)
end

--- @param obj Object
function bhv_ball_particle_bounce(obj)
    local spi = obj_get_temp_spawn_particles_info(E_MODEL_MIST)
    if spi == nil then
        return nil
    end

    spi.behParam = 3
    spi.count = 5
    spi.offsetY = -1 * ballRadius
    spi.forwardVelBase = 6
    spi.forwardVelRange = -6
    spi.velYBase = 6
    spi.velYRange = -6
    spi.gravity = 0
    spi.dragStrength = 5
    spi.sizeBase = 8
    spi.sizeRange = 13

    cur_obj_spawn_particles(spi)
end

--- @param obj Object
function bhv_ball_init(obj)
    -- flags and such
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oGraphYOffset = 0
    cur_obj_scale(1.4)

    -- physics
    obj.oWallHitboxRadius = 40.00
    obj.oGravity          = 2.50
    obj.oBounciness       = -0.75
    obj.oDragStrength     = 0.00
    obj.oFriction         = 0.99
    obj.oBuoyancy         = -2.00

    -- hitbox
    obj.hitboxRadius = 100
    obj.hitboxHeight = 100

    -- custom values
    obj.oNetworkTime = 0
    obj.oHitTime = 0
    obj.oFrozen = 0

    -- cache
    local cb = get_cached_ball(obj)

    network_init_object(obj, false, {
        'oPosX',
        'oPosY',
        'oPosZ',
        'oVelX',
        'oVelY',
        'oVelZ',
        'oGlobalOwner',
        'oNetworkTime',
        'oHitTime',
    })
end

--- @param obj Object
function bhv_ball_player_collision(obj)
    local alterPos = { x = 0, y = 0, z = 0 }

    local m = nearest_mario_state_to_object(obj)
    if m == nil then return alterPos end
    local player = m.marioObj
    if player == nil then return alterPos end

    local playerRadius = 37
    local playerHeight = 160

    local objPoint = { x = obj.oPosX, y = obj.oPosY, z = obj.oPosZ }
    local v = { x = obj.oVelX, y = obj.oVelY, z = obj.oVelZ }

    -- figure out player-to-ball radius
    local alterBallFlags = (ACT_FLAG_ATTACKING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_DIVING)
    local playerBallRadius = ballRadius
    if ballActionValues[m.action] ~= nil or (m.action & alterBallFlags) ~= 0 then
        playerBallRadius = playerBallRadius + 50
    end

    ------------------------------------------------
    -- calculate position and determine collision --
    ------------------------------------------------

    -- calculate cylinder values
    local cylY1 = player.oPosY + playerRadius
    local cylY2 = player.oPosY + playerHeight - playerRadius
    local cylPoint = { x = player.oPosX, y = clamp(obj.oPosY, cylY1, cylY2), z = player.oPosZ }
    local cylDist = vec3f_dist(cylPoint, objPoint)

    -- check for collision
    if cylDist > (playerBallRadius + playerRadius) then
        return alterPos
    end

    gBallTouchedLocal = (m.playerIndex == 0)

    local vDifference = { x = objPoint.x - cylPoint.x, y = objPoint.y - cylPoint.y, z = objPoint.z - cylPoint.z }
    local differenceDir = { x = vDifference.x, y = vDifference.y, z = vDifference.z }
    if vec3f_length(differenceDir) ~= 0 then
        vec3f_normalize(differenceDir)
    end

    alterPos.x = (cylPoint.x + differenceDir.x * (playerBallRadius + playerRadius + 1)) - objPoint.x
    alterPos.y = (cylPoint.y + differenceDir.y * (playerBallRadius + playerRadius + 1)) - objPoint.y
    alterPos.z = (cylPoint.z + differenceDir.z * (playerBallRadius + playerRadius + 1)) - objPoint.z

    -----------------------------------------
    -- figure out player's attack velocity --
    -----------------------------------------

    local vPlayer = { x = player.oVelX, y = player.oVelY, z = player.oVelZ }
    local playerTheta = (m.faceAngle.y / 0x8000) * math.pi

    -- have attacks alter velocity further
    local alterXz = 0
    local alterY = 0
    local alterDirectionless = false

    if ballActionValues[m.action] ~= nil then
        alterXz = ballActionValues[m.action].xz
        alterY = ballActionValues[m.action].y
        alterDirectionless = ballActionValues[m.action].directionless
    elseif ((m.action & (ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_DIVING)) ~= 0) or (m.action == ACT_SLIDE_KICK_SLIDE)
        or (m.action == ACT_SLIDE_KICK) then
        -- dive or slide sends it upward, and slows xz
        alterXz = -7
        alterY = 25
    elseif (m.action & ACT_FLAG_ATTACKING) ~= 0 then
        -- other attacks should just do something reasonable
        alterXz = 10
        alterY = 10
    end

    -- adjust angle
    local theta = playerTheta
    if alterDirectionless and differenceDir.z ~= 0 then
        theta = math.atan2(differenceDir.x, differenceDir.z)
    end

    vPlayer.x = vPlayer.x + math.sin(theta) * alterXz
    vPlayer.z = vPlayer.z + math.cos(theta) * alterXz
    if vPlayer.y < alterY then vPlayer.y = vPlayer.y + alterY end

    local vPlayerMag = vec3f_length(vPlayer)

    -------------------------------------------------
    -- figure out which velocity interaction to do --
    -------------------------------------------------

    local v = { x = obj.oVelX, y = obj.oVelY, z = obj.oVelZ }

    local doReflection = (vPlayerMag == 0)

    -- make sure ball is offset in the vPlayer direction
    if not doReflection then
        local objCylDir = { x = cylPoint.x - objPoint.x, y = cylPoint.y - objPoint.y, z = cylPoint.z - objPoint.z }
        local objCylDirXZ = { x = objCylDir.x, y = 0, z = objCylDir.z }
        local objCylDirMag = vec3f_length(objCylDir)

        local vPlayerXZ = { x = vPlayer.x, y = 0, z = vPlayer.z }
        local vPlayerXZMag = vec3f_length(vPlayerXZ)

        if objCylDirMag > 0 and vPlayerXZMag > 0 then
            doReflection = (vec3f_degrees_between(vPlayer, objCylDir)) <= 120
                and (vec3f_degrees_between(vPlayerXZ, objCylDirXZ)) <= 120
        end
    end

    -- make sure player has a velocity
    if not doReflection and vPlayerMag == 0 then
        doReflection = true
    end

    --------------------------------------
    -- calculate velocity (interaction) --
    --------------------------------------

    if not doReflection then
        local vPlayerDir = { x = vPlayer.x, y = vPlayer.y, z = vPlayer.z }
        vec3f_normalize(vPlayerDir)

        -- split velocity into parallel/perpendicular to normal
        local perpendicular = vec3f_project(v, vPlayerDir)
        local parallel = { x = v.x - perpendicular.x, y = v.y - perpendicular.y, z = v.z - perpendicular.z }

        -- apply friction
        vec3f_mul(parallel, 0.5)

        local parallelMag = vec3f_length(parallel)
        local perpendicularMag = vec3f_length(perpendicular)

        if perpendicularMag == 0 or perpendicularMag < vPlayerMag then
            vec3f_copy(perpendicular, vPlayer)
        end

        -- reflect velocity along normal
        local reflect = {
            x = parallel.x + perpendicular.x,
            y = parallel.y + perpendicular.y,
            z = parallel.z + perpendicular.z
        }

        -- set new velocity
        obj.oVelX = reflect.x
        obj.oVelY = reflect.y
        obj.oVelZ = reflect.z
    end

    -------------------------------------
    -- calculate velocity (reflection) --
    -------------------------------------

    if doReflection then
        -- split velocity into parallel/perpendicular to normal
        local perpendicular = vec3f_project(v, differenceDir)
        local parallel = { x = v.x - perpendicular.x, y = v.y - perpendicular.y, z = v.z - perpendicular.z }

        -- apply friction and restitution
        vec3f_mul(parallel, ballFriction)
        vec3f_mul(perpendicular, ballRestitution)

        -- play sounds
        local parallelLength = vec3f_length(parallel)
        local perpendicularLength = vec3f_length(perpendicular)

        if perpendicularLength > 5 then
            cur_obj_play_sound_2(SOUND_GENERAL_BOX_LANDING_2)
        elseif parallelLength > 3 then
            cur_obj_play_sound_2(SOUND_ENV_SLIDING)
        end

        local pushOutMag = 10

        -- reflect velocity along normal
        local reflect = {
            x = parallel.x - perpendicular.x,
            y = parallel.y - perpendicular.y,
            z = parallel.z - perpendicular.z
        }

        -- set new velocity
        obj.oVelX = reflect.x + differenceDir.x * pushOutMag
        obj.oVelY = reflect.y + differenceDir.y * pushOutMag
        obj.oVelZ = reflect.z + differenceDir.z * pushOutMag
    end

    return alterPos
end

--- @param obj Object
--- @param offset Vec3f
function bhv_ball_resolve(obj, offset)
    local a   = { x = obj.oPosX + 0, y = obj.oPosY + 0, z = obj.oPosZ + 0 }
    local dir = { x = offset.x * -1.0, y = offset.y * -1.0, z = offset.z * -1.0 }

    info = collision_find_surface_on_ray(
        a.x, a.y, a.z,
        dir.x, dir.y, dir.z)

    obj.oPosX = info.hitPos.x + offset.x
    obj.oPosY = info.hitPos.y + offset.y
    obj.oPosZ = info.hitPos.z + offset.z

    if info.surface == nil then return nil end
    return { x = info.surface.normal.x, y = info.surface.normal.y, z = info.surface.normal.z }
end

--- @param obj Object
function bhv_ball_loop(obj)
    if obj.oFrozen ~= 0 then
        return
    end

    gBallTouchedLocal = false
    local cb = get_cached_ball(obj)

    -- detect when a packet was received
    if obj.oNetworkTime ~= cb.oNetworkTime then
        if should_reject_packet(obj) then
            -- reject packet
            obj.oGlobalOwner = cb.oGlobalOwner
            obj.oHitTime = cb.oHitTime
            obj.oNetworkTime = cb.oNetworkTime
            obj.oPosX = cb.oPosX
            obj.oPosY = cb.oPosY
            obj.oPosZ = cb.oPosZ
            obj.oVelX = cb.oVelX
            obj.oVelY = cb.oVelY
            obj.oVelZ = cb.oVelZ
        end
    end

    local orig = { x = obj.oPosX, y = obj.oPosY, z = obj.oPosZ }

    obj.oVelY = obj.oVelY - ballGravity
    if obj.oVelX == 0 and obj.oVelY == 0 and obj.oVelZ == 0 then
        obj.oVelY = obj.oVelY + 0.01
    end


    -- detect player collisions
    local alterPos = bhv_ball_player_collision(obj)

    -- alter end-point based on player collisions
    local a = { x = obj.oPosX, y = obj.oPosY, z = obj.oPosZ }
    local v = { x = obj.oVelX, y = obj.oVelY, z = obj.oVelZ }
    local b = { x = v.x, y = v.y, z = v.z }
    vec3f_sum(b, b, alterPos)

    -- regular movement
    local info = collision_find_surface_on_ray(
        a.x, a.y, a.z,
        b.x, b.y, b.z)

    obj.oPosX = info.hitPos.x
    obj.oPosY = info.hitPos.y
    obj.oPosZ = info.hitPos.z

    -- detect normal along movement vector
    local vMag = vec3f_length(v)
    if vMag > 0 then
        local vNorm = { x = v.x / vMag, y = v.y / vMag, z = v.z / vMag }
        b = { x = v.x + vNorm.x * (vMag + ballRadius), y = v.y + vNorm.y * (vMag + ballRadius),
            z = v.z + vNorm.z * (vMag + ballRadius) }
    end

    info = collision_find_surface_on_ray(
        a.x, a.y, a.z,
        b.x, b.y, b.z)

    -- figure out the standard normal
    local colNormals = {}
    if info.surface ~= nil then
        table.insert(colNormals, { x = info.surface.normal.x, y = info.surface.normal.y, z = info.surface.normal.z })
        if vMag > 5 then
            bhv_ball_particle_bounce(obj)
        end
    else
        table.insert(colNormals, nil)
    end

    -- resolve collisions around ball
    table.insert(colNormals, bhv_ball_resolve(obj, { x = ballRadius, y = 0, z = 0 }))
    table.insert(colNormals, bhv_ball_resolve(obj, { x = -ballRadius, y = 0, z = 0 }))
    table.insert(colNormals, bhv_ball_resolve(obj, { x = 0, y = 0, z = ballRadius }))
    table.insert(colNormals, bhv_ball_resolve(obj, { x = 0, y = 0, z = -ballRadius }))
    table.insert(colNormals, bhv_ball_resolve(obj, { x = 0, y = ballRadius, z = 0 }))
    table.insert(colNormals, bhv_ball_resolve(obj, { x = 0, y = -ballRadius, z = 0 }))

    -- figure out collision normal
    local collisionN = { x = 0, y = 0, z = 0 }
    local collisionCount = 0
    for _, colN in ipairs(colNormals) do
        if colN ~= nil then
            vec3f_sum(collisionN, collisionN, colN)
            collisionCount = collisionCount + 1
        end
    end

    -- reflect collisions
    if collisionCount > 0 then
        -- calculate total normal
        vec3f_mul(collisionN, 1.0 / collisionCount)
        vec3f_normalize(collisionN)

        -- split velocity into parallel/perpendicular to normal
        local perpendicular = vec3f_project(v, collisionN)
        local parallel = { x = v.x - perpendicular.x, y = v.y - perpendicular.y, z = v.z - perpendicular.z }

        -- apply friction and restitution
        vec3f_mul(parallel, ballFriction)
        vec3f_mul(perpendicular, ballRestitution)

        -- stop ball in parallel axis
        local parallelLength = vec3f_length(parallel)
        if parallelLength < ballParallelInertia then
            vec3f_mul(parallel, 0)
        end

        -- stop ball in perpendicular axis
        local perpendicularLength = vec3f_length(perpendicular)
        if perpendicularLength < ballPerpendicularInertia then
            vec3f_mul(perpendicular, 0)
        end

        -- play sounds
        if perpendicularLength > 5 then
            cur_obj_play_sound_2(SOUND_GENERAL_BOX_LANDING_2)
        elseif parallelLength > 3 then
            cur_obj_play_sound_2(SOUND_ENV_SLIDING)
        end

        -- reflect velocity along normal
        local reflect = {
            x = parallel.x - perpendicular.x,
            y = parallel.y - perpendicular.y,
            z = parallel.z - perpendicular.z
        }

        -- set new velocity
        obj.oVelX = reflect.x
        obj.oVelY = reflect.y
        obj.oVelZ = reflect.z
    end

    -- float in water
    local waterLevel = find_water_level(obj.oPosX, obj.oPosZ)
    if obj.oPosY < waterLevel then
        obj.oVelX = obj.oVelX * ballWaterDrag
        obj.oVelY = obj.oVelY * ballWaterDrag + 2
        obj.oVelZ = obj.oVelZ * ballWaterDrag
    end

    -- sanity check floor
    local floor = find_floor_height(obj.oPosX, obj.oPosY, obj.oPosZ)
    if obj.oPosY <= floor or floor <= -10000 then
        obj.oPosX = orig.x
        obj.oPosY = orig.y
        obj.oPosZ = orig.z
        obj.oVelX = -obj.oVelX
        obj.oVelY = -obj.oVelY
        obj.oVelZ = -obj.oVelZ
    end

    -- update rotation
    if obj.oVelX ~= 0 or obj.oVelZ ~= 0 then
        local moveAngle = atan2s(obj.oVelZ * 100, obj.oVelX * 100)
        local xzMag = math.sqrt(obj.oVelX * obj.oVelX + obj.oVelZ * obj.oVelZ)
        obj.oFaceAngleYaw = moveAngle
        obj.oFaceAnglePitch = obj.oFaceAnglePitch + xzMag * 100
    end

    -- send out object if we touched it
    local updateRateSend = (obj.oGlobalOwner == my_global_index() and (get_network_area_timer() - obj.oNetworkTime) > 5)
    if gBallTouchedLocal or updateRateSend then
        if gBallTouchedLocal then
            obj.oGlobalOwner = my_global_index()
            obj.oHitTime = get_network_area_timer()
        end
        obj.oNetworkTime = get_network_area_timer()
        network_send_object(obj, false)
    end

    -- spawn a particle trail
    if vMag > 50 then
        bhv_ball_particle_trail(obj)
    end

    -- hack: make sure we never set velocity to nan
    if obj.oVelX ~= obj.oVelX then obj.oVelX = 0 end
    if obj.oVelY ~= obj.oVelY then obj.oVelY = 0 end
    if obj.oVelZ ~= obj.oVelZ then obj.oVelZ = 0 end

    -- hack: save pos/vel to detect packets
    cb.oGlobalOwner = obj.oGlobalOwner
    cb.oHitTime = obj.oHitTime
    cb.oNetworkTime = obj.oNetworkTime
    cb.oPosX = obj.oPosX
    cb.oPosY = obj.oPosY
    cb.oPosZ = obj.oPosZ
    cb.oVelX = obj.oVelX
    cb.oVelY = obj.oVelY
    cb.oVelZ = obj.oVelZ
end

id_bhvBall = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_ball_init, bhv_ball_loop)
