# UnitRanks

With this mod common units can gain experience by attacking enemy units.

Once a unit has gained enough experience it gains a new rank making them slightly stronger.

The relative required experience to gain the next rank is displayed in the groove UI.

## In detail

- All units capable of attacking excluding the commander can gain up to 4 ranks.
- Per rank the unit gains 10 % additional damage adding up to 50% for max rank units.
- The experience required for a unit to reach the next rank is based on the cost of the unit and a factor corresponding to the next rank (1, 3, 6, 10, 15). For example a soldier would require a total of 600 (100 * 6) experience to reach rank 3.
- The amount of experience gained is equal to the amount of economic damage it dealt to the enemy (i.e. damaging a soldier for 60% gives the attacking unit 60 experience).


## Current state
The mod is very likely unbalanced (i.e. Mage easily capable of killing dragon gaining 1250 exp or 2 ranks immediately).
Feedback for balancing or bugs is welcome. I'm ridiculously bad at this game.

## Altered Functions and Files:
- Combat:solveCombat
- Combat:getBestWeapon
- All unitClasses for the 16 different units capable of attacking
- The entirety of events.lua


A huge thanks to Ophelia from Discord for their constant support dealing with lua and the API.
