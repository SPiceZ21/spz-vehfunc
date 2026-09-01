-- SPiceZ Vehicle Functions — indicators, hazards, flash headlights

-- State
local leftOn    = false
local rightOn   = false
local hazardsOn = false

-- Real relay-style flasher: even ~1.4 Hz (on time == off time)
local BLINK_MS   = 350
local blinkState = false
local lastBlink  = 0
local steerTriggered = false

-- Emergency brake pulse
local lastBrakePulse  = 0
local brakePulseState = false

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function inDriverSeat()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    return veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped, veh
end

local function applyLights(veh)
    if hazardsOn then
        SetVehicleIndicatorLights(veh, 0, blinkState)
        SetVehicleIndicatorLights(veh, 1, blinkState)
    elseif leftOn then
        SetVehicleIndicatorLights(veh, 0, blinkState)
        SetVehicleIndicatorLights(veh, 1, false)
    elseif rightOn then
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, blinkState)
    else
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
    end
end

local function resetAll(veh)
    leftOn         = false
    rightOn        = false
    hazardsOn      = false
    blinkState     = false
    steerTriggered = false
    if veh and veh ~= 0 then
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
    end
end

-- ── Commands / Key bindings ───────────────────────────────────────────────────

-- Left indicator
RegisterCommand('vehfunc_leftSignal', function()
    local ok, veh = inDriverSeat()
    if not ok then return end
    if rightOn then
        rightOn = false
        SetVehicleIndicatorLights(veh, 1, false)
    end
    hazardsOn = false
    leftOn = not leftOn
    steerTriggered = false
    -- Light immediately, then flash evenly (real cars turn on at once)
    if leftOn then
        blinkState = true
        lastBlink  = GetGameTimer()
    else
        SetVehicleIndicatorLights(veh, 0, false)
    end
end, false)

-- Right indicator
RegisterCommand('vehfunc_rightSignal', function()
    local ok, veh = inDriverSeat()
    if not ok then return end
    if leftOn then
        leftOn = false
        SetVehicleIndicatorLights(veh, 0, false)
    end
    hazardsOn = false
    rightOn = not rightOn
    steerTriggered = false
    if rightOn then
        blinkState = true
        lastBlink  = GetGameTimer()
    else
        SetVehicleIndicatorLights(veh, 1, false)
    end
end, false)

-- Hazard lights
RegisterCommand('vehfunc_hazards', function()
    local ok, veh = inDriverSeat()
    if not ok then return end
    leftOn    = false
    rightOn   = false
    hazardsOn = not hazardsOn
    if hazardsOn then
        blinkState = true
        lastBlink  = GetGameTimer()
    else
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
    end
end, false)

-- Flash headlights (hold)
RegisterCommand('+vehfunc_flashHeadlights', function()
    local ok, veh = inDriverSeat()
    if not ok then return end
    SetVehicleFullbeam(veh, true)
end, false)

RegisterCommand('-vehfunc_flashHeadlights', function()
    local _, veh = inDriverSeat()
    if veh and veh ~= 0 then
        SetVehicleFullbeam(veh, false)
    end
end, false)

-- Key Mappings — registry: Docs/keybinds.md
RegisterKeyMapping('vehfunc_leftSignal',       'Left Indicator',   'keyboard', 'LEFT')
RegisterKeyMapping('vehfunc_rightSignal',      'Right Indicator',  'keyboard', 'RIGHT')
-- NOT H: that is GTA's own headlights toggle, so hazards flipped the lights too.
RegisterKeyMapping('vehfunc_hazards',          'Hazard Lights',    'keyboard', 'J')
RegisterKeyMapping('+vehfunc_flashHeadlights', 'Flash Headlights', 'keyboard', 'L')

-- ── Main thread ───────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local ok, veh = inDriverSeat()

        if ok then
            local now = GetGameTimer()

            -- 1. Even flasher cadence (symmetric on/off — natural rhythm)
            if leftOn or rightOn or hazardsOn then
                if now - lastBlink >= BLINK_MS then
                    lastBlink  = now
                    blinkState = not blinkState
                end
                applyLights(veh)
            end

            -- 2. Auto-cancel indicators after a turn (steering-column relay feel)
            if not hazardsOn and (leftOn or rightOn) then
                local steer = GetVehicleSteeringAngle(veh)  -- + left, - right
                if leftOn then
                    if steer > 15.0 then
                        steerTriggered = true
                    elseif steerTriggered and steer < 5.0 then
                        leftOn = false
                        steerTriggered = false
                        SetVehicleIndicatorLights(veh, 0, false)
                    end
                elseif rightOn then
                    if steer < -15.0 then
                        steerTriggered = true
                    elseif steerTriggered and steer > -5.0 then
                        rightOn = false
                        steerTriggered = false
                        SetVehicleIndicatorLights(veh, 1, false)
                    end
                end
            end

            -- 3. Emergency brake-light pulse (hard braking at speed)
            local speedKmh = GetEntitySpeed(veh) * 3.6
            if IsControlPressed(0, 72) and speedKmh > 80.0 then
                if now - lastBrakePulse > 120 then
                    lastBrakePulse  = now
                    brakePulseState = not brakePulseState
                end
                SetVehicleBrakeLights(veh, brakePulseState)
            end

            Wait(10)
        else
            resetAll(veh)
            Wait(500)
        end
    end
end)
