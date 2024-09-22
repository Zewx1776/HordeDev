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
    victory_positions = nil,
    locked_door_found = false,
    boss_killed = false,
    teleported_from_town = false,
    keep_items = 0
}

local runtime_timer = {}

function tracker.check_time(key, delay)
    local current_time = get_time_since_inject()
    if not tracker[key] then
        tracker[key] = current_time
        table.insert(runtime_timer, key)
    end
    if current_time - tracker[key] >= delay then
        return true
    end
    return false
end

function tracker.set_teleported_from_town(value)
    tracker.teleported_from_town = value
end

function tracker.clear_runtime_timers()
    for _, timer in pairs(runtime_timer) do
        tracker.clear_key(timer)
    end
end

-- The plan is to have a separate table that stores all the key added by check_time and clear them all on exit
function tracker.clear_key(key)
    tracker[key] = nil
end

return tracker