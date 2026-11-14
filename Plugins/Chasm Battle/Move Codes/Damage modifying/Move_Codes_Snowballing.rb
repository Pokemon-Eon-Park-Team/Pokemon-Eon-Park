#===============================================================================
# Power doubles for each consecutive use.
#===============================================================================
class PokeBattle_Move_FuryCutter < PokeBattle_SnowballingMove
    def initialize(battle, move)
        @usageCountEffect = :FuryCutter
        super
    end
end

#===============================================================================
# Power doubles for each consecutive use.
#===============================================================================
class PokeBattle_Move_IceBall < PokeBattle_SnowballingMove
    def initialize(battle, move)
        @usageCountEffect = :Snowball
        super
    end
end

#===============================================================================
# Power doubles for each consecutive use.
#===============================================================================
class PokeBattle_Move_RockRoll < PokeBattle_SnowballingMove
    def initialize(battle, move)
        @usageCountEffect = :RockRoll
        super
    end
end

#===============================================================================
# Counts as a use of Rock Roll, Snowball, or Furycutter.
#===============================================================================
class PokeBattle_Move_OnARoll < PokeBattle_Move
    def pbChangeUsageCounters(user, specialUsage)
        oldEffectValues = {}
        user.eachEffect(true) do |effect, value, data|
            oldEffectValues[effect] = value if data.snowballing_move_counter?
        end
        super
        oldEffectValues.each do |effect, oldValue|
            data = GameData::BattleEffect.get(effect)
            user.effects[effect] = [oldValue + 1, data.maximum].min
        end
    end
end

#===============================================================================
# Power is multiplied by the number of consecutive rounds in which this move was
# used by any Pokémon on the user's side. (Echoed Voice)
#===============================================================================
class PokeBattle_Move_EchoedVoice < PokeBattle_Move
    def pbChangeUsageCounters(user, specialUsage)
        oldCount = user.pbOwnSide.effects[:EchoedVoiceCounter]
        super # Reset all other counters

        # If this is the first time the move is being used on this side this turn
        unless user.pbOwnSide.effectActive?(:EchoedVoiceUsed)
            user.pbOwnSide.effects[:EchoedVoiceCounter] = oldCount
            user.pbOwnSide.incrementEffect(:EchoedVoiceCounter)
        end
        user.pbOwnSide.applyEffect(:EchoedVoiceUsed)
    end

    def pbBaseDamage(baseDmg, user, _target)
        return baseDmg * user.pbOwnSide.effects[:EchoedVoiceCounter]
    end
end

#===============================================================================
# Power increases by 20 for each consecutive use. User heals by 50% of damage dealt.
#===============================================================================
class PokeBattle_Move_HeartRhythm < PokeBattle_SnowballingMove
    def initialize(battle, move)
        @usageCountEffect = :HeartRhythm
        super
    end

    def damageAtCount(baseDmg, count)
        return baseDmg + 20 * count
    end

    def healingMove?; return true; end

    def drainFactor(_user, _target); return 0.5; end

    def pbEffectAgainstTarget(user, target)
        return if target.damageState.hpLost <= 0
        hpGain = (target.damageState.hpLost * drainFactor(user, target)).round
        user.pbRecoverHPFromDrain(hpGain, target, user: user)
    end
end

#===============================================================================
# Hits three times by base, and one extra every time the move is used
# over the course of a battle. (Blades of Grass)
#===============================================================================
class PokeBattle_Move_BladesOfGrass < PokeBattle_Move
    def multiHitMove?; return true; end

    def pbNumHits(user, _targets, _checkingForAI = false)
        return 3 + user.moveUsageCount(@id)
    end
end

#===============================================================================
# Deals different effects depending on which step of the dance it is.
# Step 1: Lower's the target's Speed.
# Step 2: Lower's the target's Attack and Sp. Atk by 2 steps.
# Step 3: Deals double damage.
#===============================================================================
class PokeBattle_Move_WaterfowlDance < PokeBattle_SnowballingMove
    def initialize(battle, move)
        @usageCountEffect = :WaterfowlDance
        super
    end

    def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
        case user.countEffect(@usageCountEffect)
        when 1
            battle.pbDisplay(_INTL("{1} performs the first dance step!",user.pbThis))
            id = :AQUATAIL
        when 2
            battle.pbDisplay(_INTL("{1} performs the second dance step!",user.pbThis))
            id = :WATERFALL
        when 3
            battle.pbDisplay(_INTL("{1} performs the third and final dance step!",user.pbThis))
            id = :CRABHAMMER
        end
        super
    end

    def pbBaseDamage(baseDmg, user, _target)
        baseDmg *= 2 if user.effects[@usageCountEffect] >= 3
        return baseDmg
    end

    def pbEffectAgainstTarget(user, target)
        case user.countEffect(@usageCountEffect)
        when 1
            target.tryLowerStat(:SPEED, user, move: self)
        when 2
            target.pbLowerMultipleStatSteps(ATTACKING_STATS_2, user, move: self)
        end
    end

    def pbEffectAfterAllHits(user, _target)
        if user.effectAtMax?(@usageCountEffect)
            battle.pbDisplay(_INTL("{1} finishes the Waterfowl Dance!", user.pbThis))
            user.disableEffect(@usageCountEffect)
        end
    end
end