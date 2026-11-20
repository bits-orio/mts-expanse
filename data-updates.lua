if not mods['space-age'] then return end
-- Native hatches accept explicit pod prototypes. Preserve vanilla pods and
-- allow the larger mission-only batches, including attached cargo bays.
local function allow_reward_pods(hatches)
    for _, hatch in pairs(hatches or {}) do
        for _, name in ipairs(hatch.receiving_cargo_units or {}) do
            if name == 'cargo-pod' then
                table.insert(hatch.receiving_cargo_units, 'mts-expanse-reward-pod')
                break
            end
        end
    end
end
for _, prototype in pairs(data.raw['cargo-landing-pad']) do
    local station = prototype.cargo_station_parameters
    allow_reward_pods(station and station.hatch_definitions)
end
for _, prototype in pairs(data.raw['cargo-bay']) do
    allow_reward_pods(prototype.hatch_definitions)
end

-- Mission rockets carry what the startup setting says. Players cannot build
-- rocket silos in Expanse, so every silo in the game is a mission silo. One
-- tonne is the game's own default and leaves the prototype untouched.
local lift_tonnes = tonumber(settings.startup['mts-expanse-mission-rocket-lift'].value) or 1
if lift_tonnes > 1 then
    data.raw['rocket-silo']['rocket-silo'].lift_weight = lift_tonnes * 1000000
end
