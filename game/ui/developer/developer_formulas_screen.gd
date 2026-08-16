class_name DeveloperFormulasScreen
extends Control

signal back_requested

const FORMULA_REFERENCE: String = """[font_size=26][b]Formula base del danno[/b][/font_size]

Danno = (((2 × L ÷ 5) + 2) × P × A ÷ D ÷ 50 + 2) × M

[b]L[/b] = livello dell'Astral attaccante
[b]P[/b] = potenza della mossa
[b]A[/b] = Atk per mosse fisiche, Atkm per mosse magiche
[b]D[/b] = PDef per mosse fisiche, MDef per mosse magiche
[b]M[/b] = insieme dei modificatori finali

[font_size=26][b]Formula completa attiva[/b][/font_size]

(((((((L × 2 ÷ 5) + 2) × P × A ÷ 50) ÷ D) × Mod1) + 2) × CH × Mod2 × Random) × STAB × Tipo1 × Tipo2 × Mod3

[b]Arrotondamenti[/b]
Le divisioni e i passaggi intermedi vengono arrotondati per difetto. Se A effettivo supera 255, A e D vengono entrambi divisi per 4 e arrotondati per difetto.

[b]CH — brutto colpo[/b]
Probabilità base: 10%. CH vale 2 in caso di brutto colpo, altrimenti 1. Un brutto colpo ignora i modificatori applicati alle statistiche di attacco e difesa.

[b]STAB[/b]
Se il tipo della mossa coincide con almeno un tipo dell'attaccante, viene aggiunto al danno floor(danno ÷ 2). Altrimenti il moltiplicatore è neutro.

[b]Tipo1 e Tipo2[/b]
Ogni tipo difensivo applica separatamente 0,5, 1 oppure 2. Tipo2 vale 1 quando il difensore possiede un solo tipo.

[b]Random[/b]
Intero uniforme tra 217 e 255 inclusi, poi divisione per 255. Se il danno prima di Random è esattamente 1, Random vale 1.

[b]Mod1, Mod2 e Mod3[/b]
Riservati a strumenti tenuti, meteo, abilità e condizioni. Attualmente valgono tutti 1.

[color=#8fa6b8]Riferimento di sviluppo in sola lettura. Questa schermata non modifica il combattimento.[/color]"""

@onready var formula_text: RichTextLabel = %FormulaText
@onready var back_button: Button = %BackButton


func _ready() -> void:
	formula_text.text = FORMULA_REFERENCE
	back_button.pressed.connect(_on_back_pressed)


func open() -> void:
	show()
	call_deferred("_focus_back_button")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func get_reference_text() -> String:
	return FORMULA_REFERENCE


func _on_back_pressed() -> void:
	back_requested.emit()


func _focus_back_button() -> void:
	if visible:
		back_button.grab_focus()
