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
    interact_time = 0,
    portal_interact_time = 0,

    shouldExecute = function()
        return (get_local_player():get_item_count() >= 25 and settings.loot_modes == gui.loot_modes_enum.SALVAGE)
    end,

    Execute = function(self)
        local current_time = get_time_since_inject()
        console.print("Current state: " .. self.current_state)

        if self.current_state == salvage_state.INIT then
            self:init_salvage()
        elseif self.current_state == salvage_state.TELEPORTING then
            self:teleport_to_town()
        elseif self.current_state == salvage_state.MOVING_TO_BLACKSMITH then
            self:move_to_blacksmith()
        elseif self.current_state == salvage_state.INTERACTING_WITH_BLACKSMITH then
            self:interact_with_blacksmith(current_time)
        elseif self.current_state == salvage_state.SALVAGING then
            self:salvage_items()
        elseif self.current_state == salvage_state.MOVING_TO_PORTAL then
            self:move_to_portal()
        elseif self.current_state == salvage_state.INTERACTING_WITH_PORTAL then
            self:interact_with_portal(current_time)
        elseif self.current_state == salvage_state.FINISHED then
            self:finish_salvage()
        end
    end,

    init_salvage = function(self)
        if not utils.player_in_zone("Scos_Cerrigar") and get_local_player():get_item_count() >= 1 then
            self.current_state = salvage_state.TELEPORTING
        else
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
        end
    end,

    teleport_to_town = function(self)
        explorer:clear_path_and_target()
        teleport_to_waypoint(waypoints_enum.CERRIGAR)
        self.current_state = salvage_state.MOVING_TO_BLACKSMITH
    end,

    move_to_blacksmith = function(self)
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            explorer:set_custom_target(blacksmith:get_position())
            explorer:move_to_target()
            if utils.distance_to(blacksmith) < 2 then
                self.current_state = salvage_state.INTERACTING_WITH_BLACKSMITH
                self.interact_time = 0
            end
        else
            console.print("No blacksmith found")
            explorer:set_custom_target(enums.positions.blacksmith_position)
            explorer:move_to_target()
        end
    end,

    interact_with_blacksmith = function(self, current_time)
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            if self.interact_time == 0 then
                self.interact_time = current_time
                interact_vendor(blacksmith)
            elseif current_time - self.interact_time >= 5 then
                self.current_state = salvage_state.SALVAGING
            end
        else
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
        end
    end,

    salvage_items = function(self)
        loot_manager.salvage_all_items()
        tracker.has_salvaged = true
        self.current_state = salvage_state.MOVING_TO_PORTAL
    end,

    move_to_portal = function(self)
        explorer:set_custom_target(enums.positions.portal_position)
        explorer:move_to_target()
        if utils.distance_to(enums.positions.portal_position) < 5 then
            self.current_state = salvage_state.INTERACTING_WITH_PORTAL
            self.portal_interact_time = 0
        end
    end,

    interact_with_portal = function(self, current_time)
        local portal = utils.get_town_portal()
        if portal then
            if self.portal_interact_time == 0 then
                self.portal_interact_time = current_time
                interact_object(portal)
            elseif current_time - self.portal_interact_time >= 2 then
                self.current_state = salvage_state.FINISHED
            end
        else
            console.print("Town portal not found")
            self.current_state = salvage_state.MOVING_TO_PORTAL
        end
    end,

    finish_salvage = function(self)
        tracker.has_salvaged = false
        tracker.needs_salvage = false
        self.current_state = salvage_state.INIT
        console.print("Town salvage task finished")
    end,

    reset = function(self)
        self.current_state = salvage_state.INIT
        self.interact_time = 0
        self.portal_interact_time = 0
        tracker.has_salvaged = false
        tracker.needs_salvage = false
        console.print("Reset town_salvage_task and related tracker flags")
    end,
}

return town_salvage_task