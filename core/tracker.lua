local tracker = {
    finished_time = 0,
    pit_start_time = 0,
    ga_chest_opened = false,
    finished_chest_looting = false,
    has_salvaged = false,
    exit_horde_start_time = 0,
    has_entered = false,
    start_dungeon_time = nil,
    horde_opened = false,
    first_run = false,
    exit_horde_completion_time = 0,
    exit_horde_completed = true,
    wave_start_time = 0
}

function tracker.reset_chest_trackers()
    tracker.ga_chest_opened = false
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

return tracker