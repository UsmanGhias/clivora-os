/** Structured Connect profile extras stored as a bio HTML comment (no schema change). */

export type PortfolioProject = {
  title: string;
  url?: string;
  description?: string;
  coverImage?: string;
  skills?: string[];
  completionDate?: string;
  isVerified?: boolean;
};

export type PortfolioCertificate = {
  name: string;
  issuer?: string;
  year?: string;
};

export type ConnectPortfolioMeta = {
  hourlyRate?: number | null;
  additionalSkills?: string[];
  projects?: PortfolioProject[];
  certificates?: PortfolioCertificate[];
  languages?: string[];
  education?: string;
  experienceYears?: number | null;
};

const META_RE = /<!--clivora-meta:([\s\S]*?)-->/;

export function stripPortfolioMeta(bio: string | null | undefined): string {
  return String(bio ?? "")
    .replace(META_RE, "")
    .trim();
}

export function parsePortfolioMeta(bio: string | null | undefined): ConnectPortfolioMeta {
  const raw = String(bio ?? "");
  const m = raw.match(META_RE);
  if (!m?.[1]) return {};
  try {
    const parsed = JSON.parse(m[1]) as ConnectPortfolioMeta;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

export function encodeBioWithMeta(visibleBio: string, meta: ConnectPortfolioMeta): string {
  const clean = visibleBio.trim();
  const payload: ConnectPortfolioMeta = {
    hourlyRate: meta.hourlyRate ?? null,
    additionalSkills: (meta.additionalSkills ?? []).filter(Boolean).slice(0, 40),
    projects: (meta.projects ?? [])
      .filter((p) => p.title.trim())
      .slice(0, 12)
      .map((p) => ({
        title: p.title.trim(),
        url: (p.url || "").trim() || undefined,
        description: (p.description || "").trim() || undefined,
        coverImage: (p.coverImage || "").trim() || undefined,
        skills: Array.isArray(p.skills)
          ? p.skills.map((s) => String(s).trim()).filter(Boolean).slice(0, 8)
          : undefined,
        completionDate: (p.completionDate || "").trim() || undefined,
        isVerified: Boolean(p.isVerified),
      })),
    certificates: (meta.certificates ?? [])
      .filter((c) => c.name.trim())
      .slice(0, 12)
      .map((c) => ({
        name: c.name.trim(),
        issuer: (c.issuer || "").trim() || undefined,
        year: (c.year || "").trim() || undefined,
      })),
    languages: (meta.languages ?? []).filter(Boolean).slice(0, 12),
    education: (meta.education || "").trim() || undefined,
    experienceYears: meta.experienceYears ?? null,
  };
  const hasAny =
    payload.hourlyRate ||
    (payload.additionalSkills?.length ?? 0) > 0 ||
    (payload.projects?.length ?? 0) > 0 ||
    (payload.certificates?.length ?? 0) > 0 ||
    (payload.languages?.length ?? 0) > 0 ||
    !!payload.education ||
    payload.experienceYears;
  if (!hasAny) return clean;
  return `${clean}\n\n<!--clivora-meta:${JSON.stringify(payload)}-->`;
}

export {
  parseHourlyFromRateBand,
  clampHourlyRate,
  HOURLY_RATE_MIN,
  HOURLY_RATE_MAX,
} from "@/lib/hourly-rate";
