local Wargroove = require("wargroove/wargroove")
local TriggerContext = require("triggers/trigger_context")
local Resumable = require("wargroove/resumable")
local OldEvents = require "wargroove/events"
local Leveling = require "initialized/leveling"
--local inspect = require "inspect"

local Events = {}

local triggerContext = TriggerContext:new({
    state = "",
    fired = {},
    campaignFlags = {},    
    mapFlags = {},
    mapCounters = {},
    party = {},
    campaignCutscenes = {},
    creditsToPlay = ""
})

local triggerList = nil
local triggerConditions = {}
local triggerActions = {}
local pendingDeadUnits = {}
local activeDeadUnits = {}


function Events.init()
    OldEvents.startSession = Events.startSession
    OldEvents.getMatchState = Events.getMatchState
    OldEvents.addToActionsList = Events.addToActionsList
    OldEvents.addToConditionsList = Events.addToConditionsList
    OldEvents.populateTriggerList = Events.populateTriggerList
    OldEvents.addTrigger = Events.addTrigger
    OldEvents.doCheckEvents = Events.doCheckEvents
    OldEvents.checkEvents = Events.checkEvents
    OldEvents.checkConditions = Events.checkConditions
    OldEvents.runActions = Events.runActions
    OldEvents.setMapFlag = Events.setMapFlag
    OldEvents.getTriggerKey = Events.getTriggerKey
    OldEvents.canExecuteTrigger = Events.canExecuteTrigger
    OldEvents.executeTrigger = Events.executeTrigger
    OldEvents.isConditionTrue = Events.isConditionTrue
    OldEvents.runAction = Events.runAction
    OldEvents.reportUnitDeath = Events.reportUnitDeath
end

function Events.startSession(matchState)
    pendingDeadUnits = {}

    Events.populateTriggerList()

    function readVariables(name)
        src = matchState[name]
        dst = triggerContext[name]

        for i, var in ipairs(src) do
            dst[var.id] = var.value
        end
    end

    readVariables("mapFlags")
    readVariables("mapCounters")
    readVariables("campaignFlags")

    for i, var in ipairs(matchState.triggersFired) do
        triggerContext.fired[var] = true
    end

    for i, var in ipairs(matchState.party) do
        table.insert(triggerContext.party, var)
    end

    for i, var in ipairs(matchState.campaignCutscenes) do
        table.insert(triggerContext.campaignCutscenes, var)
    end

    triggerContext.creditsToPlay = matchState.creditsToPlay
end


function Events.getMatchState()
    local result = {}

    function writeVariables(name)
        local src = triggerContext[name]
        local dst = {}
        result[name] = dst

        for k, v in pairs(src) do
            table.insert(dst, { id = k, value = v })
        end
    end

    writeVariables("mapFlags")
    writeVariables("mapCounters")
    writeVariables("campaignFlags")

    result.triggersFired = {}
    for k, v in pairs(triggerContext.fired) do
        table.insert(result.triggersFired, k)
    end

    result.party = {}
    for i, var in ipairs(triggerContext.party) do
        table.insert(result.party, var)
    end

    result.campaignCutscenes = {}
    for i, var in ipairs(triggerContext.campaignCutscenes) do
        table.insert(result.campaignCutscenes, var)
    end

    result.creditsToPlay = triggerContext.creditsToPlay

    return result
end

local additionalActions = {}
local additionalConditions = {}

function Events.addToActionsList(actions)
  table.insert(additionalActions, actions)
end

function Events.addToConditionsList(conditions)
  table.insert(additionalConditions, conditions)
end

function Events.populateTriggerList()
    triggerList = Wargroove.getMapTriggers()
    -- 
    Events.addTrigger(Leveling.loadTrigger())
    
    local Actions = require("triggers/actions")
    local Conditions = require("triggers/conditions")

    Conditions.populate(triggerConditions)
    Actions.populate(triggerActions)

    for i, action in ipairs(additionalActions) do
      action.populate(triggerActions)
    end

    for i, condition in ipairs(additionalConditions) do
      condition.populate(triggerConditions)
    end
end

-- replaces old trigger with id if already exists
function Events.addTrigger(newTrigger)
    local found = false
    for i, trigger in ipairs(triggerList) do
        if (trigger.id == newTrigger.id) then
            table.remove(triggerList, i)
            break
        end
    end
    table.insert(triggerList, newTrigger)
end

function Events.doCheckEvents(state)
    triggerContext.state = state
    triggerContext.deadUnits = pendingDeadUnits

    local newPendingUnits = {}
    for i, unit in ipairs(pendingDeadUnits) do
        if unit.triggeredBy ~= nil then
            table.insert(newPendingUnits, unit)
        end 
    end

    pendingDeadUnits = newPendingUnits

    for triggerNum, trigger in ipairs(triggerList) do
        local newPendingUnits = {}
        for j, unit in ipairs(pendingDeadUnits) do
            if unit.triggeredBy == nil or unit.triggeredBy ~= triggerNum then
                table.insert(newPendingUnits, unit)
            end
        end        

        pendingDeadUnits = newPendingUnits

        for n = 0, 7 do
            triggerContext.triggerInstancePlayerId = n
            if Events.canExecuteTrigger(trigger) then
                Events.executeTrigger(trigger)
                for j, unit in ipairs(pendingDeadUnits) do
                    if unit.triggeredBy == nil then
                        unit.triggeredBy = triggerNum
                        table.insert(triggerContext.deadUnits, unit)
                    end
                end
            end
        end
    end
end


function Events.checkEvents(state)
    return Resumable.run(function ()
       Events.doCheckEvents(state) 
    end)
end

function Events.checkConditions(conditions)
    for i, cond in ipairs(conditions) do
        if not Events.isConditionTrue(cond) then
            return false
        end
    end
    return true
end

function Events.runActions(actions)
    for i, action in ipairs(actions) do
        Events.runAction(action)
    end
end


function Events.setMapFlag(flagId, value)
    triggerContext:setMapFlagById(flagId, value)
end


function Events.getTriggerKey(trigger)
    local key = trigger.id
    if trigger.recurring == "oncePerPlayer" then
        key = key .. ":" .. tostring(triggerContext.triggerInstancePlayerId)
    end
    return key
end


function Events.canExecuteTrigger(trigger)
    -- Check if this trigger supports this player
    if trigger.players[triggerContext.triggerInstancePlayerId + 1] ~= 1 then
        return false
    end

    if trigger.recurring ~= 'start_of_match' then
        if triggerContext:checkState('startOfMatch') then
            return false
        end        
    elseif not triggerContext:checkState('startOfMatch') then
        return false
    end

    if trigger.recurring ~= 'end_of_match' then
        if triggerContext:checkState('endOfMatch') then
            return false
        end        
    elseif not triggerContext:checkState('endOfMatch') then
        return false
    end

    -- Check if it already ran
    if trigger.recurring ~= "repeat" then
        if triggerContext.fired[Events.getTriggerKey(trigger)] ~= nil then
            return false
        end
    end

    -- Check all conditions
    return Events.checkConditions(trigger.conditions)
end


function Events.executeTrigger(trigger)
    triggerContext.fired[Events.getTriggerKey(trigger)] = true
    Events.runActions(trigger.actions)
end


function Events.isConditionTrue(condition)
    local f = triggerConditions[condition.id]
    if f == nil then
        print("Condition not implemented: " .. condition.id)
    else
        triggerContext.params = condition.parameters
       return f(triggerContext)
    end
end


function Events.runAction(action)
    local f = triggerActions[action.id]
    if f == nil then
        print("Action not implemented: " .. action.id)
    else
        print("Executing action " .. action.id)
        triggerContext.params = action.parameters
        f(triggerContext)
    end
end


function Events.reportUnitDeath(id, attackerUnitId, attackerPlayerId, attackerUnitClass)
    local unit = Wargroove.getUnitById(id)
    unit.attackerId = attackerUnitId
    unit.attackerPlayerId = attackerPlayerId
    unit.attackerUnitClass = attackerUnitClass
    table.insert(pendingDeadUnits, unit)
end

return Events