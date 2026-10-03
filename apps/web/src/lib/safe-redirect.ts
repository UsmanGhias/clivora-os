/**
 * Returns `next` only when it is a same-origin path. Rejects absolute URLs and
 * protocol-relative forms ("//host", "/\\host") so `?next=` cannot become an open redirect.
 */
export function safeNextPath(next: string | null | undefined, fallback = "/app"): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) {
    return fallback;
  }
  return next;
}
