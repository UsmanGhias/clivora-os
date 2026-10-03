import type { ConnectNeed, ConnectProfile } from "@/lib/connect-types";
import { listPublicConnectProfiles, listPublicConnectNeeds } from "@/lib/connect";

const MEILI_HOST = process.env.MEILI_HOST ?? process.env.NEXT_PUBLIC_MEILI_HOST;
const MEILI_KEY = process.env.MEILI_KEY ?? process.env.NEXT_PUBLIC_MEILI_KEY;

type SearchResult = {
  profiles: ConnectProfile[];
  needs: ConnectNeed[];
  source: "meilisearch" | "postgres";
};

async function meiliSearch<T>(index: string, query: string, limit = 60): Promise<T[]> {
  if (!MEILI_HOST || !MEILI_KEY) throw new Error("Meilisearch not configured");
  const url = `${MEILI_HOST}/indexes/${index}/search`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${MEILI_KEY}`,
    },
    body: JSON.stringify({ q: query, limit }),
  });
  if (!res.ok) throw new Error(`Meilisearch error: ${res.status}`);
  const data = (await res.json()) as { hits: T[] };
  return data.hits ?? [];
}

/**
 * Searches Connect profiles and needs.
 * Prefers Meilisearch when MEILI_HOST + MEILI_KEY are set; falls back to
 * Postgres ilike via existing server helpers.
 */
export async function searchConnect(query: string): Promise<SearchResult> {
  const q = query.trim();
  if (!q) {
    const [profiles, needs] = await Promise.all([
      listPublicConnectProfiles(),
      listPublicConnectNeeds(),
    ]);
    return { profiles, needs, source: "postgres" };
  }

  if (MEILI_HOST && MEILI_KEY) {
    try {
      const [profiles, needs] = await Promise.all([
        meiliSearch<ConnectProfile>("connect_profiles", q),
        meiliSearch<ConnectNeed>("connect_needs", q),
      ]);
      return { profiles, needs, source: "meilisearch" };
    } catch {
      // fall through to Postgres
    }
  }

  const [profiles, needs] = await Promise.all([
    listPublicConnectProfiles(q),
    listPublicConnectNeeds(q),
  ]);
  return { profiles, needs, source: "postgres" };
}
