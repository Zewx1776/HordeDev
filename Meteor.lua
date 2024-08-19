local M = {}

M.initialized_evade_db = false

function M.initialize()
    if M.initialized_evade_db then
        return
    end

    local circular_spell_particles = {"pvp_volcano_projectile_mesh"}
    local circular_spell_name = "Infernal Meteor"
    local circular_spell_radius = 1.5
    local circular_spell_color = color.new(255, 0, 0, 255) -- RGBA: Red
    local circular_spell_danger_level = danger_level.high
    local circular_spell_delay = 1.0
    local circular_spell_moving = true
    local circular_spell_set_to_player_pos = false
    local circular_spell_set_to_player_pos_delay = 0.5

    evade.register_circular_spell(circular_spell_particles, circular_spell_name, circular_spell_radius,
                                  circular_spell_color, circular_spell_danger_level, circular_spell_delay,
                                  circular_spell_moving, circular_spell_set_to_player_pos, circular_spell_set_to_player_pos_delay)

    local circular_spell_particles = {"astaroth_boss_meteorstorm_proj"}
        local circular_spell_name = "Infernal Boss Meteor"
        local circular_spell_radius = 2.0
        local circular_spell_color = color.new(255, 0, 0, 255) -- RGBA: Red
        local circular_spell_danger_level = danger_level.high
        local circular_spell_delay = 1.0
        local circular_spell_moving = true
        local circular_spell_set_to_player_pos = false
        local circular_spell_set_to_player_pos_delay = 0.5

        evade.register_circular_spell(circular_spell_particles, circular_spell_name, circular_spell_radius,
                                    circular_spell_color, circular_spell_danger_level, circular_spell_delay,
                                    circular_spell_moving, circular_spell_set_to_player_pos, circular_spell_set_to_player_pos_delay)

    M.initialized_evade_db = true
end

return M