local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local chest_state = {
    INIT = "INIT",
    MOVING_TO_AETHER = "MOVING_TO_AETHER",
    COLLECTING_AETHER = "COLLECTING_AETHER",
    SELECTING_CHEST = "SELECTING_CHEST",
    MOVING_TO_CHEST = "MOVING_TO_CHEST",
    OPENING_CHEST = "OPENING_CHEST",
    WAITING_FOR_VFX = "WAITING_FOR_VFX",
    FINISHED = "FINISHED"
}

local open_chests_task = {
    name = "Open Chests",
    current_state = chest_state.INIT,
    current_chest_type = nil,
    
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") and utils.get_stash()
    end,
    
    Execute = function(self)
        local current_time = get_time_since_inject()
        
        if self.current_state == chest_state.INIT then
            self:init_chest_opening()
        elseif self.current_state == chest_state.MOVING_TO_AETHER then
            self:move_to_aether()
        elseif self.current_state == chest_state.COLLECTING_AETHER then
            self:collect_aether()
        elseif self.current_state == chest_state.SELECTING_CHEST then
            self:select_chest()
        elseif self.current_state == chest_state.MOVING_TO_CHEST then
            self:move_to_chest()
        elseif self.current_state == chest_state.OPENING_CHEST then
            self:open_chest()
        elseif self.current_state == chest_state.WAITING_FOR_VFX then
            self:wait_for_vfx()
        elseif self.current_state == chest_state.FINISHED then
            self:finish_chest_opening()
        end
    end,

    init_chest_opening = function(self)
        local aether_bomb = utils.get_aether_actor()
        if aether_bomb then
            self.current_state = chest_state.MOVING_TO_AETHER
        else
            self.current_state = chest_state.SELECTING_CHEST
        end
    end,

    move_to_aether = function(self)
        local aether_bomb = utils.get_aether_actor()
        if utils.distance_to(aether_bomb) > 2 then
            pathfinder.request_move(aether_bomb:get_position())
        else
            self.current_state = chest_state.COLLECTING_AETHER
        end
    end,

    collect_aether = function(self)
        local aether_bomb = utils.get_aether_actor()
        interact_object(aether_bomb)
        self.current_state = chest_state.SELECTING_CHEST
    end,

    select_chest = function(self)
        if settings.always_open_ga_chest and not tracker.ga_chest_opened and utils.get_chest(enums.chest_types["GREATER_AFFIX"]) then
            self.current_chest_type = "GREATER_AFFIX"
        else
            local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
            self.current_chest_type = chest_type_map[settings.selected_chest_type + 1]
        end
        self.current_state = chest_state.MOVING_TO_CHEST
    end,

    move_to_chest = function(self)
        local chest = utils.get_chest(enums.chest_types[self.current_chest_type])
        if chest then
            if utils.distance_to(chest) > 2 then
                if tracker.check_time("request_move_to_chest", 0.15) then
                    console.print(string.format("Moving to %s chest", self.current_chest_type))
                    pathfinder.request_move(chest:get_position())
                end
            else
                self.current_state = chest_state.OPENING_CHEST
            end
        else
            console.print("Chest not found")
            self.current_state = chest_state.FINISHED
        end
    end,

    open_chest = function(self)
        if tracker.check_time("chest_opening_time", 1) then
            local chest = utils.get_chest(enums.chest_types[self.current_chest_type])
            if chest then
                local try_open_chest = interact_object(chest)
                console.print("Chest interaction result: " .. tostring(try_open_chest))
                self.current_state = chest_state.WAITING_FOR_VFX
            else
                console.print("Chest not found when trying to open")
                self.current_state = chest_state.FINISHED
            end
        end
    end,

    wait_for_vfx = function(self)
        if tracker.check_time("chest_vfx_wait", 0.2) then
            local actors = actors_manager:get_all_actors()
            for _, actor in pairs(actors) do
                local name = actor:get_skin_name()
                if name == "vfx_resplendentChest_coins" or name == "vfx_resplendentChest_lightRays" or name == "Hell_Prop_Chest_Rare_81_Client_Dyn" then
                    console.print("Chest opened successfully: " .. name)
                    self.current_state = chest_state.FINISHED
                    return
                end
            end
            
            console.print("No visual effects found, chest opening may have failed")
            self.current_state = chest_state.SELECTING_CHEST
        end
    end,

    finish_chest_opening = function(self)
        if self.current_chest_type == "GREATER_AFFIX" then
            tracker.ga_chest_opened = true
        end
        self.current_state = chest_state.INIT
    end
}

return open_chests_task