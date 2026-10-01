// Local test stand-in for "https://esm.sh/@supabase/supabase-js@2" (mapped by
// import_map.json): an in-memory shared_challenges table and challenge-media
// bucket with the calls chain-escape-api uses. jsonb columns (puzzle,
// payload) are stored with jsonb's key order, as the real database does. Tests only - lets the REAL
// index.ts run under Deno without network access or credentials.
//   CE_FAKE_SEED=<file.json>   rows to start with (e.g. a version-3 record)
// deno-lint-ignore-file no-explicit-any
// Like PostgreSQL jsonb: object keys come back sorted by length, then
// bytewise - NOT in the order they were sent (arrays keep their order).
const JSONB_COLUMNS = ["puzzle", "payload"];
function jsonbOrder(v: any): any {
  if (Array.isArray(v)) return v.map(jsonbOrder);
  if (v === null || typeof v !== "object") return v;
  const keys = Object.keys(v).sort((a, b) => a.length - b.length || (a < b ? -1 : a > b ? 1 : 0));
  return Object.fromEntries(keys.map((k) => [k, jsonbOrder(v[k])]));
}
function asStored(row: any) {
  const r = structuredClone(row);
  for (const c of JSONB_COLUMNS) if (c in r) r[c] = jsonbOrder(r[c]);
  return r;
}
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const rows = new Map<string, any>();
const files = new Map<string, Uint8Array>();
const seed = Deno.env.get("CE_FAKE_SEED");
if (seed) for (const r of JSON.parse(Deno.readTextFileSync(seed))) rows.set(r.id, asStored(r));

class Query {
  filters: [string, string, any][] = [];
  constructor(public cols: string) {}
  eq(c: string, v: any) { this.filters.push(["eq", c, v]); return this; }
  gt(c: string, v: any) { this.filters.push(["gt", c, v]); return this; }
  maybeSingle() {
    for (const [op, c, v] of this.filters) {
      if (c === "id" && !UUID.test(String(v))) {
        return Promise.resolve({ data: null, error: { message: `invalid input syntax for type uuid: "${v}"` } });
      }
      void op;
    }
    const hit = [...rows.values()].find((r) => this.filters.every(([op, c, v]) =>
      op === "eq" ? r[c] === v : String(r[c]) > String(v)));
    return Promise.resolve({ data: hit ? pick(hit, this.cols) : null, error: null });
  }
}
function pick(r: any, cols: string) {
  const o: any = {};
  for (const c of cols.split(",").map((s) => s.trim())) o[c] = structuredClone(r[c]);
  return o;
}
export function createClient(_url: string, _key: string, _opts?: unknown) {
  return {
    from(_table: string) {
      return {
        select: (cols: string) => new Query(cols),
        insert(row: any) {
          const now = new Date();
          const full = { ...asStored(row), created_at: now.toISOString(),
            expires_at: new Date(now.getTime() + 30 * 86400000).toISOString() };
          return { select: (cols: string) => ({ single: () => {
            if (rows.has(full.id)) return Promise.resolve({ data: null, error: { message: "duplicate key" } });
            rows.set(full.id, full);
            return Promise.resolve({ data: pick(full, cols), error: null });
          } }) };
        },
      };
    },
    storage: {
      from(_bucket: string) {
        return {
          upload(path: string, bytes: Uint8Array, _opts?: unknown): Promise<{ data: any; error: { message: string } | null }> { files.set(path, bytes); return Promise.resolve({ data: { path }, error: null }); },
          createSignedUrl(path: string, secs: number) {
            if (!files.has(path)) return Promise.resolve({ data: null, error: { message: "Object not found" } });
            return Promise.resolve({ data: { signedUrl: `https://fake.supabase.test/storage/v1/object/sign/challenge-media/${path}?token=t&e=${secs}` }, error: null });
          },
          remove(paths: string[]) { for (const p of paths) files.delete(p); return Promise.resolve({ data: null, error: null }); },
        };
      },
    },
  };
}
