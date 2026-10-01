// chain-escape-api - Supabase Edge Function (version 4).
//
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

const API_VERSION = 4;
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
