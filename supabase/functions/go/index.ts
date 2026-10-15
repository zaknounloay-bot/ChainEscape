// go - stable challenge links (Phase 4): redirects a permanent challenge
// link to the current itch.io upload. All logic: redirect.ts. Deploy with
// "Verify JWT" OFF (links are opened by anyone, without a key).
import { handleGo } from "./redirect.ts";

Deno.serve((req: Request) => handleGo(req, (k) => Deno.env.get(k)));
