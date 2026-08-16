-- client/godmode.lua
-- Vehicles take no damage. Applied to EVERY vehicle in scope (yours, parked,
-- other players', race, freeroam). Cars still bump/push physically — they just
-- never break, deform, catch fire, or lose performance.
--
-- Everything is re-applied on a short tick, not once, because several things
-- reset these flags: the race grid-unfreeze (SPZ:freezeRacer at GO sets
-- invincible=false), vehicle re-streaming, and network-owner changes. Cheap
-- enough at 250 ms.

local GODMODE = true   -- set false to let vehicles take damage
if Config and Config.VehicleGodmode == false then GODMODE = false end

local function protect(veh)
    -- damage gate (most reliable — survives owner changes)
    SetEntityCanBeDamaged(veh, false)
    SetEntityInvincible(veh, true)
    SetEntityProofs(veh, true, true, true, true, true, true, true, true)

    -- component breakage
    SetVehicleTyresCanBurst(veh, false)
    SetVehicleWheelsCanBreak(veh, false)
    SetVehicleCanBeVisiblyDamaged(veh, false)
    SetVehicleEngineCanDegrade(veh, false)
    SetVehicleStrong(veh, true)

    -- pin health so anything that slipped through is repaired instantly
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDeformationFixed(veh)
end

CreateThread(function()
    while true do
        if GODMODE then
            -- Protect EVERY vehicle in scope, not just the one we're driving —
            -- so parked / exited / other players' cars never take visual or
            -- engine damage either. The car we're in is refreshed most often.
            local mine = GetVehiclePedIsIn(PlayerPedId(), false)
            if mine ~= 0 and DoesEntityExist(mine) then protect(mine) end

            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if veh ~= mine and DoesEntityExist(veh) then protect(veh) end
            end
            Wait(500)
        else
            Wait(1500)
        end
    end
end)
