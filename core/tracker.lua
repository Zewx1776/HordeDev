local tracker = {
    finished_time = 0,
    pit_start_time = 0,
    ga_chest_opened = false,
    selected_chest_opened = false,
    gold_chest_opened = false,
    finished_chest_looting = false,
    has_salvaged = false,
    exit_horde_start_time = 0,
    has_entered = false,
    start_dungeon_time = nil,
    horde_opened = false,
    first_run = false,
    exit_horde_completion_time = 0,
    exit_horde_completed = true,
    wave_start_time = 0,
    needs_salvage = false,
    victory_lap = false,
    locked_door_found = false;
}

function tracker.check_time(key, delay)
    local current_time = get_time_since_inject()
    if not tracker[key] then
        tracker[key] = current_time
    end
    if current_time - tracker[key] >= delay then
        return true
    end
    return false
end

function tracker.clear_key(key)
    tracker[key] = nil
end

return tracker