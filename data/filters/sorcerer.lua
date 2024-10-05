local filter = {}

filter.helm_affix_filter = {
}

filter.chest_affix_filter = {
    { sno_id = 1924662, affix_name = "Mana per Second" },
    { sno_id = 1829566, affix_name = "Intelligence" },
    { sno_id = 1927016, affix_name = "Teleport" },
}

filter.gloves_affix_filter = {
    { sno_id = 1829556, affix_name = "Attack Speed" },
    { sno_id = 1829582, affix_name = "Critical Strike Chance" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
}

filter.pants_affix_filter = {
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829566, affix_name = "Intelligence" },
    { sno_id = 1834117, affix_name = "Dodge Chance" }
}

filter.boots_affix_filter = {
    { sno_id = 1829598, affix_name = "Movement Speed" },
    { sno_id = 1834117, affix_name = "Dodge Chance" },
}

filter.amulet_affix_filter = {
    { sno_id = 1928404, affix_name = "Glass Cannon" },
    { sno_id = 1928406, affix_name = "Conjuration Mastery" },
}

filter.ring_affix_filter = {
    { sno_id = 1829556, affix_name = "Attack Speed" },
    { sno_id = 1829584, affix_name = "Critical Strike Chance" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
}

filter.one_hand_weapons_affix_filter = {
    { sno_id = 1829562, affix_name = "Intelligence" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 2040980, affix_name = "Basic Skill -- Verathiel" },
    { sno_id = 2040968, affix_name = "Attack Speed -- Verathiel" },
}

filter.two_hand_weapons_affix_filter = {
    { sno_id = 1829562, affix_name = "Intelligence" },
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" }
}

filter.focus_weapons_affix_filter = {
    { sno_id = 1829562, affix_name = "Intelligence" },
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829582, affix_name = "Critical Strike Chance" },
    { sno_id = 1829560, affix_name = "Cooldown Reduction" },
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