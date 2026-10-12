extends RefCounted
## Detecta si el juego corre en celular o tablet (o se prueba con --touch).


static func is_touch() -> bool:
	return OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()


## Celular o tablet: se usa el modo más ligero sin importar la calidad elegida.
static func is_phone() -> bool:
	return is_touch()
