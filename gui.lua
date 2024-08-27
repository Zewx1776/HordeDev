local gui = {}
local plugin_label = "Infernal Horde - Dev Edition"

local function create_checkbox(key)
    return checkbox:new(false, get_hash(plugin_label .. "_" .. key))
end

gui.loot_modes_options = {
    "Nothing",  -- will get stuck
    "Salvage",  -- will salvage all and keep going
}

gui.loot_modes_enum = {
    NOTHING = 0,
    SALVAGE = 2,
}

-- Add chest types enum
gui.chest_types_enum = {
    GEAR = 0,
    MATERIALS = 1,
    GOLD = 2,
}

gui.chest_types_options = {
    "Gear",
    "Materials",
    "Gold",
}

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox("main_toggle"),
    settings_tree = tree_node:new(1),
    melee_logic = create_checkbox("melee_logic"),
    elite_only_toggle = create_checkbox("elite_only"),
    loot_modes = combo_box:new(0, get_hash("piteer_loot_modes")),
    path_angle_slider = slider_int:new(0, 360, 10, get_hash("path_angle_slider")), -- 10 is a default value
    chest_type_selector = combo_box:new(0, get_hash("chest_type_selector")),
    always_open_ga_chest = create_checkbox("always_open_ga_chest"),
}

function gui.render()
    if not gui.elements.main_tree:push("Infernal Horde - Dev Edition") then return end

    gui.elements.main_toggle:render("Enable", "Enable the bot")
    
    if gui.elements.settings_tree:push("Settings") then
        gui.elements.melee_logic:render("Melee", "Do we need to move into Melee?")
        gui.elements.elite_only_toggle:render("Elite Only", "Do we only want to seek out elites in the Pit?")   
        gui.elements.loot_modes:render("Loot Modes", gui.loot_modes_options, "Nothing and Stash will get you stuck for now")
        gui.elements.path_angle_slider:render("Path Angle", "Adjust the angle for path filtering (0-360 degrees)")
        
        -- Updated chest type selector to use the new enum structure
        gui.elements.chest_type_selector:render("Chest Type", gui.chest_types_options, "Select the type of chest to open")
        gui.elements.always_open_ga_chest:render("Always Open GA Chest", "Toggle to always open Greater Affix chest when available")
        
        gui.elements.settings_tree:pop()
    end

    gui.elements.main_tree:pop()
end

return gui