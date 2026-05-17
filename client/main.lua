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

-- New Vehicle Functions State
local cruiseSpeed        = 0.0
local isEngineRunning    = true
local engineStarting     = false
local lastBrakePulse     = 0
local brakePulseState    = false

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
    leftOn          = false
    rightOn         = false
    hazardsOn       = false
    blinkState      = false
    cruiseSpeed     = 0.0
    engineStarting  = false
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

-- Unflash headlights
RegisterCommand('-vehfunc_flashHeadlights', function()
    local _, veh = inDriverSeat()
    if veh and veh ~= 0 then
        SetVehicleFullbeam(veh, false)
    end
end, false)

-- Toggle Cruise Control
RegisterCommand('vehfunc_toggleCruise', function()
    local ok, veh = inDriverSeat()
    if not ok then return end
    
    if not isEngineRunning then
        Notify("Engine is not running", "error")
        return
    end
    
    if cruiseSpeed > 0.0 then
        cruiseSpeed = 0.0
        Notify("Cruise Control Disabled", "error")
    else
        local speed = GetEntitySpeed(veh)
        local speedKmh = speed * 3.6
        if speedKmh < 20.0 then
            Notify("Speed too low for Cruise Control (Min 20 km/h)", "error")
        else
            cruiseSpeed = speed
            Notify(string.format("Cruise Control Locked: %.0f km/h", speedKmh), "success")
        end
    end
end, false)

-- Toggle Engine Ignition
RegisterCommand('vehfunc_toggleEngine', function()
    local ok, veh = inDriverSeat()
    if not ok or engineStarting then return end
    
    if GetIsVehicleEngineRunning(veh) then
        isEngineRunning = false
        SetVehicleEngineOn(veh, false, false, true)
        Notify("Engine Off", "error")
    else
        engineStarting = true
        Notify("Starting engine...", "info")
        
        -- Crank simulation timer (runs in command thread)
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 800 do
            if not inDriverSeat() then
                engineStarting = false
                return
            end
            SetVehicleEngineOn(veh, false, false, true)
            Wait(100)
        end
        
        isEngineRunning = true
        engineStarting = false
        SetVehicleEngineOn(veh, true, false, true)
        Notify("Engine Started", "success")
    end
end, false)

-- Key Mappings
RegisterKeyMapping('vehfunc_leftSignal',       'Left Indicator',       'keyboard', 'LEFT')
RegisterKeyMapping('vehfunc_rightSignal',       'Right Indicator',      'keyboard', 'RIGHT')
RegisterKeyMapping('vehfunc_hazards',           'Hazard Lights',        'keyboard', 'H')
RegisterKeyMapping('+vehfunc_flashHeadlights',  'Flash Headlights',     'keyboard', 'L')
RegisterKeyMapping('vehfunc_toggleCruise',      'Toggle Cruise Control','keyboard', 'C')
RegisterKeyMapping('vehfunc_toggleEngine',      'Toggle Engine Ignition','keyboard', 'Y')

-- ── Main thread ───────────────────────────────────────────────────────────────

local lastVeh = 0

CreateThread(function()
    while true do
        local ok, veh = inDriverSeat()

        if ok then
            local now = GetGameTimer()
            
            -- Sync engine state on vehicle swap
            if veh ~= lastVeh then
                lastVeh = veh
                isEngineRunning = GetIsVehicleEngineRunning(veh)
                cruiseSpeed = 0.0
            end

            -- 1. Blinker timing
            local nextChange = blinkState and BLINK_ON_MS or BLINK_OFF_MS
            if now - lastBlink >= nextChange then
                lastBlink  = now
                blinkState = not blinkState
            end

            applyLights(veh)

            -- 2. Auto-cancel indicators on steering
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

            -- 3. Engine Ignition Enforcement
            if not isEngineRunning and not engineStarting then
                SetVehicleEngineOn(veh, false, true, true)
            end

            -- 4. Emergency Brake Light Pulse
            local speedKmh = GetEntitySpeed(veh) * 3.6
            local isEmergencyBrake = IsControlPressed(0, 72) and speedKmh > 80.0
            if isEmergencyBrake then
                if now - lastBrakePulse > 120 then -- Rapid 120ms flash (approx 4 times per second)
                    lastBrakePulse = now
                    brakePulseState = not brakePulseState
                end
                SetVehicleBrakeLights(veh, brakePulseState)
            end

            -- 5. Active Cruise Control
            if cruiseSpeed > 0.0 then
                -- Disable cruise if braking, handbraking, or vehicle is stopping
                if IsControlPressed(0, 72) or IsControlPressed(0, 76) or speedKmh < 10.0 then
                    cruiseSpeed = 0.0
                    Notify("Cruise Control Canceled", "error")
                else
                    SetVehicleForwardSpeed(veh, cruiseSpeed)
                end
            end

            Wait(10)
        else
            resetAll(veh)
            lastVeh = 0
            cruiseSpeed = 0.0
            Wait(500)
        end
    end
end)
