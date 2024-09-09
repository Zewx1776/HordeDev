local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

-- Reference the position from horde.lua
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)

local chest_state = {
    INIT = "INIT",
    MOVING_TO_AETHER = "MOVING_TO_AETHER",
    COLLECTING_AETHER = "COLLECTING_AETHER",
    MOVING_TO_CENTER = "MOVING_TO_CENTER",
    SELECTING_CHEST = "SELECTING_CHEST",
    MOVING_TO_CHEST = "MOVING_TO_CHEST",
    OPENING_CHEST = "OPENING_CHEST",
    WAITING_FOR_VFX = "WAITING_FOR_VFX",
    FINISHED = "FINISHED",
    PAUSED_FOR_SALVAGE = "PAUSED_FOR_SALVAGE",
}

local chest_order = {"GREATER_AFFIX", "SELECTED", "GOLD"}

local open_chests_task = {
    name = "Open Chests",
    current_state = chest_state.INIT,
    current_chest_type = nil,
    current_chest_index = nil,
    failed_attempts = 0,
    current_chest_index = nil,
    max_attempts = 3,
    state_before_pause = nil,
    
    shouldExecute = function()
        local in_correct_zone = utils.player_in_zone("S05_BSK_Prototype02")
    
        if not in_correct_zone then
            return false
        end
    
        local gold_chest_exists = utils.get_chest(enums.chest_types["GOLD"]) ~= nil
    
        if not gold_chest_exists then
            return false
        end
    
        console.print("  finished_chest_looting: " .. tostring(tracker.finished_chest_looting))
    
        return not tracker.finished_chest_looting
    end,
    
    Execute = function(self)
        local current_time = get_time_since_inject()
        console.print("Current state: " .. self.current_state)
    
        if tracker.has_salvaged then
            self:return_from_salvage()
        elseif self.current_state == chest_state.PAUSED_FOR_SALVAGE then
            self:waiting_for_salvage()
        elseif self.current_state == chest_state.FINISHED then
            self:finish_chest_opening()
        elseif self.current_state == chest_state.INIT then
            self:init_chest_opening()
        elseif self.current_state == chest_state.MOVING_TO_AETHER then
            self:move_to_aether()
        elseif self.current_state == chest_state.COLLECTING_AETHER then
            self:collect_aether()
        elseif self.current_state == chest_state.MOVING_TO_CENTER then
            self:move_to_center()
        elseif self.current_state == chest_state.SELECTING_CHEST then
            self:select_chest()
        elseif self.current_state == chest_state.MOVING_TO_CHEST then
            self:move_to_chest()
        elseif self.current_state == chest_state.OPENING_CHEST then
            self:open_chest()
        elseif self.current_state == chest_state.WAITING_FOR_VFX then
            self:wait_for_vfx()
        end
    end,

    return_from_salvage = function(self)
        if not tracker.check_time("salvage_return_time", 3) then
            console.print("Waiting before resuming chest opening")
            return
        end
        console.print("Resume chest opening")
        tracker.salvage_return_time = nil
        tracker.has_salvaged = false
        self.current_state = chest_state.MOVING_TO_CHEST
        return
    end,

    waiting_for_salvage = function(self)
        console.print("Need salvage. Setting tracker.needs_salvage to start salvage task")
        tracker.needs_salvage = true
        return
    end,

    init_chest_opening = function(self)
        -- First, wait 6 seconds for all aether to drop from boss and check for aether
        local aether_bomb = utils.get_aether_actor()
        if aether_bomb then
            -- Boss dead and dropping aether
            tracker.boss_killed = true
            if not tracker.check_time("aether_drop_wait", settings.boss_kill_delay) then
                return
            end
            self.current_state = chest_state.MOVING_TO_AETHER
            return
        end
        
        console.print("Initializing chest opening")
        console.print("settings.always_open_ga_chest: " .. tostring(settings.always_open_ga_chest))
        console.print("tracker.ga_chest_opened: " .. tostring(tracker.ga_chest_opened))
        console.print("settings.selected_chest_type: " .. tostring(settings.selected_chest_type))
    
        -- Always set self.selected_chest_type
        local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
        self.selected_chest_type = chest_type_map[settings.selected_chest_type + 1]
    
        -- If no aether, proceed with chest selection
        self.current_chest_index = 1
        if settings.always_open_ga_chest and not tracker.ga_chest_opened then
            self.current_chest_type = "GREATER_AFFIX"
        else
            self.current_chest_index = 2  -- Skip to SELECTED
            self.current_chest_type = self.selected_chest_type
        end
        
        console.print("self.selected_chest_type: " .. tostring(self.selected_chest_type))
        console.print("self.current_chest_type: " .. tostring(self.current_chest_type))
        self.current_state = chest_state.MOVING_TO_CHEST
        self.failed_attempts = 0
    end,

    move_to_aether = function(self)
        local aether_bomb = utils.get_aether_actor()
        if aether_bomb then
            if utils.distance_to(aether_bomb) > 2 then
                explorer:set_custom_target(aether_bomb:get_position())
                explorer:move_to_target()
            else
                self.current_state = chest_state.COLLECTING_AETHER
            end
        else
            console.print("No aether bomb found")
            self.current_state = chest_state.SELECTING_CHEST
        end
    end,

    collect_aether = function(self)
        local aether_bomb = utils.get_aether_actor()
        if aether_bomb then
            interact_object(aether_bomb)
            self.current_state = chest_state.MOVING_TO_CENTER
        else
            console.print("No aether bomb found to collect")
            self.current_state = chest_state.MOVING_TO_CENTER
        end
    end,

    move_to_center = function(self)
        if utils.distance_to(horde_boss_room_position) > 2 then
            console.print("Moving to center position.")
            explorer:set_custom_target(horde_boss_room_position)
            explorer:move_to_target()
        else
            self.current_state = chest_state.SELECTING_CHEST
            console.print("Reached Central Room Position.")
        end
    end,

    select_chest = function(self)
        console.print("Selecting chest")
        console.print("Current self.selected_chest_type: " .. tostring(self.selected_chest_type))
        console.print("Current self.current_chest_type: " .. tostring(self.current_chest_type))
        local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
        self.selected_chest_type = chest_type_map[settings.selected_chest_type + 1]
        console.print("New self.selected_chest_type: " .. tostring(self.selected_chest_type))
        if not tracker.ga_chest_opened and settings.always_open_ga_chest and utils.get_chest(enums.chest_types["GREATER_AFFIX"]) then
            self.current_chest_type = "GREATER_AFFIX"
        else
            self.current_chest_type = self.selected_chest_type
        end
        console.print("Final self.current_chest_type: " .. tostring(self.current_chest_type))
        self.current_state = chest_state.MOVING_TO_CHEST
    end,

    move_to_chest = function(self)
        if self.current_chest_type == nil then
            console.print("Error: current_chest_type is nil")
            self:try_next_chest()
            return
        end
    
        console.print("Attempting to find " .. self.current_chest_type .. " chest")
        local chest = utils.get_chest(enums.chest_types[self.current_chest_type])
        
        if chest then
            self.chest_not_found_attempts = 0 -- Reset the counter when chest is found
            if utils.distance_to(chest) > 2 then
                if tracker.check_time("request_move_to_chest", 0.15) then
                    console.print(string.format("Moving to %s chest", self.current_chest_type))
                    explorer:set_custom_target(chest:get_position())
                    explorer:move_to_target()

                    self.move_attempts = (self.move_attempts or 0) + 1
                    if self.move_attempts >= settings.chest_move_attempts then
                        console.print("Failed to reach chest after multiple attempts")
                        self:try_next_chest()
                        return
                    end
                end
            else
                self.current_state = chest_state.OPENING_CHEST
                self.move_attempts = 0  -- Reset the counter when we successfully reach the chest
            end
        else
            console.print("Chest not found")
            self.chest_not_found_attempts = (self.chest_not_found_attempts or 0) + 1
            if self.chest_not_found_attempts >= 15 then
                console.print("Failed to find chest after 5 attempts")
                self:try_next_chest()
            else
                console.print("Attempt " .. self.chest_not_found_attempts .. " of 5 to find chest")
                self.current_state = chest_state.MOVING_TO_CHEST -- Stay in this state to retry
            end
        end
    end,

    open_chest = function(self)
        if tracker.check_time("chest_opening_time", settings.open_chest_delay) then
            -- Add check for GEAR chest type and full inventory
            console.print("Current self.current_chest_type: " .. tostring(self.current_chest_type))
            console.print("Current self.selected_chest_type: " .. tostring(self.selected_chest_type))
            local failover_chest_type_map = {"MATERIALS", "GOLD"}
            if not settings.salvage and (self.current_chest_type == "GEAR" or self.current_chest_type == "GREATER_AFFIX") and utils.is_inventory_full() then
                console.print("Selected chest is GEAR and inventory is full, switching to failover chest type")
                self.selected_chest_type = failover_chest_type_map[settings.failover_chest_type + 1]
                self.current_chest_type = failover_chest_type_map[settings.failover_chest_type + 1]
                self.current_state = chest_state.MOVING_TO_CHEST
                return
            elseif settings.salvage and utils.is_inventory_full() then
                self.state_before_pause = self.current_state
                self.current_state = chest_state.PAUSED_FOR_SALVAGE
                return
            end
            local chest = utils.get_chest(enums.chest_types[self.current_chest_type])
            if chest then
                local try_open_chest = interact_object(chest)
                console.print("Chest interaction result: " .. tostring(try_open_chest))
                self.current_state = chest_state.WAITING_FOR_VFX
            else
                console.print("Chest not found when trying to open")
                self:try_next_chest()
                -- Log all nearby actors to help debug
                local actors = actors_manager:get_all_actors()
                for _, actor in pairs(actors) do
                    if actor:get_skin_name():match("Chest") then
                        console.print("Found chest: " .. actor:get_skin_name() .. ", Distance: " .. utils.distance_to(actor))
                    end
                end
                self.current_state = chest_state.FINISHED
                console.print("Set tracker.finished_chest_looting to true due to chest not found")
            end
        end
    end,

    wait_for_vfx = function(self)
        if tracker.check_time("chest_vfx_wait", 1) then
            local actors = actors_manager:get_all_actors()
            for _, actor in pairs(actors) do
                local name = actor:get_skin_name()
                if name == "vfx_resplendentChest_coins" or name == "vfx_resplendentChest_lightRays" then
                    console.print("Chest opened successfully: " .. name)
                    self.failed_attempts = 0
                    self:try_next_chest(true)  -- Move to next chest type after successful opening
                    return
                end
            end
            
            console.print("No visual effects found, chest opening may have failed")
            self.failed_attempts = self.failed_attempts + 1
            if self.failed_attempts >= self.max_attempts then
                self:try_next_chest(false)
            else
                self.current_state = chest_state.OPENING_CHEST
            end
        end
    end,

    try_next_chest = function(self, was_successful)
        console.print("Trying next chest")
        console.print("Current self.current_chest_type: " .. tostring(self.current_chest_type))
        console.print("Current self.selected_chest_type: " .. tostring(self.selected_chest_type))

        -- Add check for GEAR chest type and full inventory
        local failover_chest_type_map = {"MATERIALS", "GOLD"}
        if not settings.salvage and (self.current_chest_type == "GEAR" or self.current_chest_type == "GREATER_AFFIX") and utils.is_inventory_full() then
            console.print("Selected chest is GEAR and inventory is full, switching to failover chest type")
            self.selected_chest_type = failover_chest_type_map[settings.failover_chest_type + 1]
            self.current_chest_type = failover_chest_type_map[settings.failover_chest_type + 1]
            self.current_state = chest_state.MOVING_TO_CHEST
            return
        elseif settings.salvage and (self.current_chest_type == "GEAR" or self.current_chest_type == "GREATER_AFFIX") and utils.is_inventory_full() then
            self.state_before_pause = self.current_state
            self.current_state = chest_state.PAUSED_FOR_SALVAGE
            return
        end
    
        local function move_to_next_chest()
            self.current_chest_index = (self.current_chest_index or 0) + 1
            if self.current_chest_index <= #chest_order then
                local next_chest = chest_order[self.current_chest_index]
                if next_chest == "SELECTED" then
                    self.current_chest_type = self.selected_chest_type
                else
                    self.current_chest_type = next_chest
                end
                return true
            end
            return false
        end
    
        if not was_successful or self.current_chest_type ~= self.selected_chest_type then
            if not move_to_next_chest() then
                console.print("All chest types exhausted, finishing task")
                self.current_state = chest_state.FINISHED
                return
            end
        end
    
        if self.current_chest_type == "GREATER_AFFIX" then
            tracker.ga_chest_opened = true
        elseif self.current_chest_type == self.selected_chest_type then
            tracker.selected_chest_opened = true
        end
    
        console.print("Next chest type set to: " .. self.current_chest_type)
        self.current_state = chest_state.MOVING_TO_CHEST
        self.failed_attempts = 0
    end,

    finish_chest_opening = function(self)
        -- Handle opening the gold chest with a 6-second delay
        if self.current_chest_type == "GOLD" then
            if not tracker.check_time("gold_chest_timer", 6) then
                console.print("Waiting for 6 seconds after opening gold chest.")
                return
            end
            tracker.gold_chest_opened = true
        end
    
        if self.current_chest_type == "GREATER_AFFIX" then
            tracker.ga_chest_opened = true
        elseif self.current_chest_type == self.selected_chest_type then
            tracker.selected_chest_opened = true
        end
    
        tracker.finished_chest_looting = true
        console.print("Set tracker.finished_chest_looting to true in finish_chest_opening")
        console.print("Chest opening task finished")
    end,

    reset = function(self)
        self.current_state = chest_state.INIT
        self.current_chest_type = nil
        self.failed_attempts = 0
        self.current_chest_index = nil-- Reset the timer during reset
        tracker.finished_chest_looting = false
        tracker.ga_chest_opened = false
        tracker.selected_chest_opened = false
        tracker.gold_chest_opened = false
        console.print("Reset open_chests_task and related tracker flags")
    end,
}

return open_chests_task
