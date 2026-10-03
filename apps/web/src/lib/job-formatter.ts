import { cleanText } from "@/lib/clean-text";

export type StructuredJobSection = {
  title: string;
  paragraphs: string[];
  bullets: string[];
};

/**
 * Strips all HTML markup, normalizes whitespace, formats bullet points,
 * and strips em/en dashes for clean typography.
 */
export function formatJobDescription(raw?: string | null): string {
  if (!raw) return "";
  return cleanText(raw);
}

const HEADING_DEFINITIONS: Array<{
  regex: RegExp;
  title: string;
  priority: number;
}> = [
  {
    regex: /^(?:why\s+this\s+role\s+exists|the\s+role|role\s+overview|position\s+summary|role\s+summary|about\s+the\s+role|about\s+the\s+position|the\s+opportunity|role\s+description|position\s+overview|job\s+summary|what\s+to\s+expect)/i,
    title: "Role Overview",
    priority: 1,
  },
  {
    regex: /^(?:about\s+(?:us|the\s+company|our\s+team|the\s+team)|who\s+we\s+are|company\s+overview|our\s+vision|our\s+mission|our\s+culture|life\s+at|about\s+(?!you\b|the\s+role\b|the\s+job\b|the\s+position\b|the\s+opportunity\b)[a-z0-9&.-]+)/i,
    title: "About the Company",
    priority: 2,
  },
  {
    regex: /^(?:what\s+you(?:'ll|\swill)\s+(?:do|own|work\s+on)|key\s+responsibilities|responsibilities|your\s+role|core\s+duties|what\s+you'll\s+be\s+responsible\s+for|duties|what\s+you\s+will\s+deliver|your\s+day-to-day|day-to-day\s+responsibilities)/i,
    title: "Key Responsibilities",
    priority: 3,
  },
  {
    regex: /^(?:what\s+we(?:'re|\s+are)\s+looking\s+for|who\s+(?:we're|are\s+we|you\s+are)\s+looking\s+for|requirements|qualifications|requirements\s+(&|and)\s+qualifications|skills\s+(?:&|and)\s+experience|what\s+you\s+need|must\s+have|ideal\s+candidate|who\s+you\s+are|about\s+you|what\s+you\s+bring|what\s+you'll\s+bring|basic\s+qualifications|profile\s+required|experience\s+required)/i,
    title: "Requirements & Qualifications",
    priority: 4,
  },
  {
    regex: /^(?:nice\s+to\s+have|bonus\s+points|preferred\s+qualifications|good\s+to\s+have|bonus\s+skills|preferred\s+skills|bonus\s+if\s+you\s+have)/i,
    title: "Preferred Skills & Bonus Points",
    priority: 5,
  },
  {
    regex: /^(?:what\s+we\s+offer|benefits(?:\s+(&|and)\s+perks)?|perks|compensation|why\s+join\s+us|total\s+rewards|what\s+do\s+we\s+do\s+to\s+make\s+your\s+work\s+life\s+easier)/i,
    title: "Benefits & Perks",
    priority: 6,
  },
  {
    regex: /^(?:recruitment\s+process|interview\s+process|hiring\s+process|how\s+to\s+apply|selection\s+process|next\s+steps)/i,
    title: "Hiring Process",
    priority: 7,
  },
];

// Inline headings frequently concatenated without double newlines in crawled feeds
const INLINE_HEADING_KEYWORDS = [
  "Why this role exists",
  "The Role",
  "Role Overview",
  "Position Summary",
  "Role Summary",
  "About the Role",
  "The Opportunity",
  "What to expect",
  "What you'll do",
  "What you will do",
  "What you'll own",
  "What you will work on",
  "What you'll be responsible for",
  "Key Responsibilities",
  "Responsibilities",
  "Core duties",
  "Requirements & Qualifications",
  "Requirements",
  "Qualifications",
  "Who we're looking for",
  "Who are we looking for",
  "Who you are",
  "About you",
  "What you bring",
  "What you'll bring",
  "What you need",
  "Skills & Experience",
  "Must Have",
  "Nice to have",
  "Preferred Qualifications",
  "Bonus points",
  "Good to have",
  "What we offer",
  "Benefits & Perks",
  "Benefits",
  "Perks",
  "Compensation",
  "Why join us",
  "What do we do to make your work life easier",
  "Recruitment process",
  "Interview process",
  "Hiring process",
  "How to apply",
  "About us",
  "About Us",
  "About the company",
  "Who we are",
  "Our vision",
  "Our mission",
  "Our culture",
];

function preprocessInlineHeadings(text: string): string {
  let result = text;
  for (const heading of INLINE_HEADING_KEYWORDS) {
    const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const pattern = new RegExp(
      `(^|[.!?\\):]\\s+|\\n+)(${escaped})(?:\\s*\\?)?(:|\\s*-\\s*)?(?=[\\s\\n]+(?:[A-Z0-9•\\-*]|\\p{Extended_Pictographic}|$))`,
      "giu"
    );
    result = result.replace(pattern, () => {
      return `\n\n### ${heading}\n\n`;
    });
  }
  return result;
}

/**
 * Extracts a concise 1-2 sentence executive summary for cards and mobile feeds.
 */
export function getJobExecutiveSummary(raw?: string | null, maxLength = 180): string {
  const cleaned = formatJobDescription(raw);
  if (!cleaned) return "Verified remote opportunity with direct client contact and $0 platform fees.";

  // Preprocess to find substantive sentences
  const preprocessed = preprocessInlineHeadings(cleaned);
  const blocks = preprocessed.split(/\n\n+/).map((b) => b.trim()).filter(Boolean);

  const BUREAUCRATIC_NOISE =
    /^(?:domaine|statut|nature du poste|corps|cotation|fondement|durée|date|environnement professionnel|cadre d'emploi|contacts? pour tout renseignement)\s*:/i;

  let candidateText = "";
  for (const block of blocks) {
    const lines = block
      .split("\n")
      .map((l) => l.trim().replace(/^###\s*/, ""))
      .filter((l) => l.length > 0 && !l.startsWith("•") && !l.startsWith("-"));

    for (const line of lines) {
      const stripped = line.replace(/^[_\-=*~#]+\s*/, "").trim();
      // Skip bureaucratic form fields or scraper metadata
      if (BUREAUCRATIC_NOISE.test(stripped)) continue;
      // Skip lines that are just short headings
      if (stripped.length < 25 && !stripped.includes(".")) continue;
      // Skip question run-ups if longer substantive text follows
      if (stripped.endsWith("?") && lines.length > 1) continue;
      candidateText = stripped;
      break;
    }
    if (candidateText) break;
  }

  if (!candidateText) {
    candidateText =
      cleaned
        .split("\n")
        .map((l) => l.replace(/^[_\-=*~#]+\s*/, "").trim())
        .filter((l) => l.length > 20 && !BUREAUCRATIC_NOISE.test(l))[0] || cleaned;
  }

  // Clean leading emojis, markdown, and repeated punctuation
  candidateText = candidateText
    .replace(/^[_\-=*~#]+\s*/, "")
    .replace(/^[^\w\s"'(]+/, "")
    .trim();

  if (candidateText.length <= maxLength) return candidateText;

  const sub = candidateText.slice(0, maxLength);
  const lastSpace = sub.lastIndexOf(" ");
  return `${sub.slice(0, lastSpace > 100 ? lastSpace : maxLength).trim()}...`;
}

/**
 * Splits raw job text into structured, styled semantic sections for rich UI display.
 */
export function parseJobIntoSections(raw?: string | null): StructuredJobSection[] {
  const fullText = formatJobDescription(raw);
  if (!fullText) return [];

  // 1. Separate concatenated inline headings with standard ### markers
  const preprocessed = preprocessInlineHeadings(fullText);
  const rawBlocks = preprocessed.split(/\n\n+/).map((b) => b.trim()).filter(Boolean);

  const parsedList: StructuredJobSection[] = [];
  let currentSection: StructuredJobSection | null = null;

  for (const block of rawBlocks) {
    const lines = block.split("\n").map((l) => l.trim()).filter(Boolean);
    if (lines.length === 0) continue;

    const firstLine = lines[0];
    const isExplicitHeading = firstLine.startsWith("###");
    const normalizedFirstLine = firstLine
      .replace(/^###\s*/, "")
      .replace(/[:#*_-]/g, "")
      .trim();

    // Check if this block opens with a recognized heading
    let matchedTitle: string | null = null;
    for (const def of HEADING_DEFINITIONS) {
      if (def.regex.test(normalizedFirstLine)) {
        matchedTitle = def.title;
        break;
      }
    }

    if (matchedTitle) {
      if (currentSection && (currentSection.paragraphs.length > 0 || currentSection.bullets.length > 0)) {
        parsedList.push(currentSection);
      }
      currentSection = {
        title: matchedTitle,
        paragraphs: [],
        bullets: [],
      };
      // Content lines start after the heading line
      const contentLines = lines.slice(1);
      processContentLines(contentLines, currentSection);
    } else {
      if (!currentSection) {
        currentSection = {
          title: "Role Overview",
          paragraphs: [],
          bullets: [],
        };
      }
      processContentLines(lines, currentSection);
    }
  }

  if (currentSection && (currentSection.paragraphs.length > 0 || currentSection.bullets.length > 0)) {
    parsedList.push(currentSection);
  }

  // Fallback if nothing was parsed
  if (parsedList.length === 0) {
    return [
      {
        title: "Role Overview",
        paragraphs: [fullText],
        bullets: [],
      },
    ];
  }

  // Clean empty or legal-only disclaimers
  const filtered = parsedList.filter((s) => {
    // Filter empty sections
    if (s.paragraphs.length === 0 && s.bullets.length === 0) return false;
    // Filter sections that are only multi-language GDPR or scam warnings
    const combined = [...s.paragraphs, ...s.bullets].join(" ");
    if (combined.includes("Données personnelles") || combined.includes("Personenbezogene Daten")) {
      return false;
    }
    return true;
  });

  // Deduplicate and merge sections with the same title
  const mergedMap = new Map<string, StructuredJobSection>();
  for (const s of filtered) {
    const existing = mergedMap.get(s.title);
    if (existing) {
      existing.paragraphs.push(...s.paragraphs);
      existing.bullets.push(...s.bullets);
    } else {
      mergedMap.set(s.title, {
        title: s.title,
        paragraphs: [...s.paragraphs],
        bullets: [...s.bullets],
      });
    }
  }
  const mergedList = Array.from(mergedMap.values());

  // Reorder sections for optimal candidate UX and AdSense readability
  // Desired priority: Role Overview (1), About the Company (2), Key Responsibilities (3),
  // Requirements (4), Nice to have (5), Benefits (6), Hiring Process (7)
  const getPriority = (title: string): number => {
    for (const def of HEADING_DEFINITIONS) {
      if (def.title.toLowerCase() === title.toLowerCase()) return def.priority;
    }
    return 8;
  };

  mergedList.sort((a, b) => getPriority(a.title) - getPriority(b.title));

  return mergedList;
}

function processContentLines(lines: string[], target: StructuredJobSection) {
  // Pre-expand lines that contain concatenated bullet items, sentences, or action verbs
  const expandedLines: string[] = [];
  const isBulletSection =
    target.title === "Key Responsibilities" ||
    target.title === "Requirements & Qualifications" ||
    target.title === "Preferred Skills & Bonus Points";

  for (const line of lines) {
    let text = line.trim();
    if (!text) continue;

    if (isBulletSection) {
      // Split inline intro transition e.g. "That means: Running..."
      text = text.replace(/(That means:\s*)([A-Z])/gi, "$1\n• $2");
      // Split concatenated action gerunds
      text = text.replace(
        /([a-z0-9]\.?)(\s+)(Running|Turning|Strengthening|Preparing|Improving|Leading|Driving|Developing|Managing|Accelerating|Translating|Supporting)\s+([a-z0-9])/g,
        "$1\n• $3 $4"
      );
      // If the line contains multiple sentences without bullets, split each sentence into a bullet
      if (!text.startsWith("•") && !text.startsWith("-") && !text.startsWith("*") && text.includes(". ")) {
        text = text.replace(/([.!?])\s+(?=[A-Z0-9])/g, "$1\n• ");
        if (!text.startsWith("• ")) {
          text = "• " + text;
        }
      }
    }

    for (const sub of text.split("\n")) {
      const s = sub.trim();
      if (s) expandedLines.push(s);
    }
  }

  for (const trimmed of expandedLines) {
    // Filter out aggregator spam or scam warnings inside paragraphs
    if (
      /Find\s+(?:more\s+)?(?:English\s+Speaking\s+)?Jobs\s+in/i.test(trimmed) ||
      /Important\s+information\s+for\s+candidates/i.test(trimmed) ||
      /Données\s+personnelles/i.test(trimmed)
    ) {
      continue;
    }

    // Check for bullet indicators
    const isBullet =
      trimmed.startsWith("•") ||
      trimmed.startsWith("-") ||
      trimmed.startsWith("*") ||
      /^\d+\.\s+/.test(trimmed) ||
      /^(?:💻|💰|👨‍👩‍👧‍👦|🌍|🤝|🚀|🌴|💵|📈|🏡|⛹️|🇬🇧|🏢|🎉|✔|✓)\s+/.test(trimmed);

    if (isBullet) {
      const cleanBullet = trimmed
        .replace(/^[•\-*]\s*/, "")
        .replace(/^\d+\.\s*/, "")
        .replace(/^(?:💻|💰|👨‍👩‍👧‍👦|🌍|🤝|🚀|🌴|💵|📈|🏡|⛹️|🇬🇧|🏢|🎉|✔|✓)\s+/, "")
        .trim();

      if (cleanBullet) {
        target.bullets.push(cleanBullet);
      }
    } else {
      // If line contains multiple inline bullet points like " -To speak English -To be energized"
      if (trimmed.includes(" -To ") || trimmed.includes(" • ")) {
        const parts = trimmed.split(/\s+[-•]\s*/).filter(Boolean);
        for (let i = 0; i < parts.length; i++) {
          const p = parts[i].trim();
          if (!p) continue;
          if (i === 0 && !trimmed.startsWith("-") && !trimmed.startsWith("•")) {
            target.paragraphs.push(p);
          } else {
            target.bullets.push(p);
          }
        }
      } else {
        target.paragraphs.push(trimmed);
      }
    }
  }
}

/**
 * Formats a raw job description into clean semantic HTML (<p> and <ul><li>)
 * strictly formatted according to Google Search JobPosting Structured Data specifications.
 */
export function formatGoogleJobsHtml(raw?: string | null): string {
  const sections = parseJobIntoSections(raw);
  if (sections.length === 0) {
    return "<p>Verified career opportunity on CLIVORA with $0 platform fees.</p>";
  }

  return sections
    .map((s) => {
      let html = `<p><strong>${s.title}</strong></p>`;
      for (const p of s.paragraphs) {
        html += `<p>${p}</p>`;
      }
      if (s.bullets.length > 0) {
        html += `<ul>${s.bullets.map((b) => `<li>${b}</li>`).join("")}</ul>`;
      }
      return html;
    })
    .join("");
}
