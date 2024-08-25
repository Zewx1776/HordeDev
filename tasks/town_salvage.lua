local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local tracker = require "core.tracker"
local gui = require "gui"

local salvage_state = {
    INIT = "INIT",
    TELEPORTING = "TELEPORTING",
    MOVING_TO_BLACKSMITH = "MOVING_TO_BLACKSMITH",
    INTERACTING_WITH_BLACKSMITH = "INTERACTING_WITH_BLACKSMITH",
    SALVAGING = "SALVAGING",
    MOVING_TO_PORTAL = "MOVING_TO_PORTAL",
    INTERACTING_WITH_PORTAL = "INTERACTING_WITH_PORTAL",
    FINISHED = "FINISHED",
}

local town_salvage_task = {
    name = "Town Salvage",
    current_state = salvage_state.INIT,
    max_retries = 5,
    current_retries = 0,
    max_teleport_attempts = 5,
    teleport_wait_time = 20,

    shouldExecute = function()
        return (get_local_player():get_item_count() >= 25 and settings.loot_modes == gui.loot_modes_enum.SALVAGE)
    end,

    Execute = function(self)
        console.print("Executing Town Salvage Task")
        console.print("Current state: " .. self.current_state)

        if self.current_retries >= self.max_retries then
            console.print("Max retries reached. Resetting task.")
            self:reset()
            return
        end

        if self.current_state == salvage_state.INIT then
            self:init_salvage()
        elseif self.current_state == salvage_state.TELEPORTING then
            self:handle_teleporting()
        elseif self.current_state == salvage_state.MOVING_TO_BLACKSMITH then
            self:move_to_blacksmith()
        elseif self.current_state == salvage_state.INTERACTING_WITH_BLACKSMITH then
            self:interact_with_blacksmith()
        elseif self.current_state == salvage_state.SALVAGING then
            self:salvage_items()
        elseif self.current_state == salvage_state.MOVING_TO_PORTAL then
            self:move_to_portal()
        elseif self.current_state == salvage_state.INTERACTING_WITH_PORTAL then
            self:interact_with_portal()
        elseif self.current_state == salvage_state.FINISHED then
            self:finish_salvage()
        end
    end,

    init_salvage = function(self)
        console.print("Initializing salvage process")
        if not utils.player_in_zone("Scos_Cerrigar") and get_local_player():get_item_count() >= 1 then
            self.current_state = salvage_state.TELEPORTING
            self.teleport_start_time = get_time_since_inject()
            self.teleport_attempts = 0
            self:teleport_to_town()
            console.print("Player not in Cerrigar, initiating teleport")
        else
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
            console.print("Player in Cerrigar, moving to blacksmith")
        end
    end,
    
    handle_teleporting = function(self)
        local current_time = get_time_since_inject()
        if utils.player_in_zone("Scos_Cerrigar") then
            console.print("Teleport complete, moving to blacksmith")
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
            self.teleport_attempts = 0 -- Reset attempts counter
        else
            if current_time - self.teleport_start_time > self.teleport_wait_time then
                console.print("Teleport taking too long, retrying...")
                self.teleport_attempts = (self.teleport_attempts or 0) + 1
                
                if self.teleport_attempts >= self.max_teleport_attempts then
                    console.print("Max teleport attempts reached. Resetting task.")
                    self:reset()
                    return
                end
                
                self:teleport_to_town()
            else
                console.print("Still teleporting, waiting...")
            end
        end
    end,

    teleport_to_town = function(self)
        console.print("Teleporting to town")
        explorer:clear_path_and_target()
        teleport_to_waypoint(enums.waypoints.CERRIGAR)
        self.teleport_start_time = get_time_since_inject()
        console.print("Teleport command issued")
    end,

    move_to_blacksmith = function(self)
        console.print("Moving to blacksmith")
        console.print("Explorer object: " .. tostring(explorer))
        console.print("set_custom_target exists: " .. tostring(type(explorer.set_custom_target) == "function"))
        console.print("move_to_target exists: " .. tostring(type(explorer.move_to_target) == "function"))
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            explorer:set_custom_target(blacksmith:get_position())
            explorer:move_to_target()
            if utils.distance_to(blacksmith) < 2 then
                console.print("Reached blacksmith")
                self.current_state = salvage_state.INTERACTING_WITH_BLACKSMITH
            end
        else
            console.print("No blacksmith found, retrying...")
            self.current_retries = self.current_retries + 1
            explorer:set_custom_target(enums.positions.blacksmith_position)
            explorer:move_to_target()
        end
    end,

    interact_with_blacksmith = function(self)
        console.print("Interacting with blacksmith")
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            interact_vendor(blacksmith)
            if tracker.check_time("blacksmith_interaction", 5) then
                console.print("Interaction complete, moving to salvage")
                self.current_state = salvage_state.SALVAGING
            end
        else
            console.print("Blacksmith not found, moving back")
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
        end
    end,

    salvage_items = function(self)
        console.print("Salvaging items")
        local initial_item_count = get_local_player():get_item_count()
        loot_manager.salvage_all_items()
        
        if tracker.check_time("salvage_completion", 2) then
            local final_item_count = get_local_player():get_item_count()
            
            if final_item_count < initial_item_count then
                tracker.has_salvaged = true
                console.print("Salvage complete, moving to portal")
                self.current_state = salvage_state.MOVING_TO_PORTAL
            else
                console.print("Salvage may have failed, retrying")
                self.current_retries = self.current_retries + 1
                if self.current_retries >= self.max_retries then
                    console.print("Max retries reached. Resetting task.")
                    self:reset()
                else
                    self.current_state = salvage_state.INTERACTING_WITH_BLACKSMITH
                end
            end
        end
    end,

    move_to_portal = function(self)
        console.print("Moving to portal")
        explorer:set_custom_target(enums.positions.portal_position)
        explorer:move_to_target()
        if utils.distance_to(enums.positions.portal_position) < 5 then
            console.print("Reached portal")
            self.current_state = salvage_state.INTERACTING_WITH_PORTAL
        end
    end,

    interact_with_portal = function(self)
        console.print("Interacting with portal")
        local portal = utils.get_town_portal()
        if portal then
            interact_object(portal)
            if tracker.check_time("portal_interaction", 2) then
                console.print("Portal interaction complete")
                self.current_state = salvage_state.FINISHED
            end
        else
            console.print("Town portal not found")
            self.current_state = salvage_state.MOVING_TO_PORTAL
        end
    end,

    finish_salvage = function(self)
        console.print("Finishing salvage task")
        tracker.has_salvaged = false
        tracker.needs_salvage = false
        self.current_state = salvage_state.INIT
        self.current_retries = 0
        console.print("Town salvage task finished")
    end,

    reset = function(self)
        console.print("Resetting town salvage task")
        self.current_state = salvage_state.INIT
        tracker.has_salvaged = false
        tracker.needs_salvage = false
        console.print("Reset town_salvage_task and related tracker flags")
    end,
}

return town_salvage_task