--### HEADER ###--
local Wargroove = require "wargroove/wargroove"
--local inspect = require "inspect"
local Leveling = {}

function Leveling.init()
    --for i= 0, 7 do 
    --    print("i = " .. i)
    --    print(Wargroove.getCurrentPlayerId())
    --    print("Pre")
    --    print("UnitIdAt11 = " .. Wargroove.getUnitAtXY(1, 1))
    --    print("Post")
    --    local units = Wargroove.getAllUnitsForPlayer(i, true)
    --    for key, unit in ipairs(units) do
    --        print("unit = " .. unit)
    --        Leveling.loadStates(unit)
    --    end
    --end    
end
--################--

--### CONSTS ###--
-- how many ranks there are excluding rank 0
local rankCount = 5
-- absolute summand added to the total exp requirements for rankup
--local rankAbsolutes = {0, 0, 0, 0, 0}
-- multiplier for cost added to the total exp requirements for rankup
local rankCostMult = { 
                       [0] = 0.0, 
                       [1] = 1.0, 
                       [2] = 3.0, 
                       [3] = 6.0, 
                       [4] = 10.0,
                       [5] = 15.0
                     }
-- multipliers for effectiveness of units
local rankOffMult = { 
                      [0] = 1.0, 
                      [1] = 1.1, 
                      [2] = 1.2, 
                      [3] = 1.3, 
                      [4] = 1.4,
                      [5] = 1.5
                    }
-- disallowed classes from leveling
local canLevelTable = { 
                        commander = false, 
                        soldier = true, 
                        spearman = true,
                        dog = true,
                        wagon = false,
                        mage = true,
                        archer = true,
                        knight = true,
                        ballista = true,
                        trebuchet = true,
                        giant = true,
                        
                        balloon = false,
                        harpy = true,
                        witch = true,
                        dragon = true,
                        
                        merman = true,
                        travelboat = false,
                        harpoonship = true,
                        turtle = true,
                        warship = true,
                        
                        fieldcom = true
                      }
--##############--

--### LOADING ###--
-- used to enforce one time load 
--local loaded = false
--function getLoaded() return loaded and true end

-- should be called when loading map for each unit
function Leveling.load(units)
    for i, unit in ipairs(units) do
        Leveling.setRankSpriteId(unit, "")
        Leveling.update(unit, 0)
    end
end

-- since refreshing states is complicated all is done using ingame triggers
-- however triggers are not mutable vanilla through api; thus events replaced
-- add this trigger to update all on load
function Leveling.loadTrigger()
    return 
    { 
        id = "rankLoadTrigger",        
        recurring = "repeat",
        players = { 1, 1, 1, 1, 1, 1, 1, 1},
        conditions = 
        { 
            {
                id = "on_load", 
                parameters = {} 
            } 
        },
        actions = 
        { 
            {
                id = "update_leveling",
                parameters = {}
            }
        }
    }
end
--###############--



--### BASICS ###--
-- Checks whether a unit can level
-- defaults to false
function Leveling.canLevel(unit) return (canLevelTable[unit.unitClass.id] ~= nil) and canLevelTable[unit.unitClass.id] end
function Leveling.getExperience(unit) return Wargroove.getUnitState(unit, "experience") end
function Leveling.getRankSpriteId(unit) return Wargroove.getUnitState(unit, "rankSpriteId") end
function Leveling.getRank(unit) return Wargroove.getUnitState(unit, "rank") end

function Leveling.setExperience(unit, value) Wargroove.setUnitState(unit, "experience", value) end
function Leveling.setRankSpriteId(unit, value) Wargroove.setUnitState(unit, "rankSpriteId", value) end
--##############--



--### COMBAT ###--
-- returns the off multiplier for the unit
function Leveling.getOffensiveMultiplier(unit)
    local rank = Leveling.getRank(unit) or 0
    return rankOffMult[tonumber(rank)]
end

-- the damage converted into exp
function Leveling.ecoDamage(defender, preHealth, postHealth)
    local cost = defender.unitClass.cost
    local damage = preHealth - postHealth
    
    return damage * cost * 0.01
end
--##############--



--### MAIN ###--
-- Call to erase and redraw rank sprite after combat
-- Provide gained exp if wanna combine with adding exp
function Leveling.update(unit, gained_exp)
    gained_exp = gained_exp or 0
    if Leveling.canLevel(unit) then        
        local rankGain = Leveling.addExperience(unit, gained_exp)
        Leveling.updateGrooveUI(unit)
        Leveling.drawRankSprite(unit, rankGain)
        Wargroove.updateUnit(unit)
    end
end

-- Adds a value to the units experience and updates rank
-- returns rank difference
function Leveling.addExperience(unit, value)
    local experience = Leveling.getExperience(unit) or 0
    Leveling.setExperience(unit, experience + value)
    return Leveling.updateRank(unit)
end

-- returns an 0-index based array of total required exp for rank
-- index corresponds to rank
function Leveling.getRankExpReqs(unit)
    local cost = unit.unitClass.cost
    
    local retval = { [0] = 0}
    for i = 1, rankCount do
        retval[i] = rankCostMult[i] * cost --rankAbsolutes[i] + rankCostMult[i] * cost
    end
    
    return retval
end

-- returns rank difference
function Leveling.updateRank(unit)    
    local experience = Leveling.getExperience(unit) or 0
    local expReqs = Leveling.getRankExpReqs(unit)
    local oldRank = Leveling.getRank(unit) or 0
    
    for i=1, rankCount do
        if tonumber(experience) < expReqs[i] then             
            Wargroove.setUnitState(unit, "rank", i - 1)
            return i - 1 - tonumber(oldRank)
        end
    end
    Wargroove.setUnitState(unit, "rank", rankCount)
    return rankCount - tonumber(oldRank)
end

--############--



--### TRIGGERS ###--
-- Alters unit experience to match minimum rank requirement
function Leveling.setRank(unit, rank)
    if Leveling.canLevel(unit) then
        rank = math.max(math.min(rank, rankCount), 0)
        Leveling.setExperience(unit, Leveling.getRankExpReqs(unit)[rank])
    end
end
--################--



--### UI ###--
local rankSprites = { 
                      "fx/ranks/rank1",
                      "fx/ranks/rank2",
                      "fx/ranks/rank3",
                      "fx/ranks/rank4",
                      "fx/ranks/rank5"
                    }
                    
-- Adds the unit effect to display rank of a unit and deletes old sprite
function Leveling.drawRankSprite(unit, rankGain)
    rankGain = rankGain or 0
    
    -- sprite deletion
    local rank_sprite = Leveling.getRankSpriteId(unit)
    if rank_sprite ~= nil and rank_sprite ~= "" then
        Wargroove.deleteUnitEffect(rank_sprite, "death")       
        Leveling.setRankSpriteId(unit, "")
    end
    
    -- sprite drawing
    local rank = tonumber(Leveling.getRank(unit)) or 0
    if rank > 0 then
        if rankGain > 0 then
            Wargroove.playMapSound("unitPromote", unit.pos)
            Leveling.setRankSpriteId(unit, Wargroove.spawnUnitEffect(unit.id, rankSprites[rank], "idle", "rankup", true))
        elseif rankGain == 0 then
            Leveling.setRankSpriteId(unit, Wargroove.spawnUnitEffect(unit.id, rankSprites[rank], "idle", "idle", true))
        else
            Leveling.setRankSpriteId(unit, Wargroove.spawnUnitEffect(unit.id, rankSprites[rank], "idle", "rankdown", true))
        end
    end
end

-- Displays progress towards next rank in groove display as percentage
-- 0 percent groove if max rank; avoids 100 percent groove
function Leveling.updateGrooveUI(unit)
    local rankExpReqs = Leveling.getRankExpReqs(unit)
    local rank = Leveling.getRank(unit) or 0
    local experience = Leveling.getExperience(unit) or 0
    local progress = 0.0
    
    if rank == rankCount then 
        progress = 0.0 --100.0
    else
        progress = math.min(99, (tonumber(experience) - rankExpReqs[rank]) / (rankExpReqs[rank + 1] - rankExpReqs[rank]) * 100)
    end
    --Wargroove.unitSetGroove(unit.id, progress)
    unit:setGroove(progress)
end
--##############--



return Leveling
