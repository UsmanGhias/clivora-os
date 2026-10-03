export interface JobLanguage {
  code: string;
  label: string;
  nativeLabel: string;
  flag: string;
  description: string;
}

export const JOB_LANGUAGES: JobLanguage[] = [
  {
    code: "all",
    label: "All Languages",
    nativeLabel: "All",
    flag: "🌐",
    description: "Browse roles across all languages worldwide",
  },
  {
    code: "en",
    label: "English",
    nativeLabel: "English",
    flag: "🇬🇧",
    description: "Global English remote opportunities",
  },
  {
    code: "de",
    label: "German",
    nativeLabel: "Deutsch",
    flag: "🇩🇪",
    description: "DACH region & German-speaking roles",
  },
  {
    code: "fr",
    label: "French",
    nativeLabel: "Français",
    flag: "🇫🇷",
    description: "France & French-speaking roles",
  },
  {
    code: "es",
    label: "Spanish",
    nativeLabel: "Español",
    flag: "🇪🇸",
    description: "Spain & Latin American remote roles",
  },
];

export const POPULAR_TECH_STACKS = [
  { id: "all", label: "All Tech" },
  { id: "react", label: "React" },
  { id: "nextjs", label: "Next.js" },
  { id: "typescript", label: "TypeScript" },
  { id: "python", label: "Python" },
  { id: "nodejs", label: "Node.js" },
  { id: "golang", label: "Go" },
  { id: "rust", label: "Rust" },
  { id: "java", label: "Java" },
  { id: "php", label: "PHP" },
  { id: "mobile", label: "Mobile" },
  { id: "devops", label: "DevOps" },
  { id: "ai", label: "AI / ML" },
];

export function getLanguageBadge(code?: string | null): {
  code: string;
  label: string;
  nativeLabel: string;
  flag: string;
  className: string;
} {
  const norm = (code || "en").toLowerCase();
  switch (norm) {
    case "de":
      return {
        code: "de",
        label: "German",
        nativeLabel: "Deutsch",
        flag: "🇩🇪",
        className: "border-amber-200/90 bg-amber-50 text-amber-800",
      };
    case "fr":
      return {
        code: "fr",
        label: "French",
        nativeLabel: "Français",
        flag: "🇫🇷",
        className: "border-blue-200/90 bg-blue-50 text-blue-800",
      };
    case "es":
      return {
        code: "es",
        label: "Spanish",
        nativeLabel: "Español",
        flag: "🇪🇸",
        className: "border-rose-200/90 bg-rose-50 text-rose-800",
      };
    default:
      return {
        code: "en",
        label: "English",
        nativeLabel: "English",
        flag: "🇬🇧",
        className: "border-slate-200/90 bg-slate-100 text-slate-700",
      };
  }
}
