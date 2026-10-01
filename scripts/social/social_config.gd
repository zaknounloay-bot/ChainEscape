class_name SocialConfig
## Social: every network / share setting in ONE place. Only public values
## belong here - never a service_role key, secret key or database password.
## Moving to another endpoint or domain = editing this file only.

## The deployed Supabase Edge Function "chain-escape-api", e.g.
## "https://<project-ref>.supabase.co/functions/v1/chain-escape-api".
## Empty = sharing is off in this build (CREATE still works, locally).
const API_URL := "https://ydsippgwwdzwupbyrpfw.supabase.co/functions/v1/chain-escape-api"
## Public anon / publishable key, only if the function requires it (it is
## designed to be public). Sent as "apikey" + "Authorization: Bearer".
## Leave empty when the function is deployed without JWT verification
## (chain-escape-api is: recipients open challenges without logging in).
const API_PUBLIC_KEY := ""

## Where share links point. Empty = the page the game is running on (Web),
## so the current itch.io / Web deployment works without changes. Set it
## when Chain Escape gets its own domain, e.g. "https://chainescape.app/".
const SHARE_BASE_URL := ""
## Query parameter that carries the challenge id (only the id).
const LINK_PARAM := "challenge"
const SHARE_TITLE := "Chain Escape"
const SHARE_TEXT := "I made a Chain Escape for you 🔗 Can you unlock it?"

## Network limits (the server enforces its own; these fail early and kindly).
const TIMEOUT_SEC := 30.0
## Below the bucket's 5 MB limit; a 1080 px JPEG is ~100-400 KB.
const MAX_IMAGE_BYTES := 4 * 1024 * 1024
const MAX_REQUEST_BYTES := 6 * 1024 * 1024

## Tests only: replaces API_URL (headless tests set it directly; Web tests
## through window.ceApiUrl when window.ceTestHooks is set). "off" turns
## sharing off (local 0.2B mode) for tests of the local flow.
static var api_url_override := ""
static var timeout_override := 0.0  # tests: seconds (0 = TIMEOUT_SEC)
static var share_base_override := ""  # tests: link base outside the Web build
## Tests only: accept a plain-http photo URL (the local mock serves one).
static var allow_http_media := false
static var _web_override_checked := false


static func api_url() -> String:
	if api_url_override == "off":
		return ""
	if api_url_override != "":
		return api_url_override
	if OS.has_feature("web") and not _web_override_checked:
		_web_override_checked = true
		var w := JavaScriptBridge.get_interface("window")
		if w and bool(w.ceTestHooks) and w.ceApiUrl:
			api_url_override = str(w.ceApiUrl)
			return "" if api_url_override == "off" else api_url_override
	return API_URL


static func sharing_enabled() -> bool:
	return api_url() != ""
