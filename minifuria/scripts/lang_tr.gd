class_name LangTr
extends Translation
## Tradução entregue ao Godot (TranslationServer): todo Label, Button, dica e tr() passam por aqui.
## Quem decide o texto em inglês é Lang.lookup (frases exatas, formatos com números/nomes e pedaços).


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	if not Lang.en():
		return &""
	return StringName(Lang.lookup(String(src_message)))
