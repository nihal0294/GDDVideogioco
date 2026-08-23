class_name AstralSynergyCatalog
extends RefCounted

const DEFINITIONS: Array[Dictionary] = [
	{
		"id": AstralSpecies.DINOSAUR,
		"tiers": [
			[2, "Al primo ingresso in campo ottiene +1 Atk."],
			[4, "Dopo un KO, la prossima mossa a caricamento richiede 1 turno in meno."],
			[6, "Una volta per battaglia resiste a un KO con 1 HP e ignora il prossimo caricamento."],
		],
	},
	{
		"id": AstralSpecies.AMPHIBIAN,
		"tiers": [
			[2, "Ogni 3 turni in campo recupera 1/16 degli HP massimi."],
			[4, "La cura ogni 3 turni aumenta a 1/8 degli HP massimi."],
			[6, "Ogni rigenerazione rimuove anche un'alterazione di stato."],
		],
	},
	{
		"id": AstralSpecies.AQUATIC,
		"tiers": [
			[2, "Dopo 4 turni consecutivi in campo ottiene +1 Spd."],
			[4, "Ottiene +1 Spd ogni 3 turni consecutivi, fino a +2."],
			[6, "Ottiene +1 Spd ogni 2 turni consecutivi, fino a +3."],
		],
	},
	{
		"id": AstralSpecies.TERRESTRIAL,
		"tiers": [
			[3, "Al primo ingresso in campo ottiene +1 PDef."],
			[5, "Dopo 3 turni consecutivi in campo ottiene un ulteriore +1 PDef."],
		],
	},
	{
		"id": AstralSpecies.SYNTHETIC,
		"tiers": [
			[3, "Le mosse a caricamento diventano disponibili 1 turno prima."],
			[5, "Dopo una mossa a caricamento, la successiva riceve un'ulteriore riduzione di 1 turno."],
		],
	},
	{
		"id": AstralSpecies.BEAST,
		"tiers": [
			[2, "Dopo aver inflitto danno per 2 turni consecutivi ottiene +1 Atk."],
			[5, "Bastano 2 attacchi consecutivi; il limite della sinergia diventa +2 Atk."],
		],
	},
	{
		"id": AstralSpecies.AERIAL,
		"tiers": [
			[2, "Dopo 2 turni consecutivi in campo ottiene +1 Spd."],
			[4, "Il bonus si attiva dopo 1 turno completo in campo."],
			[5, "Agendo per primo per 3 turni consecutivi ottiene un altro +1 Spd, fino a +2."],
		],
	},
	{
		"id": AstralSpecies.FAIRY,
		"tiers": [
			[3, "Una volta per battaglia, ogni Fatato schiva la prima mossa offensiva nemica."],
			[6, "Il Velo si rigenera dopo 3 turni consecutivi in campo senza essere colpito."],
		],
	},
	{
		"id": AstralSpecies.INSECT,
		"tiers": [
			[2, "3 attacchi sullo stesso nemico lo Infestano per 3 turni: -1/16 HP a fine turno."],
			[3, "Sono sufficienti 2 attacchi per applicare Infestazione."],
			[5, "L'Infestazione passa al sostituto mantenendo i turni rimasti."],
		],
	},
	{
		"id": AstralSpecies.COLD,
		"tiers": [
			[2, "3 attacchi sullo stesso nemico applicano Assideramento per il turno seguente."],
			[4, "Bastano 2 attacchi; l'Assiderato non può usare mosse di costo 4 o 5."],
		],
	},
	{
		"id": AstralSpecies.HOT,
		"tiers": [
			[2, "Dopo 2 turni consecutivi colpito, il nemico è Surriscaldato per 3 turni e non può ripetere la stessa mossa."],
			[5, "Le mosse offensive del Surriscaldato costano 1/16 HP, oppure 1/8 con costo 4 o 5."],
		],
	},
	{
		"id": AstralSpecies.ETHEREAL,
		"tiers": [
			[2, "Dopo 2 mosse Etereo il bersaglio è Confuso per 2 turni."],
			[4, "Confusione dura 3 turni e l'auto-colpo infligge danno diretto medio."],
			[6, "Alla fine della Confusione segue 1 turno di Disorientamento."],
		],
	},
	{
		"id": AstralSpecies.CRYSTAL,
		"tiers": [
			[3, "Riflette all'attaccante 1/8 del danno offensivo diretto subito."],
			[6, "Riflette 1/4; contro colpi superefficaci usa il danno neutro."],
		],
	},
	{
		"id": AstralSpecies.DRAGON,
		"tiers": [
			[3, "Dopo danni in 2 turni consecutivi, la prossima mossa offensiva ottiene +1 Priorità."],
			[5, "Dopo un KO può attaccare nel turno seguente senza pagare il costo."],
			[6, "Una volta per ingresso, il terzo attacco consecutivo ripete subito la mossa se disponibile."],
		],
	},
	{
		"id": AstralSpecies.FOSSIL,
		"tiers": [
			[3, "Una volta per battaglia, il primo Fossile KO torna a fine turno con 1/4 HP."],
			[4, "Una volta per battaglia riporta un alleato KO a 1/2 HP."],
		],
	},
	{
		"id": AstralSpecies.LUCENT,
		"tiers": [
			[2, "Una volta per ingresso riflette la prima alterazione negativa sull'avversario."],
			[5, "Può riflettere anche la prima riduzione di statistica."],
		],
	},
	{
		"id": AstralSpecies.DARK,
		"tiers": [
			[3, "Sotto il 50% HP del nemico ignora +1 PDef o MDef derivante da potenziamenti."],
			[4, "Sotto il 25% HP, la prima mossa offensiva contro il bersaglio ottiene +1 Priorità."],
			[6, "Una volta per battaglia, dopo un KO la prossima mossa ignora il caricamento."],
		],
	},
	{
		"id": AstralSpecies.EPIC,
		"tiers": [
			[2, "Il prossimo Epico eredita per un uso l'ultima mossa generica dell'Epico KO."],
			[4, "Può ereditare mosse uniche e conservarle dopo un KO fino all'uscita dal campo."],
		],
	},
	{
		"id": AstralSpecies.MYTHICAL,
		"tiers": [
			[2, "Una volta per battaglia ritira un fallimento, un brutto colpo subito o un effetto secondario fallito."],
			[3, "Una volta per battaglia trasforma in neutrale la prima immunità elementale subita."],
		],
	},
	{
		"id": AstralSpecies.NATURE,
		"tiers": [
			[3, "Ogni 3 turni l'Astral attivo recupera 1/16 degli HP massimi."],
			[4, "Recupera 1/8 HP e ogni seconda attivazione rimuove un'alterazione."],
			[5, "Con il sesto slot libero evoca per la battaglia una Manifestazione Naturale."],
		],
	},
	{
		"id": AstralSpecies.MOUSE,
		"tiers": [
			[2, "Gli attacchi colpiscono 2 volte: 100% + 50%."],
			[3, "Gli attacchi colpiscono 3 volte: 100% + 50% + 25%."],
			[4, "I colpi sono pari ai Topi nel party, dimezzando ogni colpo successivo."],
		],
	},
	{
		"id": AstralSpecies.COSMIC,
		"tiers": [
			[4, "All'ingresso ottiene +1 alla statistica più alta."],
			[5, "Ottiene +1 anche alla seconda statistica più alta."],
			[6, "Ottiene +1 a tutte le altre statistiche, esclusi gli HP."],
		],
	},
	{
		"id": AstralSpecies.FIGHTER,
		"tiers": [
			[2, "Dopo 2 mosse fisiche a segno, la successiva ottiene +1 Priorità."],
			[4, "Dopo 3 colpi fisici usa subito una mossa fisica costo 0 casuale a Potenza dimezzata."],
		],
	},
	{
		"id": AstralSpecies.TOXIC,
		"tiers": [
			[2, "Ogni attacco applica una Dose Tossica; a 3 Dosi causa Veleno da 1/16 HP."],
			[4, "Bastano 2 Dosi Tossiche per Avvelenare."],
			[5, "Il Veleno diventa Tossina Grave e cresce di 1/16 HP ogni turno."],
		],
	},
]


static func get_definitions() -> Array[Dictionary]:
	return DEFINITIONS.duplicate(true)


static func get_definition(species_id: StringName) -> Dictionary:
	for definition: Dictionary in DEFINITIONS:
		if StringName(definition.get("id", "")) == species_id:
			return definition.duplicate(true)
	return {}


static func get_tiers(species_id: StringName) -> Array:
	var definition := get_definition(species_id)
	return definition.get("tiers", []) as Array


static func get_active_tier(species_id: StringName, party_count: int) -> int:
	var active_tier := 0
	for tier: Variant in get_tiers(species_id):
		if tier is Array and (tier as Array).size() >= 2:
			var required_count := int((tier as Array)[0])
			if party_count >= required_count:
				active_tier = required_count
	return active_tier


static func get_maximum_tier(species_id: StringName) -> int:
	var tiers := get_tiers(species_id)
	if tiers.is_empty():
		return 0
	return int((tiers.back() as Array)[0])
