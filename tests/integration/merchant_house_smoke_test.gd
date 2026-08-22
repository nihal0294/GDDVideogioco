extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_main := load("res://game/main/main.tscn") as PackedScene
	_expect(packed_main != null, "Scena Main non caricabile.")
	if packed_main == null:
		_finish()
		return
	var main := packed_main.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame

	var inventory := main.get_node_or_null("Inventory") as Inventory
	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var profile := main.get_node_or_null("PlayerProfile") as PlayerProfile
	var ui := main.get_node_or_null("GameUI") as GameUI
	var forest := main.get_node_or_null("WorldMap") as VerdantValley
	_expect(inventory != null and roster != null and profile != null and ui != null, "Sistemi globali mancanti.")
	_expect(forest != null, "Foresta iniziale non valida.")
	if inventory == null or roster == null or profile == null or ui == null or forest == null:
		main.queue_free()
		await process_frame
		_finish()
		return

	var exterior := forest.get_node_or_null("MerchantHouseExterior") as Node3D
	var entrance := forest.get_node_or_null("MerchantHouseExterior/EntranceDoor") as BuildingDoor
	_expect(exterior != null, "Casa esterna mancante.")
	_expect(
		entrance != null and entrance.destination_map_id == &"merchant_house",
		"Porta esterna non configurata per l'interno."
	)
	_expect(exterior.get_node_or_null("Collisions") is StaticBody3D, "Collisioni della casa mancanti.")

	var rune := inventory.get_item_definition(&"runa_base")
	_expect(rune != null, "Runa Base assente dal catalogo inventario.")
	if rune != null:
		_expect(not rune.consumable, "La Runa Base risulta usabile dal menu.")
		_expect(rune.buy_price == 100 and rune.get_sell_price() == 10, "Prezzi della Runa Base errati.")

	profile.add_florins(500)
	ui.shop_screen.open()
	_select_shop_item(ui.shop_screen, &"runa_base")
	ui.shop_screen.call("_on_action_pressed")
	_expect(inventory.get_quantity(&"runa_base") == 1, "Acquisto della runa fallito.")
	_expect(profile.florins == 400, "L'acquisto non sottrae il prezzo corretto.")
	ui.shop_screen.call("_toggle_mode")
	_select_shop_item(ui.shop_screen, &"runa_base")
	ui.shop_screen.call("_on_action_pressed")
	_expect(inventory.get_quantity(&"runa_base") == 0, "Vendita della runa fallita.")
	_expect(profile.florins == 410, "La vendita non rende un decimo del prezzo.")
	ui.shop_screen.close()
	ui.call("_sync_pause_state")

	var changed := bool(main.call("_replace_world_map", &"merchant_house", &"entrance", true))
	_expect(changed, "Ingresso nella mappa interna fallito.")
	var house := main.get_node_or_null("WorldMap") as MerchantHouse
	_expect(house != null and house.get_map_id() == &"merchant_house", "Mappa interna errata.")
	if house != null:
		_expect(house.get_node_or_null("Collisions") is StaticBody3D, "Collisioni interne mancanti.")
		_expect(house.facilities.get_child_count() == 5, "Numero di servizi interni errato.")
		_expect(house.exit_door.destination_map_id == &"verdant_forest", "Porta di uscita errata.")

	var initial_total := roster.get_total_astral_count()
	ui.astral_exchange_screen.call("_on_gift_pressed")
	_expect(roster.get_total_astral_count() == initial_total + 1, "Regalo Astral fallito.")
	_expect(profile.has_claimed_reward(&"merchant_house_silphy_gift"), "Regalo non persistito nel profilo.")
	ui.astral_exchange_screen.call("_on_gift_pressed")
	_expect(roster.get_total_astral_count() == initial_total + 1, "Il regalo può essere reclamato due volte.")
	var offered := roster.give_astral(AstralCatalog.load_definition(&"flambore"), 3)
	var total_before_trade := roster.get_total_astral_count()
	var received := roster.trade_astral(
		offered,
		&"flambore",
		AstralCatalog.load_definition(&"vorix"),
		1
	)
	_expect(
		received != null
		and received.definition.astral_id == &"vorix"
		and received.level == 1,
		"Scambio Astral non sostituisce l'esemplare richiesto."
	)
	_expect(roster.get_total_astral_count() == total_before_trade, "Lo scambio altera il numero di Astral.")

	var active := roster.get_active_astral()
	if active != null:
		active.current_health = 0
		main.call("_on_facility_action_requested", &"healer", main.get_node("Player"))
		_expect(active.current_health == active.get_max_health(), "Guaritrice non rianima la squadra.")
	main.call("_on_facility_action_requested", &"astral_box", main.get_node("Player"))
	_expect(ui.astral_box_screen.visible, "Il Box fisico non apre il Box Astral.")
	ui.astral_box_screen.close()
	ui.call("_sync_pause_state")
	var florins_before_game := profile.florins
	ui.coin_flip_screen.set_random_seed(1234)
	await ui.coin_flip_screen.call("_play", true)
	_expect(
		profile.florins == florins_before_game - 10
		or profile.florins == florins_before_game + 10,
		"Testa o croce non applica correttamente puntata e vincita."
	)

	_expect(bool(main.call("_replace_world_map", &"verdant_forest", &"from_merchant_house", true)), "Ritorno alla foresta fallito.")
	_expect(StringName(main.call("get_current_map_id")) == &"verdant_forest", "Mappa di ritorno errata.")

	main.queue_free()
	await process_frame
	_finish()


func _select_shop_item(shop: ShopScreen, item_id: StringName) -> void:
	for index: int in shop.item_list.item_count:
		if StringName(shop.item_list.get_item_metadata(index)) == item_id:
			shop.item_list.select(index)
			shop.call("_refresh_details")
			return


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Merchant house smoke test: PASS")
		quit(0)
	else:
		print("Merchant house smoke test: FAIL (%d errori)" % _failures.size())
		quit(1)
