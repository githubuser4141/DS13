/obj/structure/window
	name = "window"
	desc = "A window."
	icon = 'icons/obj/window.dmi'
	density = 1
	w_class = ITEM_SIZE_NORMAL

	layer = SIDE_WINDOW_LAYER
	anchored = 1.0
	atom_flags = ATOM_FLAG_CHECKS_BORDER
	alpha = 180
	max_health = 14.0
	hitsound = 'sound/effects/Glasshit.ogg'
	var/maximal_heat = T0C + 100 		// Maximal heat before this window begins taking damage from fire
	var/damage_per_fire_tick = 2.0 		// Amount of damage per fire tick. Regular windows are not fireproof so they might as well break quickly.
	var/ini_dir = null
	var/state = 2
	var/reinf = 0
	var/polarized = 0
	var/basestate = "window"
	var/shardtype = /obj/item/material/shard
	var/glasstype = null // Set this in subtypes. Null is assumed strange or otherwise impossible to dismantle, such as for shuttle glass.
	var/silicate = 0 // number of units of silicate
	var/on_frame = FALSE
	var/material_color
	blend_objects = list(/obj/machinery/door, /turf/simulated/wall, /obj/structure/tramwall) // Objects which to blend with
	noblend_objects = list(/obj/machinery/door/window)

	atmos_canpass = CANPASS_PROC

/obj/structure/window/examine(mob/user)
	. = ..(user)

	if(health == max_health)
		to_chat(user, "<span class='notice'>It looks fully intact.</span>")
	else
		var/perc = health / max_health
		if(perc > 0.75)
			to_chat(user, "<span class='notice'>It has a few cracks.</span>")
		else if(perc > 0.5)
			to_chat(user, "<span class='warning'>It looks slightly damaged.</span>")
		else if(perc > 0.25)
			to_chat(user, "<span class='warning'>It looks moderately damaged.</span>")
		else
			to_chat(user, "<span class='danger'>It looks heavily damaged.</span>")
	if(silicate)
		if (silicate < 30)
			to_chat(user, "<span class='notice'>It has a thin layer of silicate.</span>")
		else if (silicate < 70)
			to_chat(user, "<span class='notice'>It is covered in silicate.</span>")
		else
			to_chat(user, "<span class='notice'>There is a thick layer of silicate covering it.</span>")

/obj/structure/window/take_damage(var/amount, var/damtype = BRUTE, var/user, var/used_weapon, var/bypass_resist = FALSE)
	playsound(loc, hitsound, 100, 1)
	.=..()

	if(health > 0)
		if(health < max_health / 4)
			visible_message("[src] looks like it's about to shatter!" )
		else if(health < max_health / 2)
			visible_message("[src] looks seriously damaged!" )
		else if(health < max_health * 3/4)
			visible_message("Cracks begin to appear in [src]!" )

/obj/structure/window/proc/apply_silicate(var/amount)
	if(health < max_health) // Mend the damage
		health = min(health + amount * 3, max_health)
		if(health == max_health)
			visible_message("[src] looks fully repaired." )
	else // Reinforce
		silicate = min(silicate + amount, 100)
		updateSilicate()

/obj/structure/window/proc/updateSilicate()
	if (overlays)
		overlays.Cut()

	var/image/img = image(src.icon, src.icon_state)
	img.color = "#ffffff"
	img.alpha = silicate * 255 / 100
	overlays += img

/obj/structure/window/zero_health()
	shatter()

/obj/structure/window/proc/shatter(var/display_message = 1)
	playsound(src, "shatter", 70, 1)
	if(display_message)
		visible_message("[src] shatters!")

	cast_new(shardtype, is_fulltile() ? 4 : 1, loc)
	if(reinf) cast_new(/obj/item/stack/rods, is_fulltile() ? 4 : 1, loc)
	qdel(src)
	return

/obj/structure/window/zero_health()
    shatter()


//TODO: Make full windows a separate type of window.
//Once a full window, it will always be a full window, so there's no point
//having the same type for both.
/obj/structure/window/proc/is_full_window()
	return (dir == SOUTHWEST || dir == SOUTHEAST || dir == NORTHWEST || dir == NORTHEAST)

/obj/structure/window/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(istype(mover) && mover.checkpass(PASS_FLAG_GLASS))
		return 1
	if(is_full_window())
		return 0	//full tile window, you can't move into it!
	if(get_dir(loc, target) & dir)
		return !density
	else
		return 1


/obj/structure/window/CheckExit(atom/movable/O as mob|obj, target as turf)
	if(istype(O) && O.checkpass(PASS_FLAG_GLASS))
		return 1
	if(get_dir(O.loc, target) == dir)
		return 0
	return 1


/obj/structure/window/hitby(AM as mob|obj)
	..()
	visible_message("<span class='danger'>[src] was hit by [AM].</span>")
	var/tforce = 0
	if(ismob(AM)) // All mobs have a multiplier and a size according to mob_defines.dm
		var/mob/I = AM
		tforce = I.mob_size * 2 * I.throw_multiplier
	else if(isobj(AM))
		var/obj/item/I = AM
		tforce = I.throwforce
	if(reinf) tforce *= 0.25
	if(health - tforce <= 7 && !reinf)
		set_anchored(FALSE)
		step(src, get_dir(AM, src))
	take_damage(tforce)

/obj/structure/window/attack_tk(mob/user as mob)
	user.visible_message("<span class='notice'>Something knocks on [src].</span>")
	playsound(loc, 'sound/effects/Glasshit.ogg', 50, 1)

/obj/structure/window/attack_hand(mob/user as mob)
	user.set_click_cooldown(DEFAULT_ATTACK_COOLDOWN)
	if(HULK in user.mutations)
		user.say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!"))
		user.visible_message("<span class='danger'>[user] smashes through [src]!</span>")
		user.do_attack_animation(src)
		shatter()

	else if (usr.a_intent == I_HURT)

		if (istype(usr,/mob/living/carbon/human))
			var/mob/living/carbon/human/H = usr
			if(H.species.can_shred(H))
				attack_generic(H,25)
				return

		playsound(src.loc, 'sound/effects/glassknock.ogg', VOLUME_HIGH, 1)
		user.do_attack_animation(src)
		usr.visible_message("<span class='danger'>\The [usr] bangs against \the [src]!</span>",
							"<span class='danger'>You bang against \the [src]!</span>",
							"You hear a banging sound.")
	else
		playsound(src.loc, 'sound/effects/glassknock.ogg', VOLUME_HIGH, 1)
		usr.visible_message("[usr.name] knocks on the [src.name].",
							"You knock on the [src.name].",
							"You hear a knocking sound.")
	return


/obj/structure/window/meddle()
	playsound(src.loc, 'sound/effects/glassknock.ogg', VOLUME_HIGH, 1)

/obj/structure/window/attack_generic(var/mob/user, var/damage, var/attack_verb, var/environment_smash)
	if(environment_smash >= 1)
		damage = max(damage, 10)

	if(istype(user))
		user.set_click_cooldown(DEFAULT_ATTACK_COOLDOWN)
		user.do_attack_animation(src)
	if(!damage)
		return
	if(damage > resistance)
		.=..()
	else
		visible_message("<span class='notice'>\The [user] bonks \the [src] harmlessly.</span>")
	return 1

/obj/structure/window/attackby(obj/item/W as obj, mob/user as mob)
	if(!istype(W)) return//I really wish I did not need this

	if(W.item_flags & ITEM_FLAG_NO_BLUDGEON) return

	if(isScrewdriver(W))
		if ((atom_flags & ATOM_FLAG_INDESTRUCTIBLE))
			return
		if(reinf && state >= 1)
			state = 3 - state
			update_nearby_icons()
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, 1)
			to_chat(user, (state == 1 ? "<span class='notice'>You have unfastened the window from the frame.</span>" : "<span class='notice'>You have fastened the window to the frame.</span>"))
		else if(reinf && state == 0)
			set_anchored(!anchored)
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, 1)
			to_chat(user, (anchored ? "<span class='notice'>You have fastened the frame to the floor.</span>" : "<span class='notice'>You have unfastened the frame from the floor.</span>"))
		else if(!reinf)
			set_anchored(!anchored)
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, 1)
			to_chat(user, (anchored ? "<span class='notice'>You have fastened the window to the floor.</span>" : "<span class='notice'>You have unfastened the window.</span>"))
	else if(isCrowbar(W) && reinf && state <= 1)
		if ((atom_flags & ATOM_FLAG_INDESTRUCTIBLE))
			return
		state = 1 - state
		playsound(loc, 'sound/items/Crowbar.ogg', 75, 1)
		to_chat(user, (state ? "<span class='notice'>You have pried the window into the frame.</span>" : "<span class='notice'>You have pried the window out of the frame.</span>"))
	else if(isWrench(W) && !anchored && (!state || !reinf))
		if ((atom_flags & ATOM_FLAG_INDESTRUCTIBLE))
			return
		if(!glasstype)
			to_chat(user, "<span class='notice'>You're not sure how to dismantle \the [src] properly.</span>")
		else
			playsound(src.loc, 'sound/items/Ratchet.ogg', 75, 1)
			visible_message("<span class='notice'>[user] dismantles \the [src].</span>")
			if(dir == SOUTHWEST)
				var/obj/item/stack/material/mats = new glasstype(loc)
				mats.amount = is_fulltile() ? 4 : 2
			else
				new glasstype(loc)
			qdel(src)
	else if(isCoil(W) && reinf && !polarized)
		if ((atom_flags & ATOM_FLAG_INDESTRUCTIBLE))
			return
		var/obj/item/stack/cable_coil/C = W
		if (C.use(1))
			playsound(src.loc, 'sound/effects/sparks1.ogg', 75, 1)
			var/obj/structure/window/reinforced/polarized/P = new(loc)
			P.set_dir(dir)
			P.health = health
			P.state = state
			qdel(src)
	else
		.=..()
		..()
	return

/obj/structure/window/proc/hit(var/damage, var/sound_effect = 1)
	if(reinf) damage *= 0.5
	take_damage(damage)
	return


/obj/structure/window/proc/rotate()
	set name = "Rotate Window Counter-Clockwise"
	set category = "Object"
	set src in oview(1)

	if(usr.incapacitated())
		return 0

	if(anchored)
		to_chat(usr, "It is fastened to the floor therefore you can't rotate it!")
		return 0

	update_nearby_tiles(need_rebuild=1) //Compel updates before
	set_dir(turn(dir, 90))
	updateSilicate()
	update_nearby_tiles(need_rebuild=1)
	return


/obj/structure/window/proc/revrotate()
	set name = "Rotate Window Clockwise"
	set category = "Object"
	set src in oview(1)

	if(usr.incapacitated())
		return 0

	if(anchored)
		to_chat(usr, "It is fastened to the floor therefore you can't rotate it!")
		return 0

	update_nearby_tiles(need_rebuild=1) //Compel updates before
	set_dir(turn(dir, 270))
	updateSilicate()
	update_nearby_tiles(need_rebuild=1)
	return

/obj/structure/window/New(Loc, start_dir=null, constructed=0)
	..()

	//player-constructed windows
	if (constructed)
		set_anchored(FALSE)

	if (start_dir)
		set_dir(start_dir)

	if(is_fulltile())
		max_health *= 2

	health = max_health

	ini_dir = dir

/obj/structure/window/Initialize()
	.=..()

	update_connections(1)
	update_icon()

	update_nearby_tiles(need_rebuild=1)
	update_nearby_icons()


/obj/structure/window/Destroy()
	set_density(0)
	update_nearby_tiles()
	var/turf/location = loc
	. = ..()
	for(var/obj/structure/window/W in orange(location, 1))
		W.update_connections()
		W.update_icon()

/obj/structure/window/Move(NewLoc, Dir = 0, step_x = 0, step_y = 0, var/glide_size_override = 0)
	var/ini_dir = dir
	update_nearby_tiles(need_rebuild=1)
	..()
	set_dir(ini_dir)
	update_nearby_tiles(need_rebuild=1)

//checks if this window is full-tile one
/obj/structure/window/proc/is_fulltile()
	if(dir & (dir - 1))
		return 1
	return 0

/obj/structure/window/proc/set_anchored(var/new_anchored)
	if(anchored == new_anchored)
		return
	anchored = new_anchored
	update_verbs()
	update_nearby_icons()
	update_connections(1)
	update_icon()

//This proc is used to update the icons of nearby windows. It should not be confused with update_nearby_tiles(), which is an atmos proc!
/obj/structure/window/proc/update_nearby_icons()
	update_icon()
	for(var/obj/structure/window/W in orange(src, 1))
		W.update_icon()

//Updates the availabiliy of the rotation verbs
/obj/structure/window/proc/update_verbs()
	if(anchored)
		verbs -= list(/obj/structure/window/proc/rotate, /obj/structure/window/proc/revrotate)
	else
		verbs += list(/obj/structure/window/proc/rotate, /obj/structure/window/proc/revrotate)

// Visually connect with every type of window as long as it's full-tile.
/obj/structure/window/can_visually_connect()
	return ..() && is_fulltile()

/obj/structure/window/can_visually_connect_to(var/obj/structure/S)
	return istype(S, /obj/structure/window)

//merges adjacent full-tile windows into one (blatant ripoff from game/smoothwall.dm)
/obj/structure/window/update_icon()
	//A little cludge here, since I don't know how it will work with slim windows. Most likely VERY wrong.
	//this way it will only update full-tile ones
	overlays.Cut()
	update_onframe()
	layer = FULL_WINDOW_LAYER
	if(!is_fulltile())
		layer = SIDE_WINDOW_LAYER
		icon_state = "[basestate]"
		return

	var/image/I
	icon_state = ""
	if(on_frame)
		for(var/i = 1 to 4)
			if(other_connections[i] != "0")
				I = image(icon, "[basestate]_other_onframe[connections[i]]", dir = 1<<(i-1))
			else
				I = image(icon, "[basestate]_onframe[connections[i]]", dir = 1<<(i-1))
			overlays += I
	else
		for(var/i = 1 to 4)
			if(other_connections[i] != "0")
				I = image(icon, "[basestate]_other[connections[i]]", dir = 1<<(i-1))
			else
				I = image(icon, "[basestate][connections[i]]", dir = 1<<(i-1))
			overlays += I

/obj/structure/window/fire_act(var/datum/gas_mixture/air, var/exposed_temperature, var/exposed_volume, var/multiplier = 1)
	if(exposed_temperature > maximal_heat)
		hit(damage_per_fire_tick, 0)
	..()



/obj/structure/window/basic
	desc = "It looks thin and flimsy. A few knocks with... anything, really should shatter it."
	icon_state = "window"
	glasstype = /obj/item/stack/material/glass
	maximal_heat = T0C + 100
	damage_per_fire_tick = 2.0
	max_health = 12.0
	material_color = GLASS_COLOR
	color = GLASS_COLOR

/obj/structure/window/basic/full
	dir = 5
	icon_state = "window_full"
	resistance = 10

/obj/structure/window/phoronbasic
	name = "phoron window"
	desc = "A borosilicate alloy window. It seems to be quite strong."
	icon_state = "phoronwindow"
	shardtype = /obj/item/material/shard/phoron
	glasstype = /obj/item/stack/material/glass/phoronglass
	maximal_heat = T0C + 2000
	damage_per_fire_tick = 1.0
	max_health = 30.0
	material_color = GLASS_COLOR_PHORON
	color = GLASS_COLOR_PHORON

/obj/structure/window/phoronbasic/full
	dir = 5
	icon_state = "window_full"

/obj/structure/window/phoronreinforced
	name = "reinforced borosilicate window"
	desc = "A borosilicate alloy window, with rods supporting it. It seems to be very strong."
	icon_state = "rwindow"
	basestate = "rwindow"
	shardtype = /obj/item/material/shard/phoron
	glasstype = /obj/item/stack/material/glass/phoronrglass
	reinf = 1
	maximal_heat = T0C + 4000
	damage_per_fire_tick = 1.0 // This should last for 80 fire ticks if the window is not damaged at all. The idea is that borosilicate windows have something like ablative layer that protects them for a while.
	max_health = 40.0
	material_color = GLASS_COLOR_PHORON
	color = GLASS_COLOR_PHORON

/obj/structure/window/phoronreinforced/full
	dir = 5
	icon_state = "window_full"

/obj/structure/window/reinforced
	name = "reinforced window"
	desc = "It looks rather strong. Might take a few good hits to shatter it."
	icon_state = "rwindow"
	basestate = "rwindow"
	max_health = 30.0
	reinf = 1
	maximal_heat = T0C + 750
	damage_per_fire_tick = 2.0
	glasstype = /obj/item/stack/material/glass/reinforced
	material_color = GLASS_COLOR
	color = GLASS_COLOR
	resistance = 10

/obj/structure/window/New(Loc, constructed=0)
	..()

	//player-constructed windows
	if (constructed)
		state = 0
	update_connections(1)

/obj/structure/window/Initialize()
	. = ..()
	layer = is_full_window() ? FULL_WINDOW_LAYER : SIDE_WINDOW_LAYER

/obj/structure/window/reinforced/full
	dir = 5
	icon_state = "rwindow_full"
	resistance = 15

/obj/structure/window/reinforced/full/indestructible
	icon_state = "rwindow_full"
	resistance = 100

/obj/structure/window/reinforced/tinted
	name = "tinted window"
	desc = "It looks rather strong and opaque. Might take a few good hits to shatter it."
	icon_state = "window"
	opacity = 1
	color = GLASS_COLOR_TINTED

/obj/structure/window/reinforced/tinted/frosted
	name = "frosted window"
	desc = "It looks rather strong and frosted over. Looks like it might take a few less hits than a normal reinforced window."
	icon_state = "window"
	max_health = 30
	color = GLASS_COLOR_FROSTED

/obj/structure/window/shuttle
	name = "shuttle window"
	desc = "It looks rather strong. Might take a few good hits to shatter it."
	icon = 'icons/obj/podwindows.dmi'
	icon_state = "window"
	basestate = "window"
	max_health = 40
	reinf = 1
	basestate = "w"
	dir = 5

/obj/structure/window/reinforced/full
	dir = 5
	icon_state = "rwindow_full"
	resistance = 15

/obj/structure/window/reinforced/full/indestructible
	icon_state = "rwindow_full"
	atom_flags = ATOM_FLAG_INDESTRUCTIBLE

/obj/structure/window/reinforced/polarized
	name = "electrochromic window"
	desc = "Adjusts its tint with voltage. Might take a few good hits to shatter it."
	basestate = "rwindow"
	var/id
	polarized = 1

/obj/structure/window/reinforced/polarized/full
	dir = 5
	icon_state = "rwindow_full"

/obj/structure/window/reinforced/polarized/attackby(obj/item/W as obj, mob/user as mob)
	if(isMultitool(W))
		var/t = sanitizeSafe(input(user, "Enter the ID for the window.", src.name, null), MAX_NAME_LEN)
		if (user.get_active_hand() != W)
			return
		if (!in_range(src, user) && src.loc != user)
			return
		t = sanitizeSafe(t, MAX_NAME_LEN)
		if (t)
			src.id = t
			to_chat(user, "<span class='notice'>The new ID of the window is [id]</span>")
		return
	..()

/obj/structure/window/reinforced/polarized/proc/toggle()
	if(opacity)
		animate(src, color=material_color, time=5)
		set_opacity(0)
	else
		animate(src, color=GLASS_COLOR_TINTED, time=5)
		set_opacity(1)

/obj/structure/window/reinforced/crescent/attack_hand()
	return

/obj/structure/window/reinforced/crescent/attackby()
	return

/obj/structure/window/reinforced/crescent/ex_act()
	return

/obj/structure/window/reinforced/crescent/hitby()
	return

/obj/structure/window/reinforced/crescent/take_damage(var/amount, var/damtype = BRUTE, var/user, var/used_weapon, var/bypass_resist = FALSE)
	return

/obj/structure/window/reinforced/crescent/shatter()
	return


/obj/structure/window/proc/update_onframe()
	var/success = FALSE
	var/turf/T = get_turf(src)
	for(var/obj/O in T)
		if(istype(O, /obj/structure/wall_frame))
			success = TRUE
		if(success)
			break
	if(success)
		on_frame = TRUE
	else
		on_frame = FALSE

/obj/machinery/button/windowtint
	name = "window tint control"
	icon = 'icons/obj/power.dmi'
	icon_state = "light0"
	desc = "A remote control switch for electrochromic windows."
	var/range = 7

/obj/machinery/button/windowtint/attack_hand(mob/user as mob)
	if(..())
		return 1

	toggle_tint()

/obj/machinery/button/windowtint/attackby(obj/item/W as obj, mob/user as mob)
	if(isMultitool(W))
		to_chat(user, "<span class='notice'>The ID of the button: [id]</span>")
		return

/obj/machinery/button/windowtint/proc/toggle_tint()
	use_power(5)

	active = !active
	update_icon()

	for(var/obj/structure/window/reinforced/polarized/W in range(src,range))
		if (W.id == src.id || !W.id)
			spawn(0)
				W.toggle()
				return

/obj/machinery/button/windowtint/power_change()
	. = ..()
	if(active && !powered(power_channel))
		toggle_tint()

/obj/machinery/button/windowtint/update_icon()
	icon_state = "light[active]"