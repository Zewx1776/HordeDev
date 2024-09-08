filter = require("data.filter")

local affix_filter = {}

local filter_lookup = {
    ["Amulet"] = filter.amulet_affix_filter,
    ["Ring"] = filter.ring_affix_filter,
    ["2H"] = filter.two_hand_weapons_affix_filter,
    ["1H"] = filter.one_hand_weapons_affix_filter,
    ["Boots"] = filter.boots_affix_filter,
    ["Pants"] = filter.pants_affix_filter,
    ["Gloves"] = filter.gloves_affix_filter,
    ["Chest"] = filter.chest_affix_filter,
    ["Helm"] = filter.helm_affix_filter
}

 function affix_filter:get_filter(skin_name)
    -- Check for specific weapon types first
    if #filter.focus_weapons_affix_filter > 0 and skin_name:match("Focus") then       
        return filter.focus_weapons_affix_filter
    end

    if #filter.dagger_weapons_affix_filter > 0 and skin_name:match("Dagger") then
        return filter.dagger_weapons_affix_filter
    end

    if #filter.shield_weapons_affix_filter > 0 and skin_name:match("Shield") then
        return filter.shield_weapons_affix_filter
    end

    -- Check the broader categories
    for pattern, filter in pairs(filter_lookup) do
        if skin_name:match(pattern) then
            return filter
        end
    end
    return nil
end

local uber_table = {
    { name = "Tyrael's Might", sno = 1901484 },
    { name = "The Grandfather", sno = 223271 },
    { name = "Andariel's Visage", sno = 241930 },
    { name = "Ahavarion, Spear of Lycander", sno = 359165 },
    { name = "Doombringer", sno = 221017 },
    { name = "Harlequin Crest", sno = 609820 },
    { name = "Melted Heart of Selig", sno = 1275935 },
    { name = "‍Ring of Starless Skies", sno = 1306338 }
}

function affix_filter:is_uber_item(sno_to_check)
    for _, entry in ipairs(uber_table) do
        if entry.sno == sno_to_check then
            return true
        end
    end
    return false
end

return affix_filter