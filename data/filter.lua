local filter = {}

filter.helm_affix_filter = {
}

filter.chest_affix_filter = {
}

filter.gloves_affix_filter = {
    { sno_id = 1829582, affix_name = "Critical Strike Chance" },
    { sno_id = 1829584, affix_name = "Critical Strike Chance" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
    { sno_id = 1829556, affix_name = "Attack Speed" }
}

filter.pants_affix_filter = {
}

filter.boots_affix_filter = {
    { sno_id = 1829598, affix_name = "Movement Speed" },
}

filter.amulet_affix_filter = {
}

filter.ring_affix_filter = {
    { sno_id = 1829562, affix_name = "Intelligence" },
    { sno_id = 1829592, affix_name = "Maximum Life" },
    { sno_id = 1829584, affix_name = "Critical Strike Chance" },
    { sno_id = 1829582, affix_name = "Critical Strike Chance" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
    { sno_id = 1829556, affix_name = "Attack Speed" },
}

filter.one_hand_weapons_affix_filter = {
    { sno_id = 1829562, affix_name = "Intelligence" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
    { sno_id = 1829592, affix_name = "Maximum Life" }
}

filter.two_hand_weapons_affix_filter = {
    { sno_id = 1829562, affix_name = "Intelligence" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" }
}


filter.focus_weapons_affix_filter = {
}

filter.dagger_weapons_affix_filter = {
}

filter.shield_weapons_affix_filter = {
}

-- Color coding logic
function get_color(affix_count)
    if affix_count >= 3 then
        return "green"
    elseif affix_count == 2 then
        return "yellow"
    else
        return "red"
    end
end

function filter_items(item, affix_filter)
    local match_count = 0
    for _, affix in ipairs(affix_filter) do
        if item:has_affix(affix.sno_id) then
            match_count = match_count + 1
        end
    end
    return get_color(match_count)
end

return filter