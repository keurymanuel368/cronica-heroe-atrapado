extends RefCounted
## Detecta si el juego corre en celular o tablet (o se prueba con --touch).


static func is_touch() -> bool:
	return OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
