-- client/idlecam.lua
-- Replaces GTA's stock idle camera with a Crew-2-style cinematic orbit around
-- your car. The default idle cam is suppressed continuously; after IDLE_DELAY of
-- no input — and only while parked in a vehicle, outside races/menus — a scripted
-- camera slowly orbits the car with gentle rise/fall and shallow DOF. Any input
-- (steer, throttle, look, key) drops it instantly.

local ENABLED    = true
local IDLE_DELAY = 8000     -- ms of no input before the reel starts
local FOV        = 40.0
local LOOK_DZ    = 0.03     -- mouse/stick deadzone that counts as "looking"

-- Cinematic shot reel. Each shot SLOWLY dollies the camera from `a` to `b` —
-- VEHICLE-LOCAL offsets in metres (+y front, -y rear, +x right, -x left, +z up)
-- — aiming at the car + `look` offset, at `fov` (tighter = more compressed /
-- close-up feel). Shots cross-blend into one another (SetCamActiveWithInterp),
-- so there are no hard cuts. Order shuffles each cycle. Small A→B deltas + long
-- durations = slow, smooth, deliberate moves.
local BLEND = 1600   -- ms cross-blend between shots

local SHOTS = {
    -- ── Close-up detail ──
    { name="badge_front",  a={ 0.0, 3.7,0.55}, b={ 0.0, 3.15,0.60}, look={ 0.0, 4.4,0.50}, fov=30.0, dur=7000 },
    { name="headlight",    a={ 2.05,3.2,0.55}, b={ 1.7, 3.45,0.58}, look={ 2.5, 3.7,0.42}, fov=31.0, dur=6500 },
    { name="tail_macro",   a={ 1.35,-3.6,0.72},b={ 0.8,-3.95,0.76}, look={ 1.2,-2.5,0.60}, fov=31.0, dur=7000 },
    { name="wheel_front",  a={ 2.7, 2.3,0.32}, b={ 2.5, 2.7,0.42},  look={ 1.2, 1.9,0.26}, fov=33.0, dur=6500 },
    { name="mirror",       a={ 2.35,1.2,1.0},  b={ 2.2, 1.55,1.05}, look={ 0.9, 1.25,0.90},fov=32.0, dur=6000 },
    { name="low_nose",     a={ 0.5, 5.4,0.24}, b={-0.5, 5.6,0.30},  look={ 0.0, 1.2,0.60}, fov=36.0, dur=7500 },
    -- ── Hero / wide cinematic ──
    { name="side_profile", a={-5.7,-2.8,1.0},  b={-5.5, 3.0,1.15},  look={ 0.0, 0.0,0.60}, fov=40.0, dur=9500 },
    { name="front_34",     a={ 4.1, 4.9,1.10}, b={ 2.7, 5.3,0.95},  look={ 0.0, 0.5,0.55}, fov=39.0, dur=8500 },
    { name="rear_34",      a={-4.1,-5.0,1.15}, b={-2.4,-5.5,1.0},   look={ 0.0,-0.4,0.60}, fov=39.0, dur=8000 },
    { name="high_reveal",  a={ 3.2,-3.4,3.2},  b={-3.2,-3.0,3.0},   look={ 0.0, 0.0,0.35}, fov=45.0, dur=9500 },
}

local cam       = nil
local orbiting  = false
local curVeh    = 0
local order     = {}         -- shuffled shot order
local shotIdx   = 1
local shotStart = 0
local lastInput = GetGameTimer()

-- Controls whose activity means "the player is doing something" → not idle.
local INPUT_CONTROLS = {
    30, 31,        -- move LR / UD (on foot)
    59, 60,        -- vehicle steer LR / UD
    71, 72,        -- vehicle accelerate / brake
    75, 23,        -- exit / enter vehicle
    21, 22, 24,    -- sprint / jump / attack
    44, 38, 45,    -- cover / interact / reload
    47, 74,        -- detonate / headlight
    19, 20, 199,   -- char wheel / info / pause
    15, 14,        -- weapon wheel up/down (mouse scroll)
}

local function anyInput()
    if math.abs(GetControlNormal(0, 1)) > LOOK_DZ then return true end   -- look LR
    if math.abs(GetControlNormal(0, 2)) > LOOK_DZ then return true end   -- look UD
    for _, c in ipairs(INPUT_CONTROLS) do
        if IsControlPressed(0, c) or IsDisabledControlPressed(0, c) then return true end
    end
    if curVeh ~= 0 and DoesEntityExist(curVeh) and GetEntitySpeed(curVeh) > 0.5 then return true end
    return false
end

local function canStart()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    if LocalPlayer.state.inRace then return false end
    if _G.SPZ_InTimeTrial then return false end
    if IsPauseMenuActive() or IsNuiFocused() then return false end
    if GetEntitySpeed(veh) > 0.5 then return false end
    return true, veh
end

local function canStay()
    if IsPauseMenuActive() or IsNuiFocused() then return false end
    if LocalPlayer.state.inRace or _G.SPZ_InTimeTrial then return false end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    return veh ~= 0 and veh == curVeh
end

local function _shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Build a cam already framed at a shot's start pose, with mild DOF.
local function _mkCam(veh, shot)
    local c = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(c, shot.fov or FOV)
    local p = GetOffsetFromEntityInWorldCoords(veh, shot.a[1], shot.a[2], shot.a[3])
    local l = GetOffsetFromEntityInWorldCoords(veh, shot.look[1], shot.look[2], shot.look[3])
    SetCamCoord(c, p.x, p.y, p.z)
    PointCamAtCoord(c, l.x, l.y, l.z)
    -- Mild DOF: subtle background softening, car stays sharp.
    SetCamUseShallowDofMode(c, true)
    SetCamNearDof(c, 1.0)
    SetCamFarDof(c, 30.0)
    SetCamDofStrength(c, 0.32)
    SetCamDofFnumberOfLens(c, 9.0)
    return c
end

local function startOrbit(veh)
    curVeh = veh
    order = {}
    for i = 1, #SHOTS do order[i] = i end
    _shuffle(order)
    shotIdx   = 1
    shotStart = GetGameTimer()

    cam = _mkCam(veh, SHOTS[order[1]])
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1200, true, true)
    orbiting = true
end

local function stopOrbit()
    orbiting = false
    if cam then
        RenderScriptCams(false, true, 800, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    curVeh = 0
    lastInput = GetGameTimer()
end

local function _smooth(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)   -- smootherstep: zero accel at ends
end

local function updateOrbit()
    if not curVeh or curVeh == 0 or not DoesEntityExist(curVeh) then stopOrbit(); return end

    local shot    = SHOTS[order[shotIdx]]
    local elapsed = GetGameTimer() - shotStart
    local t = elapsed / shot.dur
    if t >= 1.0 then
        -- Advance to the next shot; reshuffle when the reel wraps. Cross-blend
        -- into it (SetCamActiveWithInterp) so the transition is smooth, not a cut.
        local ni = shotIdx + 1
        if ni > #order then _shuffle(order); ni = 1 end
        shotIdx   = ni
        shotStart = GetGameTimer()
        shot      = SHOTS[order[shotIdx]]

        local newCam = _mkCam(curVeh, shot)
        SetCamActiveWithInterp(newCam, cam, BLEND, 1, 1)
        local old = cam
        cam = newCam
        SetTimeout(BLEND + 250, function()
            if old and old ~= cam and DoesCamExist(old) then DestroyCam(old, false) end
        end)
        elapsed = 0
    end

    -- Hold at the shot's start pose during the cross-blend, THEN dolly a→b over
    -- the remainder. Keeps the blend a pure eased move with no compound motion.
    local dp = (elapsed - BLEND) / (shot.dur - BLEND)
    local e  = _smooth(dp)
    local ox = shot.a[1] + (shot.b[1] - shot.a[1]) * e
    local oy = shot.a[2] + (shot.b[2] - shot.a[2]) * e
    local oz = shot.a[3] + (shot.b[3] - shot.a[3]) * e

    local p = GetOffsetFromEntityInWorldCoords(curVeh, ox, oy, oz)
    local l = GetOffsetFromEntityInWorldCoords(curVeh, shot.look[1], shot.look[2], shot.look[3])
    SetCamCoord(cam, p.x, p.y, p.z)
    PointCamAtCoord(cam, l.x, l.y, l.z)
    SetUseHiDof()
end

-- ── Suppress the stock idle cam ──────────────────────────────────────────────
CreateThread(function()
    while true do
        InvalidateIdleCam()          -- on-foot / general idle cinematic
        InvalidateVehicleIdleCam()   -- the in-vehicle idle pan
        Wait(1000)
    end
end)

-- ── Idle detection + orbit ───────────────────────────────────────────────────
CreateThread(function()
    while true do
        if not ENABLED then
            if orbiting then stopOrbit() end
            Wait(1000)
        elseif orbiting then
            if anyInput() or not canStay() then
                stopOrbit()
            else
                updateOrbit()
            end
            Wait(0)
        else
            if anyInput() then lastInput = GetGameTimer() end
            if (GetGameTimer() - lastInput) >= IDLE_DELAY then
                local ok, veh = canStart()
                if ok then startOrbit(veh) end
            end
            Wait(100)
        end
    end
end)

-- ── Toggle ───────────────────────────────────────────────────────────────────
RegisterCommand("idlecam", function()
    ENABLED = not ENABLED
    if not ENABLED and orbiting then stopOrbit() end
    lib.notify({ description = ("Cinematic idle cam: %s"):format(ENABLED and "ON" or "OFF"),
                 type = ENABLED and "success" or "warning" })
end, false)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() and orbiting then stopOrbit() end
end)
