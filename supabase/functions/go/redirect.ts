// go - stable challenge links (Phase 4). The logic, kept apart from the
// server entry (index.ts) so it can be tested without a network.
//
//   GET|HEAD /functions/v1/go?challenge=<uuid>        -> 302 <CE_GAME_URL>?challenge=<uuid>
//   GET|HEAD /functions/v1/go?challenge=<uuid>&to=qa  -> 302 <CE_QA_GAME_URL>?challenge=<uuid>
//
// A link made today keeps working after every itch.io upload: only the
// secret with the current upload's address changes. The function never
// reads or writes challenge data - the game opens the challenge with the
// API exactly as before (expiry, "isn't available", private-by-link).
//
// No open redirect: the destination is never taken from the request. It
// comes from a secret, and only an https itch.io address is accepted
// (html-classic.itch.zone, or <name>.itch.io); anything else is treated
// as unset (503). "to=qa" only picks which configured address to use - it
// is routing, not a security boundary.
//
// Status: 302 redirect, 400 bad / missing / repeated challenge id or an
// unknown "to", 405 any other method, 503 destination not configured or
// not acceptable. Every answer: Cache-Control: no-store (a changed secret
// applies at once), Referrer-Policy: no-referrer. Secret values are never
// returned or logged.

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ITCH_PAGE_RE = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.itch\.io$/;
const ROUTES: Record<string, string> = { "": "CE_GAME_URL", "qa": "CE_QA_GAME_URL" };

// The configured destination as a URL, or null if it is not an https
// itch.io address without credentials or a port. Its own query (e.g.
// itch's ?v=) is kept; a challenge / to / fragment in it is dropped.
export function gameTarget(raw: string | undefined): URL | null {
  if (!raw || raw.trim() === "") return null;
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:" || u.username !== "" || u.password !== "" || u.port !== "") return null;
  const host = u.hostname.toLowerCase();
  if (host !== "html-classic.itch.zone" && !ITCH_PAGE_RE.test(host)) return null;
  u.hash = "";
  u.searchParams.delete("challenge");
  u.searchParams.delete("to");
  return u;
}

function answer(status: number, text: string, extra: Record<string, string> = {}, head = false): Response {
  const headers = {
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "Content-Type": "text/plain; charset=utf-8",
    ...extra,
  };
  return new Response(head || text === "" ? null : text, { status, headers });
}

export function handleGo(req: Request, env: (k: string) => string | undefined): Response {
  const head = req.method === "HEAD";
  if (req.method !== "GET" && !head) {
    return answer(405, "Method not allowed.", { "Allow": "GET, HEAD" });
  }
  const url = new URL(req.url);
  const ids = url.searchParams.getAll("challenge");
  const tos = url.searchParams.getAll("to");
  const id = ids.length === 1 ? ids[0] : "";
  const route = tos.length === 0 ? "" : (tos.length === 1 ? tos[0] : "?");
  if (!UUID_RE.test(id) || !Object.hasOwn(ROUTES, route)) {
    return answer(400, "This Chain Escape link isn't valid.", {}, head);
  }
  const target = gameTarget(env(ROUTES[route]));
  if (target === null) {
    console.error(`go: ${ROUTES[route]} is not set to an https itch.io address`);  // the name only, never the value
    return answer(503, "Chain Escape is being updated. Please try this link again in a few minutes.", {}, head);
  }
  target.searchParams.set("challenge", id);  // the id exactly as given
  return answer(302, "", { "Location": target.toString() }, head);
}
