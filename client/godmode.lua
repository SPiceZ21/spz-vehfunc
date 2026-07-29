-- client/godmode.lua
-- Vehicles take no damage by default. Applied to whatever vehicle the local
-- player is in — spawned, race, freeroam. Cosmetic scuffs and physics are
-- untouched (cars still bump and push); they just never break, deform, catch
-- fire, or lose performance.
--
-- Toggle off with Config.VehicleGodmode = false (see below).

local GODMODE = true   -- default ON; set false to let vehicles take damage

-- One-time flags per vehicle (cheap — set once when you enter it).
local function harden(veh)
    SetVehicleTyresCanBurst(veh, false)
    SetVehicleWheelsCanBreak(veh, false)
    SetVehicleCanBeVisiblyDamaged(veh, false)
    SetVehicleEngineCanDegrade(veh, false)
    SetVehicleStrong(veh, true)          -- resists deformation
end

-- Re-asserted every tick: invincibility + health. Must repeat because the
-- race grid-unfreeze (SPZ:freezeRacer at GO) sets invincible=false, which
-- would otherwise strip godmode mid-race.
local function topUp(veh)
    SetEntityInvincible(veh, true)
    SetEntityProofs(veh, true, true, true, true, true, true, true, true)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
end

CreateThread(function()
    local hardened = 0   -- vehicle handle we've already hardened this stint
    while true do
        if not GODMODE then
            hardened = 0
            Wait(1000)
        else
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and DoesEntityExist(veh) then
                if veh ~= hardened then
                    harden(veh)
                    hardened = veh
                end
                topUp(veh)
                Wait(500)
            else
                hardened = 0
                Wait(750)
            end
        end
    end
end)

-- Honour a config override if spz-vehfunc ever gains a Config table.
if Config and Config.VehicleGodmode == false then GODMODE = false end
