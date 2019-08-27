local Wargroove = require "wargroove/wargroove"
local OldCombat = require "wargroove/combat"
local Leveling = require "initialized/leveling"

local Combat = {}

function Combat.init()
    OldCombat.solveCombat = Combat.solveCombat
    OldCombat.getBestWeapon = Combat.getBestWeapon
end

function Combat:getBestWeapon(attacker, defender, delta, moved, facing)
	assert(facing ~= nil)

	local weapons = attacker.unitClass.weapons
		for i, weapon in ipairs(weapons) do
      if self:canUseWeapon(weapon, moved, delta, facing) then
				local dmg = Wargroove.getWeaponDamage(weapon, defender, facing) * Leveling.getOffensiveMultiplier(attacker)
            if dmg > 0.0001 then
                return weapon, dmg
            end
        end
    end

	return nil, 0.0
end

function Combat:solveCombat(attackerId, defenderId, attackerPath, solveType)
	local attacker = Wargroove.getUnitById(attackerId)
	assert(attacker ~= nil)
	local defender = Wargroove.getUnitById(defenderId)
	assert(defender ~= nil)

	local results = {
		attackerHealth = attacker.health,
		defenderHealth = defender.health,
		attackerAttacked = false,
		defenderAttacked = false,
		hasCounter = false,
		hasAttackerCrit = false
	}

	local e0 = self:getEndPosition(attackerPath, attacker.pos)
	Wargroove.pushUnitPos(attacker, e0)

    -- Attack
	local attackResult
	attackResult, results.hasAttackerCrit = self:solveRound(attacker, defender, solveType, false, attacker.pos, defender.pos, attackerPath)
	if attackResult ~= nil then
		results.defenderHealth = attackResult
		results.attackerAttacked = true
		if results.defenderHealth < 1 and solveType == "random" then
			results.defenderHealth = 0
		end
	end

    -- Counter
	if results.defenderHealth > 0 then
		local damagedDefender = {
			id = defender.id,
			pos = defender.pos,
			startPos = defender.startPos,
			playerId = defender.playerId,
			health = results.defenderHealth,
			unitClass = defender.unitClass,
			unitClassId = defender.unitClassId,
			garrisonClassId = defender.garrisonClassId,
			state = defender.state
		}
		local defenderResult
		defenderResult, results.hasDefenderCrit = self:solveRound(damagedDefender, attacker, solveType, true, defender.pos, attacker.pos, {defender.pos})
		if defenderResult ~= nil then
			results.attackerHealth = defenderResult
			results.defenderAttacked = true
			results.hasCounter = true
			if results.attackerHealth < 1 and solveType == "random" then
				results.attackerHealth = 0
			end
		end
	end
    
    -- Experience distribution
    if solveType == "random" then
        local attEcoDamage = Leveling.ecoDamage(defender, defender.health, results.defenderHealth)
        
        Leveling.update(attacker, attEcoDamage)
        
        if results.defenderHealth > 0 then
            local defEcoDamage = Leveling.ecoDamage(attacker, attacker.health, results.attackerHealth)
            
            Leveling.update(defender, defEcoDamage)
        end
    end
    
	Wargroove.popUnitPos()
	
	return results
end

return Combat
