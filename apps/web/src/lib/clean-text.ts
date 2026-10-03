/**
 * Ultra-robust HTML and MS Word rich-text cleaner for job descriptions,
 * markdown summaries, and portal content.
 *
 * Strips XML tags, Office conditional comments, raw data attributes,
 * JSON metadata artifacts, and normalizes bullet lists cleanly.
 */
export function cleanText(str?: string | null): string {
  if (!str) return "";

  let text = str;

  // 1. Remove XML/HTML comments & Office conditionals (mso)
  text = text.replace(/<!--[\s\S]*?-->/g, "");
  text = text.replace(/<!\[[\s\S]*?\]>/g, "");

  // 2. Remove script and style blocks
  text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "");
  text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "");

  // 3. Pre-decode escaped HTML markup entities so tag processing operates on real tags
  if (text.includes("&lt;") || text.includes("&gt;") || text.includes("&amp;lt;")) {
    text = text
      .replace(/&amp;lt;/gi, "<")
      .replace(/&amp;gt;/gi, ">")
      .replace(/&amp;quot;/gi, '"')
      .replace(/&amp;amp;/gi, "&")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, '"');
  }

  // 4. Remove raw Office/Word list metadata blobs e.g. data-list-defn-props="{...}"
  text = text.replace(/data-[a-z0-9_-]+="\{[^}]*\}"/gi, "");
  text = text.replace(/data-[a-z0-9_-]+='\{[^']*\}'/gi, "");
  text = text.replace(/data-[a-z0-9_-]+="[^"]*"/gi, "");
  text = text.replace(/data-[a-z0-9_-]+='[^']*'/gi, "");
  text = text.replace(/\{"\d+":\s*\d+[^}]*\}/g, "");
  text = text.replace(/\{"33555[^}]*\}/g, "");

  // 5. Mark heading-like strong/b tags as explicit section headings
  text = text.replace(
    /<p[^>]*>\s*<(?:strong|b)>\s*([^<:\n]{3,60}:?)\s*<\/(?:strong|b)>\s*<\/p>/gi,
    "\n\n### $1\n\n"
  );
  text = text.replace(
    /<(?:strong|b)>\s*([^<:\n]{3,60}:?)\s*<\/(?:strong|b)>/gi,
    "\n\n### $1\n\n"
  );

  // 6. Mark heading elements with double newlines
  text = text.replace(/<h[1-6][^>]*>/gi, "\n\n### ");
  text = text.replace(/<\/h[1-6]>/gi, "\n\n");

  // 7. Convert all <li> elements with any attributes to uniform bullet points
  text = text.replace(/<li(\s+[^>]*)?>/gi, "\n• ");
  text = text.replace(/<\/li>/gi, "\n");
  text = text.replace(/<br\s*[\/]?>/gi, "\n");
  text = text.replace(/<\/(p|div|tr|table|ul|ol|section|article)>/gi, "\n\n");

  // 8. Strip any remaining standard or malformed HTML tags (e.g. <a>, <span>, <u>)
  text = text.replace(/<[^>]+>/g, " ");

  // 9. Decode all remaining HTML entities
  text = text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&rsquo;/g, "'")
    .replace(/&lsquo;/g, "'")
    .replace(/&rdquo;/g, '"')
    .replace(/&ldquo;/g, '"')
    .replace(/&ndash;/g, "-")
    .replace(/&mdash;/g, "-")
    .replace(/&#x2F;/gi, "/")
    .replace(/&#47;/g, "/")
    .replace(/&nbsp;/g, " ")
    .replace(/&bull;/g, "•")
    .replace(/&middot;/g, "·")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)))
    .replace(/&#x([a-f0-9]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)));

  // 10. Normalize Unicode typography to standard ASCII (single quotes, hyphens, spaces)
  text = text.replace(/[\u00A0\u200B\u202F\uFEFF]/g, " "); // non-breaking & zero-width spaces
  text = text.replace(/[\u2011\u2012\u2013\u2014\u2015]/g, "-"); // non-breaking hyphens, en-dash, em-dash
  text = text.replace(/[\u2018\u2019\u201A\u201B`]/g, "'"); // curly apostrophes & backticks
  text = text.replace(/[\u201C\u201D\u201E\u201F]/g, '"'); // curly double quotes

  // 11. Re-run bullet and tag cleanup on any entities that decoded into markup
  text = text.replace(/<li(\s+[^>]*)?>/gi, "\n• ");
  text = text.replace(/<[^>]+>/g, " ");

  // 12. Strip aggregator watermarks and scraper footers
  text = text.replace(/Find\s+(?:more\s+)?(?:English\s+Speaking\s+)?Jobs\s+in\s+[^.\n]+on\s+Arbeitnow/gi, "");
  text = text.replace(/Find\s+Jobs\s+(?:in\s+[^.\n]+\s+)?on\s+Arbeitnow/gi, "");
  text = text.replace(/Posted\s+on\s+Remotive/gi, "");

  // 13. Strip multi-language personal data / GDPR legal blocks
  text = text.replace(/(?:🇫🇷|🇬🇧|🇩🇪)?\s*(?:Données personnelles|Personenbezogene Daten|Personal Data\s+Pennylane)[\s\S]*?(?=(?:\n\n[A-Z]|$))/gi, "");

  // 14. Strip recruitment scam warnings that clutter candidate reading
  text = text.replace(
    /(?:Important\s+information\s+for\s+candidates|Recruitment\s+scam\s+attempts|Beware\s+of\s+(?:recruitment\s+)?scams)[\s\S]*?(?:report\s+it\s+to\s+us\s+immediately\s*\.?|fraudulent\s*\.?)/gi,
    ""
  );
  text = text.replace(
    /Applications\s+through\s+official\s+channels\s+only[\s\S]*?(?:report\s+it\s+to\s+us\s+immediately\s*\.?|fraudulent\s*\.?)/gi,
    ""
  );
  text = text.replace(
    /We\s+invite\s+you\s+to\s+not\s+respond\s+and\s+to\s+report\s+it\s+to\s+us\s+immediately\s*\.?/gi,
    ""
  );

  // 15. Convert inline emojis used as bullet points in scrapers
  text = text.replace(/(\s+)([\p{Extended_Pictographic}\u200d]+)(\s+[A-Z])/gu, "\n• $3");

  // 16. Strip decorative horizontal rule dividers and repeated punctuation underscores/hyphens/equals
  text = text.replace(/^[_\-=*~#]{2,}\s*/gm, "");
  text = text.replace(/\n[_\-=*~#]{2,}\s*/g, "\n");

  // 17. Standardize spacing and newlines
  text = text.replace(/[ \t]+/g, " ");
  text = text.replace(/\n[ \t]+/g, "\n");
  text = text.replace(/\n\s*\n\s*\n+/g, "\n\n");

  return text.trim();
}
