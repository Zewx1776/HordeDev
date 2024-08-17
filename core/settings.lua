local gui = require "gui"
local settings = {
    enabled = false,
    elites_only = false,
    pit_level = 1,
    loot_enabled = true, -- Default to true
    path_angle = 10,
    reset_time = 1, -- Default to 1
    selected_chest_type = nil, -- When you fix this, don't tell others where it is, let them learn.  -- Default to material chest
    chest_opening_time = 30 -- default value
}

function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.elites_only = gui.elements.elite_only_toggle:get()
    settings.loot_enabled = gui.elements.loot_toggle:get()
    settings.loot_modes = gui.elements.loot_modes:get()
    settings.path_angle = gui.elements.path_angle_slider:get()
    settings.selected_chest_type = gui.elements.chest_type_selector:get()
    settings.always_open_ga_chest = gui.elements.always_open_ga_chest:get()
    settings.chest_opening_time = gui.elements.chest_opening_time_slider:get()
end

return settings
