/datum/mind
	var/list/learned_spells


//A fix for when a spell is created before a mob is created
/mob/Login()
	..()
	mind?.active = 1		//indicates that the mind is currently synced with a client
	if(mind)
		if(!mind.learned_spells)
			mind.learned_spells = list()
		if(hud_used.ability_master && hud_used.ability_master.spell_objects)
			for(var/atom/movable/screen/ability/spell/screen in hud_used.ability_master.spell_objects)
				var/spell/S = screen.spell
				mind.learned_spells |= S

proc/restore_spells(var/mob/H)
	if(H.mind && H.mind.learned_spells)
		var/list/spells = list()
		for(var/spell/spell_to_remove in H.mind.learned_spells) //remove all the spells from other people.
			if(istype(spell_to_remove.holder,/mob))
				var/mob/M = spell_to_remove.holder
				spells += spell_to_remove
				M.remove_spell(spell_to_remove)

		for(var/spell/spell_to_add in spells)
			H.add_spell(spell_to_add)
	H.hud_used.ability_master.update_abilities(0,H)

/mob/proc/add_spell(var/spell/spell_to_add, var/spell_base = "wiz_spell_ready")
	if(!hud_used.ability_master)
		hud_used.ability_master = new()
	spell_to_add.holder = src
	if(mind)
		if(!mind.learned_spells)
			mind.learned_spells = list()
		mind.learned_spells |= spell_to_add
	hud_used.ability_master.add_spell(spell_to_add, spell_base)
	return 1

/mob/proc/remove_spell(var/spell/spell_to_remove)
	if(!spell_to_remove || !istype(spell_to_remove))
		return

	if(mind)
		mind.learned_spells -= spell_to_remove
	if (hud_used.ability_master)
		hud_used.ability_master.remove_ability(hud_used.ability_master.get_ability_by_spell(spell_to_remove))
	return 1

/mob/proc/silence_spells(var/amount = 0)
	if(amount < 0)
		return

	if(!hud_used.ability_master)
		return

	hud_used.ability_master.silence_spells(amount)