# Infernal Horde - Dev Edition

**`THIS IS A DEVELOPMENT RELEASE`**

**`As a community script any user is welcome to join the development of this script, if you are not a dev (don't worry, I'm not a dev either the majority of this script is thanks to Neer) I HIGHLY recommend loading this repo into Greptile and using Claude to understand and help write the code, its not a magic wand though you still need to learn to comprehend the logic and the structure and the best practices. You will spend lots of time prompting, testing, deleting everything and trying again. The goal is to learn from it and eventually come up with an improvement. When you do post it in the community thread. `**

**`REQUIRES ORBWALKER CLEAR TOGGLED ON AND BLOCK ORBWALKER MOVEMENT ENABLED`**


## Overview

Infernal Horde is a Lua-based script designed to automate the infernal hordes. This guide provides a high-level overview of the directory structure, core components, and the task manager's role. It also lists the `shouldExecute` functions for each task in the `/tasks` directory to help new developers understand and contribute to the project.

Current Features
- **`When in Horde, horde task runs and navigates to spires / masses, make sure orbwalker clear is on to kill monsters using your rotation`**
- **`Interacts with pylons to select boon/banes based on priority table`**
- **`Picks up Aether`**
- **`Interacts with boss door to check if its locked`**
- **`Enters boss room`**
- **`When bosses are dead switches task to Open Chests`**
- **`Opens Chests based on settings in GUI: Always open GA Chest / Open material, gear, or gold`**


## To-Do

Below is a quick list of things that need to be added, if you would like to tackle these please post in the dev thread and let others know, build in public, and get words of encouragement from other members of the community. 

- **`Clean up repo and remove piteer enums, data etc.`**
- **`Edit Repair task to tp from horde to vendor and back to horde`**

## Known issues

- Undiscovered Monsters at horde perimeter prevents script from continuing
- Getting stuck at door when more waves are needed


## Directory Structure

```
infernal_bored/
├── core/
│   ├── navigation.lua
│   ├── settings.lua
│   ├── task_manager.lua
│   ├── tracker.lua
│   └── utils.lua
├── data/
│   └── enums.lua
├── tasks/
│   ├── explore.lua
│   ├── horde.lua
│   ├── kill_monsters.lua
│   ├── open_chests.lua
│   ├── town_repair.lua
│   ├── town_sell.lua
│   ├── town_salvage.lua
├── gui.lua
└── main.lua
```

## Core Components

### `main.lua`
- Sets up the main script that runs in the background.
- Imports necessary modules.
- Defines functions for updating settings, executing tasks, and rendering the current task.

### `gui.lua`
- Defines the graphical user interface.
- Provides options for enabling/disabling the bot, adjusting settings, and selecting the type of chest to open.

### `core/`
- **`navigation.lua`**: Functions for moving the player character to a target position using direct movement or pathfinding.
- **`settings.lua`**: Contains a table of program settings and a function to update them based on the GUI.
- **`task_manager.lua`**: Manages a list of tasks and executes them based on priority.
- **`tracker.lua`**: Keeps track of various times during the game.
- **`utils.lua`**: Contains various utility functions, including distance calculation, aura and quest checking, actor retrieval, and pathfinding.

### `data/`
- **`enums.lua`**: Defines a table of constants used throughout the game, including quests, portal names, miscellaneous items, positions, and chest types.

### `tasks/`
- **`explore.lua`**: Defines the task for exploring.
- **`horde.lua`**: Defines the task for managing the horde.
- **`kill_monsters.lua`**: Defines the task for killing monsters.
- **`open_chests.lua`**: Defines the task for opening chests.
- **`town_repair.lua`**: Defines the task for repairing items in town.
- **`town_sell.lua`**: Defines the task for selling items in town.
- **`town_salvage.lua`**: Defines the task for salvaging items in town.

## Task Manager

The task manager is a crucial component that manages and executes tasks based on their priority. It ensures that tasks are executed in the correct order, which is essential for the smooth operation of the bot. The task manager's role includes:

- Maintaining a list of tasks.
- Checking if tasks should be executed.
- Executing tasks based on their priority.

## `shouldExecute` Functions

Each task module in the `/tasks` directory includes a `shouldExecute` function that determines whether the task should be executed. Below is a list of these functions for each task:

### `explore.lua`
```lua
shouldExecute = function()
    return not utils.get_closest_enemy()
end
```

### `horde.lua`
```lua
shouldExecute = function()
    return utils.player_in_zone("S05_BSK_Prototype02") 
end
```

### `kill_monsters.lua`
```lua
shouldExecute = function()
    local close_enemy = utils.get_closest_enemy()
    return close_enemy ~= nil
end
```

### `open_chests.lua`
```lua
shouldExecute = function()
    return utils.player_in_zone("S05_BSK_Prototype02") and utils.player_on_quest(2023962)
end
```

### `town_repair.lua`
```lua
shouldExecute = function()
    return utils.player_in_zone("Scos_Cerrigar") 
        and auto_play.get_objective() == objective.repair
end
```

### `town_sell.lua`
```lua
shouldExecute = function()
    return utils.player_in_zone("Scos_Cerrigar") 
        and get_local_player():get_item_count() >= 25
        and settings.loot_modes == gui.loot_modes_enum.SELL
end
```

### `town_salvage.lua`
```lua
shouldExecute = function()
    return utils.player_in_zone("Scos_Cerrigar") 
        and get_local_player():get_item_count() >= 25
        and settings.loot_modes == gui.loot_modes_enum.SALVAGE
end
```

## Getting Started

To get started with contributing to the project, follow these steps:

1. Clone the repository.
2. Familiarize yourself with the directory structure and core components.
3. Review the `shouldExecute` functions for each task to understand the logic behind task execution.
4. Start by making small changes or improvements to the existing codebase.
5. Test your changes thoroughly before submitting a pull request.

We welcome contributions from developers of all skill levels. If you have any questions or need further assistance, feel free to open an issue or reach out to the maintainers.

Happy coding!
