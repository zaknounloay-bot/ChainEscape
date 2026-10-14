// chain-escape-api - Supabase Edge Function (version 5).
//
// Version 5 = version 4 + real-player results (Phase 3B-B), two new POST
// actions routed BEFORE challenge CREATE (whose bodies never carry
// "action"), so every challenge request behaves exactly as in version 4:
//   - {action: "submit_result", pool, player_id, secret, level,
//     fingerprint, time_ms, diag?}  -> {ok, improved, best_ms, percentile}
//   - {action: "level_standing", pool, player_id, secret, level,
//     fingerprint}                  -> {ok, best_ms, percentile} | {ok, none}
//   percentile = TOP X% (null until MIN_PLAYERS players have a result);
//   the number of players is never returned.
//   Server settings (Edge Function secrets):
//     CE_PROD_POOL=open        the "prod" pool takes results (default: closed)
//     CE_PROD_ORIGINS=a,b      ... and only from these browser origins
//                              ("*.itch.zone" = any subdomain; empty = any)
//     CE_QA_POOL=closed        stop the "qa" pool (default: open)
//     CE_MAX_NEW_PLAYERS_PER_HOUR (default 1000 per pool)
//   Writes go through the SQL functions ce_submit_result /
//   ce_level_standing (supabase/migrations/20261014120000_*.sql).
//
// Version 4 =
// Version 4 = version 3 (the deployed source, kept verbatim in
// docs/backend/chain-escape-api/index.v3.deployed.ts) + Challenge a Friend
// phase 2:
//   - challenge_type "friend_challenge" (CREATE + READ), next to
//     "photo_message_reveal"; each type has its own validation.
//   - difficulty "very_hard" for friend_challenge only.
//   - photo_message_reveal: unchanged (same checks, error codes, payload,
//     storage upload and signed URL).
//   - READ: a malformed id is answered 404 instead of a database error;
//     media is signed only for photo_message_reveal.
//   - health check reports version 4.
// The service-role key is read from the function's environment and never
// leaves the server. Deploy with "Verify JWT" OFF, as before.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const API_VERSION = 5;
const BUCKET = "challenge-media";
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const SIGNED_URL_SECONDS = 60 * 60; // 1 hour

const PHOTO_MESSAGE_REVEAL = "photo_message_reveal";
const FRIEND_CHALLENGE = "friend_challenge";

// Difficulties each challenge type accepts. very_hard is Challenge a
// Friend only. ("surprise" is never a difficulty: the client stores the
// real one it picked, plus surprise_me: true.)
const DIFFICULTIES: Record<string, string[]> = {
  [PHOTO_MESSAGE_REVEAL]: ["easy", "medium", "hard"],
  [FRIEND_CHALLENGE]: ["easy", "medium", "hard", "very_hard"],
};

// Challenge a Friend boards use only plain arrows ("R>") and clockwise
// spinners ("B^@"); "." is an empty cell.
const FRIEND_CELL = /^(\.|[RBGYP][\^v<>](@)?)$/;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// --------------------------------------------------
// Real-player results (version 5)
// --------------------------------------------------
const MIN_PLAYERS = 5;
const MIN_TIME_MS = 300;
const MAX_TIME_MS = 6 * 60 * 60 * 1000;
const HEX64 = /^[0-9a-f]{64}$/;
const DIAG_KEYS = ["discarded_ms", "capped_frames", "longest_frame_ms", "start_frame_ms"];

// TOP X%: X = round(100 * (players strictly faster + 1) / players), 1..100.
// Equal times share the better place. null below MIN_PLAYERS players.
export function topPercent(n: number, faster: number): number | null {
  if (!Number.isInteger(n) || !Number.isInteger(faster) || n < MIN_PLAYERS || faster < 0 || faster >= n) {
    return null;
  }
  return Math.min(100, Math.max(1, Math.round((100 * (faster + 1)) / n)));
}

// The pool is the server's decision. "qa" unless the client asks for
// "prod" AND the prod pool is open AND (when CE_PROD_ORIGINS is set) the
// browser Origin is one of the production hosts.
export function resolvePool(asked: unknown, origin: string, env: (k: string) => string | undefined):
  { pool: string } | { error: string } {
  if (asked === "prod") {
    if ((env("CE_PROD_POOL") || "closed") !== "open") return { error: "prod_closed" };
    const allowed = (env("CE_PROD_ORIGINS") || "").split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);
    if (allowed.length > 0) {
      let host = "";
      try { host = new URL(origin).host.toLowerCase(); } catch { host = ""; }
      const ok = allowed.some((a) => a.startsWith("*.") ? host.endsWith(a.slice(1)) : (host === a || origin.toLowerCase() === a));
      if (!ok) return { error: "origin_not_allowed" };
    }
    return { pool: "prod" };
  }
  if (asked !== "qa" && asked !== undefined) return { error: "invalid_pool" };
  if ((env("CE_QA_POOL") || "open") === "closed") return { error: "qa_closed" };
  return { pool: "qa" };
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Field checks shared by both actions ("" = fine).
// deno-lint-ignore no-explicit-any
function resultFieldsError(body: any): string {
  if (typeof body?.player_id !== "string" || !UUID_RE.test(body.player_id)) return "invalid_player";
  if (typeof body?.secret !== "string" || !HEX64.test(body.secret)) return "invalid_secret";
  if (!Number.isInteger(body?.level) || body.level < 1 || body.level > 300) return "invalid_level";
  if (typeof body?.fingerprint !== "string" || !HEX64.test(body.fingerprint)) return "invalid_fingerprint";
  return "";
}

// Timing diagnostics: four non-negative integers, kept for the QA pool only.
// deno-lint-ignore no-explicit-any
function cleanDiag(diag: any): Record<string, number> | null {
  if (diag === undefined || diag === null || typeof diag !== "object" || Array.isArray(diag)) return null;
  const out: Record<string, number> = {};
  for (const k of DIAG_KEYS) {
    const v = diag[k];
    if (Number.isInteger(v) && v >= 0 && v <= MAX_TIME_MS * 10) out[k] = v;
  }
  return Object.keys(out).length ? out : null;
}

const RPC_FAILURES: Record<string, [string, number]> = {
  bad_level: ["invalid_level", 400],
  bad_time: ["invalid_time", 400],
  bad_pool: ["invalid_pool", 400],
  wrong_secret: ["wrong_secret", 403],
  busy: ["busy", 429],
};

// deno-lint-ignore no-explicit-any
async function resultAction(supabase: any, req: Request, body: any): Promise<Response> {
  const problem = resultFieldsError(body);
  if (problem) return fail(problem, 400);
  const pool = resolvePool(body.pool, req.headers.get("origin") || "", (k) => Deno.env.get(k));
  if ("error" in pool) return fail(pool.error, 403);
  const secretHash = await sha256Hex(body.secret);

  if (body.action === "submit_result") {
    if (!Number.isInteger(body.time_ms) || body.time_ms < MIN_TIME_MS || body.time_ms > MAX_TIME_MS) {
      return fail("invalid_time", 400);
    }
    const maxNew = parseInt(Deno.env.get("CE_MAX_NEW_PLAYERS_PER_HOUR") || "1000", 10);
    const { data, error } = await supabase.rpc("ce_submit_result", {
      p_pool: pool.pool, p_level: body.level, p_fingerprint: body.fingerprint, p_player: body.player_id,
      p_secret_hash: secretHash, p_time_ms: body.time_ms,
      p_diag: pool.pool === "qa" ? cleanDiag(body.diag) : null,
      p_max_new_players: Number.isFinite(maxNew) ? maxNew : 1000,
    });
    if (error || !data) {
      console.error("submit_result failed:", error?.message);
      return fail("database_error", 500);
    }
    if (data.status !== "ok") {
      const [code, status] = RPC_FAILURES[data.status] || ["database_error", 500];
      return fail(code, status);
    }
    return jsonResponse({ ok: true, improved: !!data.improved, best_ms: data.best_ms,
      percentile: topPercent(data.n, data.faster) });
  }

  // level_standing (read-only)
  const { data, error } = await supabase.rpc("ce_level_standing", {
    p_pool: pool.pool, p_level: body.level, p_fingerprint: body.fingerprint, p_player: body.player_id,
    p_secret_hash: secretHash,
  });
  if (error || !data) {
    console.error("level_standing failed:", error?.message);
    return fail("database_error", 500);
  }
  if (data.status === "none") return jsonResponse({ ok: true, none: true, best_ms: null, percentile: null });
  if (data.status !== "ok") {
    const [code, status] = RPC_FAILURES[data.status] || ["database_error", 500];
    return fail(code, status);
  }
  return jsonResponse({ ok: true, best_ms: data.best_ms, percentile: topPercent(data.n, data.faster) });
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function fail(error: string, status = 400) {
  return jsonResponse({ ok: false, error }, status);
}

function getExtension(contentType: string) {
  if (contentType === "image/jpeg") return "jpg";
  if (contentType === "image/png") return "png";
  if (contentType === "image/webp") return "webp";
  return null;
}

function decodeBase64(base64: string): Uint8Array {
  const cleaned = base64.includes(",")
    ? base64.substring(base64.indexOf(",") + 1)
    : base64;

  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes;
}

// The version-3 puzzle checks, shared by both types (unchanged).
// Returns an error code, or "" if the puzzle passes.
// deno-lint-ignore no-explicit-any
function puzzleError(puzzle: any): string {
  if (!puzzle || typeof puzzle !== "object") {
    return "invalid_puzzle";
  }

  if (
    puzzle.format !== "ce-puzzle" ||
    puzzle.v !== 1 ||
    puzzle.rules !== 1
  ) {
    return "unsupported_puzzle_format";
  }

  if (
    !Number.isInteger(puzzle.rows) ||
    !Number.isInteger(puzzle.cols) ||
    puzzle.rows < 2 ||
    puzzle.cols < 2 ||
    puzzle.rows > 10 ||
    puzzle.cols > 10
  ) {
    return "invalid_puzzle_dimensions";
  }

  if (
    !Array.isArray(puzzle.map) ||
    puzzle.map.length !== puzzle.rows
  ) {
    return "invalid_puzzle_map";
  }

  if (
    !puzzle.map.every(
      (row: unknown) =>
        typeof row === "string" &&
        row.length <= 500
    )
  ) {
    return "invalid_puzzle_map";
  }

  return "";
}

// friend_challenge only: every row has exactly `cols` cells, every cell is
// a plain arrow / clockwise spinner / empty, and the board is not empty.
// deno-lint-ignore no-explicit-any
function friendBoardError(puzzle: any): string {
  let blocks = 0;

  for (const row of puzzle.map as string[]) {
    const cells = row.split(/\s+/).filter((c) => c.length > 0);

    if (cells.length !== puzzle.cols) {
      return "invalid_puzzle_map";
    }

    for (const cell of cells) {
      if (!FRIEND_CELL.test(cell)) {
        return "invalid_puzzle_map";
      }
      if (cell !== ".") {
        blocks++;
      }
    }
  }

  return blocks > 0 ? "" : "invalid_puzzle_map";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);

    // --------------------------------------------------
    // Health check
    // --------------------------------------------------
    if (
      req.method === "GET" &&
      url.searchParams.get("action") !== "read"
    ) {
      return jsonResponse({
        ok: true,
        service: "chain-escape-api",
        version: API_VERSION,
      });
    }

    // --------------------------------------------------
    // Server-side Supabase client
    // --------------------------------------------------
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return fail("server_configuration_error", 500);
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    );

    // --------------------------------------------------
    // READ CHALLENGE
    // GET ?action=read&id=<challenge_id>
    // --------------------------------------------------
    if (
      req.method === "GET" &&
      url.searchParams.get("action") === "read"
    ) {
      const challengeId = url.searchParams.get("id");

      if (!challengeId) {
        return fail("missing_challenge_id", 400);
      }

      // Not a UUID: it cannot exist (and would only make the uuid
      // column query fail).
      if (!UUID_RE.test(challengeId)) {
        return fail("challenge_not_found", 404);
      }

      const { data, error } = await supabase
        .from("shared_challenges")
        .select(
          "id, challenge_type, puzzle, payload, difficulty, format_version, rules_version, created_at, expires_at"
        )
        .eq("id", challengeId)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();

      if (error) {
        console.error(
          "Read challenge failed:",
          error.message
        );

        return fail("read_failed", 500);
      }

      if (!data) {
        return fail("challenge_not_found", 404);
      }

      let mediaUrl: string | null = null;

      // Only Photo / Message Reveal challenges have media; a friend
      // challenge never touches Storage.
      const mediaPath =
        data.challenge_type === PHOTO_MESSAGE_REVEAL
          ? data?.payload?.media?.path
          : null;

      if (
        typeof mediaPath === "string" &&
        mediaPath.length > 0
      ) {
        const { data: signedData, error: signedError } =
          await supabase.storage
            .from(BUCKET)
            .createSignedUrl(
              mediaPath,
              SIGNED_URL_SECONDS
            );

        if (signedError) {
          console.error(
            "Signed URL failed:",
            signedError.message
          );
        } else {
          mediaUrl = signedData.signedUrl;
        }
      }

      return jsonResponse({
        ok: true,
        challenge: {
          ...data,
          media_url: mediaUrl,
        },
      });
    }

    // --------------------------------------------------
    // CREATE CHALLENGE
    // POST JSON
    //
    // photo_message_reveal:
    //   { challenge_type, difficulty, puzzle, message?,
    //     image_base64?, image_type? }
    //   image_type = image/jpeg | image/png | image/webp
    //   at least a photo or a message
    //
    // friend_challenge:
    //   { challenge_type, difficulty, puzzle, surprise_me? }
    //   no message, no image; surprise_me is an optional boolean
    // --------------------------------------------------
    if (req.method === "POST") {
      const body = await req.json();

      // Real-player results (version 5) - never a challenge request.
      if (body?.action === "submit_result" || body?.action === "level_standing") {
        return await resultAction(supabase, req, body);
      }

      const challengeType = body?.challenge_type;
      const difficulty = body?.difficulty;
      const puzzle = body?.puzzle;

      if (
        typeof challengeType !== "string" ||
        !(challengeType in DIFFICULTIES)
      ) {
        return fail("invalid_challenge_type", 400);
      }

      if (!DIFFICULTIES[challengeType].includes(difficulty)) {
        return fail("invalid_difficulty", 400);
      }

      const puzzleProblem = puzzleError(puzzle);

      if (puzzleProblem) {
        return fail(puzzleProblem, 400);
      }

      // Generate the challenge ID here so the media file (photo
      // challenges) can live under the same opaque challenge ID.
      const challengeId = crypto.randomUUID();

      // --------------------------------------------------
      // friend_challenge: the exact board, nothing to reveal.
      // --------------------------------------------------
      if (challengeType === FRIEND_CHALLENGE) {
        const boardProblem = friendBoardError(puzzle);

        if (boardProblem) {
          return fail(boardProblem, 400);
        }

        if (
          (body.message !== undefined && body.message !== null) ||
          (body.image_base64 !== undefined && body.image_base64 !== null) ||
          (body.image_type !== undefined && body.image_type !== null)
        ) {
          return fail("unexpected_reveal_content", 400);
        }

        if (
          body.surprise_me !== undefined &&
          typeof body.surprise_me !== "boolean"
        ) {
          return fail("invalid_surprise_me", 400);
        }

        const friendPayload =
          body.surprise_me === true ? { surprise_me: true } : {};

        const { data, error } = await supabase
          .from("shared_challenges")
          .insert({
            id: challengeId,
            challenge_type: challengeType,
            puzzle,
            payload: friendPayload,
            difficulty,
            format_version: 1,
            rules_version: 1,
          })
          .select("id, expires_at")
          .single();

        if (error) {
          console.error(
            "Create challenge failed:",
            error.message
          );

          return fail("create_failed", 500);
        }

        return jsonResponse(
          {
            ok: true,
            challenge_id: data.id,
            expires_at: data.expires_at,
          },
          201
        );
      }

      // --------------------------------------------------
      // photo_message_reveal: exactly as version 3.
      // --------------------------------------------------
      const message =
        typeof body?.message === "string"
          ? body.message.trim()
          : "";

      const imageBase64 =
        typeof body?.image_base64 === "string"
          ? body.image_base64
          : "";

      const imageType =
        typeof body?.image_type === "string"
          ? body.image_type
          : "";

      if (message.length > 200) {
        return fail("message_too_long", 400);
      }

      // Photo is optional, but at least photo or message is required.
      if (!message && !imageBase64) {
        return fail("missing_reveal_content", 400);
      }

      let imageBytes: Uint8Array | null = null;
      let extension: string | null = null;

      if (imageBase64) {
        extension = getExtension(imageType);

        if (!extension) {
          return fail("invalid_image_type", 400);
        }

        try {
          imageBytes = decodeBase64(imageBase64);
        } catch {
          return fail("invalid_image_data", 400);
        }

        if (
          imageBytes.length === 0 ||
          imageBytes.length > MAX_IMAGE_BYTES
        ) {
          return fail("invalid_image_size", 400);
        }
      }

      let mediaPath: string | null = null;

      if (imageBytes && extension) {
        mediaPath =
          `${challengeId}/reveal.${extension}`;

        const { error: uploadError } =
          await supabase.storage
            .from(BUCKET)
            .upload(
              mediaPath,
              imageBytes,
              {
                contentType: imageType,
                upsert: false,
              }
            );

        if (uploadError) {
          console.error(
            "Image upload failed:",
            uploadError.message
          );

          return fail("media_upload_failed", 500);
        }
      }

      const payload = {
        message,
        media: mediaPath
          ? {
              kind: "image",
              path: mediaPath,
              content_type: imageType,
            }
          : null,
      };

      const { data, error } = await supabase
        .from("shared_challenges")
        .insert({
          id: challengeId,
          challenge_type: challengeType,
          puzzle,
          payload,
          difficulty,
          format_version: 1,
          rules_version: 1,
        })
        .select("id, expires_at")
        .single();

      if (error) {
        console.error(
          "Create challenge failed:",
          error.message
        );

        // If DB creation failed after media upload,
        // remove the orphaned file.
        if (mediaPath) {
          await supabase.storage
            .from(BUCKET)
            .remove([mediaPath]);
        }

        return fail("create_failed", 500);
      }

      return jsonResponse(
        {
          ok: true,
          challenge_id: data.id,
          expires_at: data.expires_at,
        },
        201
      );
    }

    // --------------------------------------------------
    // Unsupported method
    // --------------------------------------------------
    return fail("method_not_allowed", 405);
  } catch (error) {
    console.error("Unhandled error:", error);

    return fail("bad_request", 400);
  }
});
