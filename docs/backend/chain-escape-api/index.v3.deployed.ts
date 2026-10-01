import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const BUCKET = "challenge-media";
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const SIGNED_URL_SECONDS = 60 * 60; // 1 hour

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
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
        version: 3,
      });
    }

    // --------------------------------------------------
    // Server-side Supabase client
    // --------------------------------------------------
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        {
          ok: false,
          error: "server_configuration_error",
        },
        500
      );
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
        return jsonResponse(
          {
            ok: false,
            error: "missing_challenge_id",
          },
          400
        );
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

        return jsonResponse(
          {
            ok: false,
            error: "read_failed",
          },
          500
        );
      }

      if (!data) {
        return jsonResponse(
          {
            ok: false,
            error: "challenge_not_found",
          },
          404
        );
      }

      let mediaUrl: string | null = null;

      const mediaPath = data?.payload?.media?.path;

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
    // Optional image:
    // image_base64
    // image_type = image/jpeg | image/png | image/webp
    // --------------------------------------------------
    if (req.method === "POST") {
      const body = await req.json();

      const challengeType = body?.challenge_type;
      const difficulty = body?.difficulty;
      const puzzle = body?.puzzle;

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

      if (challengeType !== "photo_message_reveal") {
        return jsonResponse(
          {
            ok: false,
            error: "invalid_challenge_type",
          },
          400
        );
      }

      if (
        !["easy", "medium", "hard"].includes(difficulty)
      ) {
        return jsonResponse(
          {
            ok: false,
            error: "invalid_difficulty",
          },
          400
        );
      }

      if (!puzzle || typeof puzzle !== "object") {
        return jsonResponse(
          {
            ok: false,
            error: "invalid_puzzle",
          },
          400
        );
      }

      if (
        puzzle.format !== "ce-puzzle" ||
        puzzle.v !== 1 ||
        puzzle.rules !== 1
      ) {
        return jsonResponse(
          {
            ok: false,
            error: "unsupported_puzzle_format",
          },
          400
        );
      }

      if (
        !Number.isInteger(puzzle.rows) ||
        !Number.isInteger(puzzle.cols) ||
        puzzle.rows < 2 ||
        puzzle.cols < 2 ||
        puzzle.rows > 10 ||
        puzzle.cols > 10
      ) {
        return jsonResponse(
          {
            ok: false,
            error: "invalid_puzzle_dimensions",
          },
          400
        );
      }

      if (
        !Array.isArray(puzzle.map) ||
        puzzle.map.length !== puzzle.rows
      ) {
        return jsonResponse(
          {
            ok: false,
            error: "invalid_puzzle_map",
          },
          400
        );
      }

      if (
        !puzzle.map.every(
          (row: unknown) =>
            typeof row === "string" &&
            row.length <= 500
        )
      ) {
        return jsonResponse(
          {
            ok: false,
            error: "invalid_puzzle_map",
          },
          400
        );
      }

      if (message.length > 200) {
        return jsonResponse(
          {
            ok: false,
            error: "message_too_long",
          },
          400
        );
      }

      // Photo is optional, but at least photo or message is required.
      if (!message && !imageBase64) {
        return jsonResponse(
          {
            ok: false,
            error: "missing_reveal_content",
          },
          400
        );
      }

      let imageBytes: Uint8Array | null = null;
      let extension: string | null = null;

      if (imageBase64) {
        extension = getExtension(imageType);

        if (!extension) {
          return jsonResponse(
            {
              ok: false,
              error: "invalid_image_type",
            },
            400
          );
        }

        try {
          imageBytes = decodeBase64(imageBase64);
        } catch {
          return jsonResponse(
            {
              ok: false,
              error: "invalid_image_data",
            },
            400
          );
        }

        if (
          imageBytes.length === 0 ||
          imageBytes.length > MAX_IMAGE_BYTES
        ) {
          return jsonResponse(
            {
              ok: false,
              error: "invalid_image_size",
            },
            400
          );
        }
      }

      // Generate the challenge ID here so the media file
      // can live under the same opaque challenge ID.
      const challengeId = crypto.randomUUID();

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

          return jsonResponse(
            {
              ok: false,
              error: "media_upload_failed",
            },
            500
          );
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

        return jsonResponse(
          {
            ok: false,
            error: "create_failed",
          },
          500
        );
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
    return jsonResponse(
      {
        ok: false,
        error: "method_not_allowed",
      },
      405
    );
  } catch (error) {
    console.error("Unhandled error:", error);

    return jsonResponse(
      {
        ok: false,
        error: "bad_request",
      },
      400
    );
  }
});
