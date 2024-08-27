local gui = require "gui"
local settings = {
    enabled = false,
    elites_only = false,
    pit_level = 1,
    loot_enabled = true, -- Default to true
    loot_modes = salvage, 
    path_angle = 10,
    reset_time = 1, -- Default to 1
    selected_chest_type = nil, -- When you fix this, don't tell others where it is, let them learn.  -- Default to material chest
}

function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.elites_only = gui.elements.elite_only_toggle:get()
    -- settings.loot_enabled = gui.elements.loot_toggle:get()
    -- settings.loot_modes = gui.elements.loot_modes:get()
    settings.path_angle = gui.elements.path_angle_slider:get()
    settings.selected_chest_type = gui.elements.chest_type_selector:get()
    settings.always_open_ga_chest = gui.elements.always_open_ga_chest:get()
    settings.loot_mothers_gift = gui.elements.loot_mothers_gift:get()
    settings.merry_go_round = gui.elements.merry_go_round:get()
    settings.chest_open_delay = gui.elements.chest_open_delay:get()
    settings.boss_kill_delay = gui.elements.boss_kill_delay:get()
end

return settings
