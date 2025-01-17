/obj/machinery/r_n_d/server
	name = "R&D Server"
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "server"
	var/datum/research/files
	health = 100
	var/list/id_with_upload = list()	//List of R&D consoles with upload to server access.
	var/list/id_with_download = list()	//List of R&D consoles with download from server access.
	var/id_with_upload_string = ""		//String versions for easy editing in map editor.
	var/id_with_download_string = ""
	var/server_id = 0
	var/produces_heat = 1
	idle_power_usage = 800
	var/delay = 10
	req_access = list(access_cscio) //Only the R&D can change server settings.
	circuit = /obj/item/circuitboard/rdserver

/obj/machinery/r_n_d/server/Initialize()
	.=..()
	SSresearch.servers += src

/obj/machinery/r_n_d/server/Destroy()
	SSresearch.servers -= src
	.=..()

/obj/machinery/r_n_d/server/RefreshParts()
	var/tot_rating = 0
	for(var/obj/item/stock_parts/SP in src)
		tot_rating += SP.rating
	idle_power_usage /= max(1, tot_rating)

/obj/machinery/r_n_d/server/Initialize()
	. = ..()
	if(!files)
		files = new /datum/research(src)
	var/list/temp_list
	if(!id_with_upload.len)
		temp_list = list()
		temp_list = splittext(id_with_upload_string, ";")
		for(var/N in temp_list)
			id_with_upload += text2num(N)
	if(!id_with_download.len)
		temp_list = list()
		temp_list = splittext(id_with_download_string, ";")
		for(var/N in temp_list)
			id_with_download += text2num(N)

/obj/machinery/r_n_d/server/Process()
	var/datum/gas_mixture/environment = loc.return_air()
	switch(environment.temperature)
		if(0 to T0C)
			health = min(100, health + 1)
		if(T0C to (T20C + 20))
			health = between(0, health, 100)
		if((T20C + 20) to (T0C + 70))
			health = max(0, health - 1)
	if(health <= 0)
		files.forget_random_technology()
	if(delay)
		delay--
	else
		produce_heat()
		delay = initial(delay)

/obj/machinery/r_n_d/server/proc/produce_heat()
	if(!produces_heat)
		return

	if(!use_power)
		return

	if(!(stat & (NOPOWER|BROKEN))) //Blatently stolen from telecoms
		var/turf/simulated/L = loc
		if(istype(L))
			var/datum/gas_mixture/env = L.return_air()

			var/transfer_moles = 0.25 * env.total_moles

			var/datum/gas_mixture/removed = env.remove(transfer_moles)

			if(removed)
				var/heat_produced = idle_power_usage	//obviously can't produce more heat than the machine draws from it's power source

				removed.add_thermal_energy(heat_produced)

			env.merge(removed)

/obj/machinery/r_n_d/server/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if(default_deconstruction_screwdriver(user, O))
		return
	if(default_deconstruction_crowbar(user, O))
		return
	if(default_part_replacement(user, O))
		return

/obj/machinery/computer/rdservercontrol
	name = "R&D Server Controller"
	icon_keyboard = "rd_key"
	icon_screen = "rdcomp"
	light_color = "#a97faa"
	circuit = /obj/item/circuitboard/rdservercontrol
	var/screen = 0
	var/obj/machinery/r_n_d/server/temp_server
	var/list/servers = list()
	var/list/consoles = list()
	var/badmin = 0

/obj/machinery/computer/rdservercontrol/CanUseTopic(user)
	if(!allowed(user) && !emagged)
		to_chat(user, "<span class='warning'>You do not have the required access level</span>")
		return STATUS_CLOSE
	return ..()

/obj/machinery/computer/rdservercontrol/OnTopic(user, href_list, state)
	if(href_list["main"])
		screen = 0
		. = TOPIC_REFRESH

	else if(href_list["access"] || href_list["data"] || href_list["transfer"])
		temp_server = null
		consoles = list()
		servers = list()
		for(var/obj/machinery/r_n_d/server/S as anything in SSresearch.servers)
			if(S.server_id == text2num(href_list["access"]) || S.server_id == text2num(href_list["data"]) || S.server_id == text2num(href_list["transfer"]))
				temp_server = S
				break
		if(href_list["access"])
			screen = 1
			for(var/obj/machinery/computer/rdconsole/C in SSmachines.machinery)
				if(C.sync)
					consoles += C
		else if(href_list["data"])
			screen = 2
		else if(href_list["transfer"])
			screen = 3
			for(var/obj/machinery/r_n_d/server/S as anything in SSresearch.servers)
				if(S == src)
					continue
				servers += S
		. = TOPIC_REFRESH

	else if(href_list["upload_toggle"])
		var/num = text2num(href_list["upload_toggle"])
		if(num in temp_server.id_with_upload)
			temp_server.id_with_upload -= num
		else
			temp_server.id_with_upload += num
		. = TOPIC_REFRESH

	else if(href_list["download_toggle"])
		var/num = text2num(href_list["download_toggle"])
		if(num in temp_server.id_with_download)
			temp_server.id_with_download -= num
		else
			temp_server.id_with_download += num
		. = TOPIC_REFRESH

	else if(href_list["reset_tech"])
		var/choice = tgui_alert(user, "Technology Data Rest", "Are you sure you want to reset this technology to its default data? Data lost cannot be recovered.", list("Continue", "Cancel"))
		if(choice == "Continue" && CanUseTopic(user, state))
			temp_server.files.forget_all(href_list["reset_tech"])

	else if(href_list["reset_techology"])
		var/choice = tgui_alert(user, "Techology Deletion", "Are you sure you want to delete this techology? Data lost cannot be recovered.", list("Continue", "Cancel"))

		if(choice == "Continue" && CanUseTopic(user, state))
			temp_server.files.forget_techology( SSresearch.all_technologies[href_list["reset_design"]] )

	updateUsrDialog()

/obj/machinery/computer/rdservercontrol/attack_hand(mob/user as mob)
	if(stat & (BROKEN|NOPOWER))
		return
	user.set_machine(src)
	var/dat = ""

	switch(screen)
		if(0) //Main Menu
			dat += "Connected Servers:<BR><BR>"

			for(var/obj/machinery/r_n_d/server/S as anything in SSresearch.servers)
				dat += "[S.name] || "
				dat += "<A href='?src=\ref[src];access=[S.server_id]'> Access Rights</A> | "
				dat += "<A href='?src=\ref[src];data=[S.server_id]'>Data Management</A>"
				if(badmin) dat += " | <A href='?src=\ref[src];transfer=[S.server_id]'>Server-to-Server Transfer</A>"
				dat += "<BR>"

		if(1) //Access rights menu
			dat += "[temp_server.name] Access Rights<BR><BR>"
			dat += "Consoles with Upload Access<BR>"
			for(var/obj/machinery/computer/rdconsole/C in consoles)
				var/turf/console_turf = get_turf(C)
				dat += "* <A href='?src=\ref[src];upload_toggle=[C.id]'>[console_turf.loc]" //FYI, these are all numeric ids, eventually.
				if(C.id in temp_server.id_with_upload)
					dat += " (Remove)</A><BR>"
				else
					dat += " (Add)</A><BR>"
			dat += "Consoles with Download Access<BR>"
			for(var/obj/machinery/computer/rdconsole/C in consoles)
				var/turf/console_turf = get_turf(C)
				dat += "* <A href='?src=\ref[src];download_toggle=[C.id]'>[console_turf.loc]"
				if(C.id in temp_server.id_with_download)
					dat += " (Remove)</A><BR>"
				else
					dat += " (Add)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

		if(2) //Data Management menu
			dat += "[temp_server.name] Data ManagementP<BR><BR>"
			dat += "Known Tech Trees<BR>"
			for(var/tech_tree in temp_server.files.tech_trees_shown)
				var/datum/tech/T = SSresearch.tech_trees[tech_tree]
				dat += "* [T.name] "
				dat += "<A href='?src=\ref[src];reset_tech=[T.id]'>(Reset)</A><BR>" //FYI, these are all strings.
			dat += "Known Technologies<BR>"
			for(var/techology_id in temp_server.files.researched_tech)
				var/datum/technology/T = SSresearch.all_technologies[techology_id]
				dat += "* [T.name] "
				dat += "<A href='?src=\ref[src];reset_techology=[T.id]'>(Delete)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

		if(3) //Server Data Transfer
			dat += "[temp_server.name] Server to Server Transfer<BR><BR>"
			dat += "Send Data to what server?<BR>"
			for(var/obj/machinery/r_n_d/server/S in servers)
				dat += "[S.name] <A href='?src=\ref[src];send_to=[S.server_id]'> (Transfer)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"
	user << browse("<TITLE>R&D Server Control</TITLE><HR>[dat]", "window=server_control;size=575x400")
	onclose(user, "server_control")
	return

/obj/machinery/computer/rdservercontrol/emag_act(var/remaining_charges, var/mob/user)
	if(!emagged)
		playsound(src.loc, 'sound/effects/sparks4.ogg', 75, 1)
		emagged = 1
		to_chat(user, "<span class='notice'>You you disable the security protocols.</span>")
		src.updateUsrDialog()
		return 1

/obj/machinery/r_n_d/server/robotics
	name = "Robotics R&D Server"
	id_with_upload_string = "1;2"
	id_with_download_string = "1;2"
	server_id = 2

/obj/machinery/r_n_d/server/core
	name = "Core R&D Server"
	id_with_upload_string = "1"
	id_with_download_string = "1"
	server_id = 1
