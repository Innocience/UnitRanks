local Leveling = require "initialized/leveling"
local Events = require "initialized/events"
local Wargroove = require "wargroove/wargroove"

local Actions = {}


function Actions.init()
  Events.addToActionsList(Actions)
end

function Actions.populate(dst)
    dst["modify_experience"] = Actions.modifyExperience
    dst["modify_rank"] = Actions.modifyRank
    dst["update_leveling"] = Actions.updateLeveling
end

function Actions.modifyExperience(context)
    -- "Modify Experience of {0} at {1} for {2}: {3} {4}%"
    print("in ModifyExp")
    local operation = context:getOperation(3)
    local value = context:getInteger(4)
    local units = context:gatherUnits(2, 0, 1)

    for i, unit in ipairs(units) do
        local newValue = operation(oldValue, value)
        print("before Leveling call")
        Leveling.setExperience(unit, newValue)
        Leveling.update(unit)
    end

    --Wargroove.updateUnits(units) included in Leveling.update

    coroutine.yield()
end

function Actions.modifyRank(context)
    -- "Modify Rank of {0} at {1} for {2}: {3} {4}%"
    local operation = context:getOperation(3)
    local value = context:getInteger(4)
    local units = context:gatherUnits(2, 0, 1)

    for i, unit in ipairs(units) do
        local newValue = operation(oldValue, value)
        Leveling.setRank(unit, newValue)
        Leveling.update(unit)
    end

    --Wargroove.updateUnits(units) included in Leveling.update

    coroutine.yield()
end

function Actions.updateLeveling(context)
    for i = -1, 7 do
        local units = Wargroove.getAllUnitsForPlayer(i, true)
        Leveling.load(units)
    end
    
    coroutine.yield()
end

return Actions