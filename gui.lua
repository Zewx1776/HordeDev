local gui = {}
local plugin_label = "Infernal Horde - Dev Edition"

local function create_checkbox(key)
    return checkbox:new(false, get_hash(plugin_label .. "_" .. key))
end

gui.loot_modes_options = {
    "Nothing",  -- will get stuck
    "Sell",     -- will sell all and keep going
    "Salvage",  -- will salvage all and keep going
    "Stash",    -- nothing for now, will get stuck, but in future can be added
}

gui.loot_modes_enum = {
    NOTHING = 0,
    SELL = 1,
    SALVAGE = 2,
    STASH = 3,
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
    loot_toggle = create_checkbox("loot_toggle"),
    loot_modes = combo_box:new(0, get_hash("piteer_loot_modes")),
    path_angle_slider = slider_int:new(0, 360, 10, get_hash("path_angle_slider")), -- 10 is a default value
    chest_type_selector = combo_box:new(0, get_hash("chest_type_selector")),
    always_open_ga_chest = create_checkbox("always_open_ga_chest"),
    loot_mothers_gift = create_checkbox("loot_mothers_gift"),
    merry_go_round = checkbox:new(true, get_hash("merry_go_round")),
    chest_open_delay = slider_float:new(1.0, 3.0, 1.0, get_hash("chest_open_delay")), -- 1.0 is the default value
    boss_kill_delay = slider_int:new(1, 10, 6, get_hash("boss_kill_delay")), -- 6 is a default value
    chest_move_attempts = slider_int:new(20, 400, 20, get_hash("chest_move_attempts")), -- 20 is a default value
}

function gui.render()
    if not gui.elements.main_tree:push("Infernal Horde - Dev Edition") then return end

    gui.elements.main_toggle:render("Enable", "Enable the bot")
    
    if gui.elements.settings_tree:push("Settings") then
        gui.elements.melee_logic:render("Melee", "Do we need to move into Melee?")
        gui.elements.elite_only_toggle:render("Elite Only", "Do we only want to seek out elites in the Pit?")
        -- gui.elements.loot_toggle:render("Enable Looting", "Toggle looting on/off")        
        -- gui.elements.loot_modes:render("Loot Modes", gui.loot_modes_options, "Nothing and Stash will get you stuck for now")
        gui.elements.path_angle_slider:render("Path Angle", "Adjust the angle for path filtering (0-360 degrees)")
        
        -- Updated chest type selector to use the new enum structure
        gui.elements.chest_type_selector:render("Chest Type", gui.chest_types_options, "Select the type of chest to open")
        gui.elements.always_open_ga_chest:render("Always Open GA Chest", "Toggle to always open Greater Affix chest when available")
        gui.elements.loot_mothers_gift:render("Loot Mother's Gift", "Toggle to loot Mother's Gift")
        gui.elements.merry_go_round:render("Circle arena when wave completes", "Toggle to circle arene when wave completes to pick up stray Aethers")
        gui.elements.open_chest_delay:render("Chest open delay", "Adjust delay for the chest opening (1.0-3.0)")
        gui.elements.boss_kill_delay:render("Boss kill delay", "Adjust delay after killing boss (1-10)")
        gui.elements.chest_move_attempts:render("Chest move attempts", "Adjust the amount of times it tries to reach a chest (20-400)")
        
        gui.elements.settings_tree:pop()
    end

    gui.elements.main_tree:pop()
end

return gui