local gui = {}
local plugin_label = "Infernal Horde - Dev Edition"

local function create_checkbox(key)
    return checkbox:new(false, get_hash(plugin_label .. "_" .. key))
end

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

gui.failover_chest_types_options = {
    "Materials",
    "Gold",
}

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox("main_toggle"),
    settings_tree = tree_node:new(1),
    melee_logic = create_checkbox("melee_logic"),
    elite_only_toggle = create_checkbox("elite_only"),
    salvage_toggle = create_checkbox("salvage_toggle"),
    aggresive_movement_toggle = create_checkbox("aggresive_movement_toggle"),
    path_angle_slider = slider_int:new(0, 360, 10, get_hash("path_angle_slider")), -- 10 is a default value
    chest_type_selector = combo_box:new(0, get_hash("chest_type_selector")),
    failover_chest_type_selector = combo_box:new(0, get_hash("failover_chest_type_selector")),
    always_open_ga_chest = create_checkbox("always_open_ga_chest"),
    loot_mothers_gift = create_checkbox("loot_mothers_gift"),
    merry_go_round = checkbox:new(true, get_hash("merry_go_round")),
    open_chest_delay = slider_float:new(1.0, 3.0, 1.5, get_hash("open_chest_delay")), -- 1.0 is the default value
    boss_kill_delay = slider_int:new(1, 10, 6, get_hash("boss_kill_delay")), -- 6 is a default value
    chest_move_attempts = slider_int:new(20, 400, 40, get_hash("chest_move_attempts")), -- 20 is a default value
    use_salvage_filter_toggle = checkbox:new(false, get_hash("use_salvage_filter_toggle")),
    greater_affix_count = slider_int:new(0, 3, 0, get_hash("greater_affix_count")), -- 0 is the default value
    affix_salvage_count = slider_int:new(1, 3, 1, get_hash("affix_salvage_count")), -- 1 is a default value
    movement_spell_to_objective = checkbox:new(false, get_hash("movement_spell_to_objective")),
}

function gui.render()
    if not gui.elements.main_tree:push("Infernal Horde - Dev Edition") then return end

    gui.elements.main_toggle:render("Enable", "Enable the bot")
    
    if gui.elements.settings_tree:push("Settings") then
        gui.elements.melee_logic:render("Melee", "Do we need to move into Melee?")
        gui.elements.elite_only_toggle:render("Elite Only", "Do we only want to seek out elites in the Pit?") 
        gui.elements.aggresive_movement_toggle:render("Aggresive movement", "Move directly to target, will fight close to target")
        gui.elements.movement_spell_to_objective:render("Attempt to use movement spell for objective", "Will attempt to use movement spell towards objective")
        if not gui.elements.aggresive_movement_toggle:get() then
            gui.elements.path_angle_slider:render("Path Angle", "Adjust the angle for path filtering (0-360 degrees)")
        end
        gui.elements.salvage_toggle:render("Salvage", "Enable salvaging items")
        if gui.elements.chest_type_selector:get() == 0 and gui.elements.salvage_toggle:get() then
            gui.elements.use_salvage_filter_toggle:render("Use salvage filter logic (update filter.lua)", "Salvage based on filter logic. Update filter.lua") 
            if gui.elements.chest_type_selector:get() == 0 and gui.elements.salvage_toggle:get() and gui.elements.use_salvage_filter_toggle:get() then
                gui.elements.greater_affix_count:render("Min Greater Affixes to Keep", "Select minimum number of Greater Affixes to keep an item (0-3, 0 = off)")
                gui.elements.affix_salvage_count:render("Min No. affixes to keep", "Minimum number of matching affixes to keep")
            end
        end
        -- Updated chest type selector to use the new enum structure
        gui.elements.chest_type_selector:render("Chest Type", gui.chest_types_options, "Select the type of chest to open")
        if gui.elements.chest_type_selector:get() == 0 and not gui.elements.salvage_toggle:get() then
            gui.elements.failover_chest_type_selector:render("Failover Chest Type When Inventory is full", gui.failover_chest_types_options, "Select the failover type of chest to open when inventory is full")
        end
        gui.elements.always_open_ga_chest:render("Always Open GA Chest", "Toggle to always open Greater Affix chest when available")
        gui.elements.loot_mothers_gift:render("Loot Mother's Gift", "Toggle to loot Mother's Gift")
        gui.elements.merry_go_round:render("Circle arena when wave completes", "Toggle to circle arene when wave completes to pick up stray Aethers")
        gui.elements.open_chest_delay:render("Chest open delay", "Adjust delay for the chest opening (1.0-3.0)", 2)
        gui.elements.boss_kill_delay:render("Boss kill delay", "Adjust delay after killing boss (1-10)")
        gui.elements.chest_move_attempts:render("Chest move attempts", "Adjust the amount of times it tries to reach a chest (20-400)")
        
        gui.elements.settings_tree:pop()
    end

    gui.elements.main_tree:pop()
end

return gui