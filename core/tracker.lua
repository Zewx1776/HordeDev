local tracker = {
    finished_time = 0,
    pit_start_time = 0,
    ga_chest_open_time = 0,
    ga_chest_opened = false,
    peasant_chest_open_time = 0,
    peasant_chest_opening_stopped = false,
    gold_chest_open_time = 0,
    gold_chest_opened = false,
    finished_chest_looting = false,
    has_salvaged = false,
    exit_horde_start_time = 0,
    has_entered = false,
    start_dungeon_time = nil,
    gold_chest_successfully_opened = false,
    horde_opened = false,
    first_run = false,
    exit_horde_completion_time = 0,
    exit_horde_completed = true,
    wave_start_time = 0
}

function tracker.reset_chest_trackers()
    tracker.ga_chest_opened = false
    tracker.ga_chest_open_time = 0
    tracker.peasant_chest_open_time = 0
    tracker.peasant_chest_opening_stopped = false
    tracker.gold_chest_opened = false
    tracker.gold_chest_open_time = 0
    tracker.finished_chest_looting = false
end


function tracker.check_time(key, delay)
    local current_time = get_time_since_inject()
    if not tracker[key] or current_time - tracker[key] >= delay then
        tracker[key] = current_time
        return true
    end
    return false
end

local function get_consumable_info(item)
    if not item then
        console.print("Error: Item is nil")
        return nil
    end
    local info = {}

    -- Safely get display name
    local success, display_name = pcall(function() return item:get_display_name() end)
    info.display_name = success and display_name or "Unknown"

    -- Safely get name
    local success, name = pcall(function() return item:get_name() end)
    info.name = success and name or "Unknown"
    
    return false
end

return tracker
