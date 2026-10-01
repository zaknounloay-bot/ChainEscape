class_name ShareLink
## Social: builds and parses challenge links. The ONLY thing a link carries
## is the challenge id - never the message, photo, puzzle or media URL.
##
##   <base>?challenge=<uuid>
##
## Query (not #hash): it survives every messenger and the iOS share sheet,
## it is what static hosts (itch.io CDN today, a dedicated domain later)
## serve unchanged, and the page script can read it before the game loads.
## A #challenge= fragment is still accepted when parsing, so a later switch
## needs no migration. The page never sends its URL to the API (browsers
## send only the origin as Referer), so the id does not leak through it.

const ID_RE := "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

static var _re: RegEx


## True for a well-formed challenge id (a UUID, lower or upper case).
static func is_valid_id(id: String) -> bool:
	if _re == null:
		_re = RegEx.create_from_string(ID_RE)
	return id.length() == 36 and _re.search(id.to_lower()) != null


## "<base>?challenge=<id>" (base's own query / fragment are dropped).
## Empty string if the id is not valid.
static func build(base: String, id: String) -> String:
	if not is_valid_id(id):
		return ""
	var clean := base.get_slice("#", 0).get_slice("?", 0)
	if clean == "":
		return ""
	return "%s?%s=%s" % [clean, SocialConfig.LINK_PARAM, id.to_lower()]


## The challenge id in a URL (query or fragment), lower case; "" if there
## is none or it is malformed.
static func parse(url: String) -> String:
	for part in [url.get_slice("#", 0).get_slice("?", 1), url.get_slice("#", 1)]:
		for pair in String(part).split("&", false):
			var kv := String(pair).split("=", true, 1)
			if kv.size() == 2 and kv[0] == SocialConfig.LINK_PARAM:
				var id := kv[1].uri_decode().strip_edges().to_lower()
				return id if is_valid_id(id) else ""
	return ""


## Base for links made on this device: SocialConfig.SHARE_BASE_URL, else
## the page the game runs on (Web), else "" (desktop without a base).
static func default_base() -> String:
	if SocialConfig.share_base_override != "":
		return SocialConfig.share_base_override
	if SocialConfig.SHARE_BASE_URL != "":
		return SocialConfig.SHARE_BASE_URL
	return SocialWeb.page_base()
