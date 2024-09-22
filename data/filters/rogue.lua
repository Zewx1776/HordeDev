local filter = {}

filter.helm_affix_filter = {
}

filter.chest_affix_filter = {
}

filter.gloves_affix_filter = {
    { sno_id = 1829556, affix_name = "Attack Speed" },
    { sno_id = 1829582, affix_name = "Critical Strike Chance" },
    { sno_id = 1829586, affix_name = "Critical Strike Damage" },
}

filter.pants_affix_filter = {
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829562, affix_name = "Dexterity" },
    { sno_id = 1829554, affix_name = "Armor" },
}

filter.boots_affix_filter = {
    { sno_id = 1829562, affix_name = "Dexterity" },
    { sno_id = 1829598, affix_name = "Movement Speed" },
    { sno_id = 1834117, affix_name = "Dodge Chance" },
}

filter.amulet_affix_filter = {
    { sno_id = 1927653, affix_name = "Alchemical Advantage" },
    { sno_id = 1927657, affix_name = "Frigid Finesse" },
    { sno_id = 1927640, affix_name = "Unstable Elixir" },
}

filter.ring_affix_filter = {
    { sno_id = 1829562, affix_name = "Dexterity" },
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829590, affix_name = "Damage Over Time" },
    { sno_id = 1829675, affix_name = "Lucky Hit Chance" },
}

filter.one_hand_weapons_affix_filter = {
}

filter.two_hand_weapons_affix_filter = {
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829562, affix_name = "Dexterity" },
    { sno_id = 1829590, affix_name = "Damage Over Time" },
}

filter.focus_weapons_affix_filter = {
}

filter.dagger_weapons_affix_filter = {
    { sno_id = 1829562, affix_name = "Dexterity" },
    { sno_id = 1829592, affix_name = "Max. Life" },
    { sno_id = 1829590, affix_name = "Damage Over Time" },
    { sno_id = 2037914, affix_name = "Subterfuge CD -- Umbracrux" },
    { sno_id = 2037916, affix_name = "Innervation -- Umbracrux" },
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