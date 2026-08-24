-- client/taunts.lua
-- Clip fuel: a one-key horn+light taunt for the car, and a small set of on-foot
-- celebration emotes. Small feature, big for the highlight reel.

local function inDriverSeat()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then return true, veh end
    return false, 0
end

-- ── Horn + light taunt (double beep + high-beam flash) ───────────────────────
local _tauntBusy = false

RegisterCommand('taunt_horn', function()
    local ok, veh = inDriverSeat()
    if not ok or _tauntBusy then return end
    _tauntBusy = true
    CreateThread(function()
        for _ = 1, 2 do
            SetVehicleFullbeam(veh, true)
            StartVehicleHorn(veh, 170, 'HELDDOWN', false)
            Wait(170)
            SetVehicleFullbeam(veh, false)
            Wait(110)
        end
        _tauntBusy = false
    end)
end, false)

RegisterKeyMapping('taunt_horn', 'Horn Taunt (beep + flash)', 'keyboard', 'G')

-- ── On-foot emotes (reliable scenarios) ──────────────────────────────────────
local EMOTES = {
    cheer = "WORLD_HUMAN_CHEERING",       -- fists-up celebration
    flex  = "WORLD_HUMAN_MUSCLE_FLEX",    -- bodybuilder flex
    smoke = "WORLD_HUMAN_SMOKING",        -- cool-guy smoke
    guard = "WORLD_HUMAN_GUARD_STAND",    -- arms crossed, unbothered
}

local function emoteList()
    local t = {}
    for k in pairs(EMOTES) do t[#t + 1] = k end
    table.sort(t)
    return table.concat(t, ", ")
end

RegisterCommand('emote', function(_, args)
    local ped  = PlayerPedId()
    local name = (args[1] or ""):lower()

    if name == "" or name == "stop" or name == "cancel" then
        ClearPedTasks(ped)
        return
    end

    local scenario = EMOTES[name]
    if not scenario then
        lib.notify({ description = "Emotes: " .. emoteList() .. "  (/emote stop to cancel)", type = "inform" })
        return
    end
    if IsPedInAnyVehicle(ped, false) then
        lib.notify({ description = "Get out of the car to emote", type = "warning" })
        return
    end

    TaskStartScenarioInPlace(ped, scenario, 0, true)
end, false)

-- Any movement input cancels the current emote so you're never stuck in it.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedUsingAnyScenario(ped) then
            if IsControlPressed(0, 32) or IsControlPressed(0, 33)      -- W / S
                or IsControlPressed(0, 34) or IsControlPressed(0, 35)  -- A / D
                or IsControlPressed(0, 22) then                        -- jump
                ClearPedTasks(ped)
            end
            Wait(100)
        else
            Wait(500)
        end
    end
end)
