local utils = require "core.utils"
local explorer = require "core.explorer"

local task  = {
    name = "Explore",
    shouldExecute = function()
        return not utils.get_closest_enemy()
    end,
    Execute = function()
        --explorer.enabled = true
    end
}

return task      