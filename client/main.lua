-- SPiceZ Vehicle Functions

local function Notify(msg, type)
    exports["spz-lib"]:Notify(msg, type or "info")
end

-- State
local leftOn    = false
local rightOn   = false
local hazardsOn = false

local blinkState     = false
local lastBlink      = 0
local BLINK_ON_MS    = 380  -- Duration blinkers stay ON
local BLINK_OFF_MS   = 280  -- Duration blinkers stay OFF (the gap)
local steerTriggered = false

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
    leftOn    = false
    rightOn   = false
    hazardsOn = false
    blinkState = false
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
    if not leftOn then SetVehicleIndicatorLights(veh, 0, false) end
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
    if not rightOn then SetVehicleIndicatorLights(veh, 1, false) end
end, false)

-- Hazard lights
RegisterCommand('vehfunc_hazards', function()
    local ok, veh = inDriverSeat()
    if not ok then return end
    leftOn    = false
    rightOn   = false
    hazardsOn = not hazardsOn
    if not hazardsOn then
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

RegisterKeyMapping('vehfunc_leftSignal',       'Left Indicator',       'keyboard', 'LEFT')
RegisterKeyMapping('vehfunc_rightSignal',       'Right Indicator',      'keyboard', 'RIGHT')
RegisterKeyMapping('vehfunc_hazards',           'Hazard Lights',        'keyboard', 'H')
RegisterKeyMapping('+vehfunc_flashHeadlights',  'Flash Headlights',     'keyboard', 'L')

-- ── Main blink thread ─────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local ok, veh = inDriverSeat()

        if ok then
            local now = GetGameTimer()
            local nextChange = blinkState and BLINK_ON_MS or BLINK_OFF_MS
            if now - lastBlink >= nextChange then
                lastBlink  = now
                blinkState = not blinkState
            end

            applyLights(veh)

            -- Auto-cancel single indicator when steering back past threshold
            if not hazardsOn then
                if leftOn or rightOn then
                    local steer = GetVehicleSteeringAngle(veh)
                    -- Steering angle: positive (left), negative (right)
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
                else
                    steerTriggered = false
                end
            end

            Wait(10)
        else
            resetAll(veh)
            Wait(500)
        end
    end
end)
