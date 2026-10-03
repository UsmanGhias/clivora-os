/** Mirrors Flutter ContractContentHelper - strip encoded meta before display. */

const META_START = "---CLIVORA-CONTRACT-META---";
const META_END = "---END-META---";

export type DecodedContractContent = {
  body: string;
  attachmentPath: string | null;
  clientSignature: string | null;
  signedAt: string | null;
  deviceMeta: string | null;
};

export function decodeContractContent(raw: string | null | undefined): DecodedContractContent {
  const trimmed = String(raw ?? "").trim();
  if (!trimmed.startsWith(META_START)) {
    return {
      body: trimmed,
      attachmentPath: null,
      clientSignature: null,
      signedAt: null,
      deviceMeta: null,
    };
  }
  const end = trimmed.indexOf(META_END);
  if (end < 0) {
    return {
      body: trimmed,
      attachmentPath: null,
      clientSignature: null,
      signedAt: null,
      deviceMeta: null,
    };
  }
  const jsonPart = trimmed.slice(META_START.length, end);
  const body = trimmed.slice(end + META_END.length).trimStart();
  try {
    const map = JSON.parse(jsonPart) as Record<string, unknown>;
    return {
      body,
      attachmentPath: typeof map.attachment === "string" ? map.attachment : null,
      clientSignature: typeof map.clientSignature === "string" ? map.clientSignature : null,
      signedAt: typeof map.signedAt === "string" ? map.signedAt : null,
      deviceMeta: typeof map.deviceMeta === "string" ? map.deviceMeta : null,
    };
  } catch {
    return {
      body,
      attachmentPath: null,
      clientSignature: null,
      signedAt: null,
      deviceMeta: null,
    };
  }
}

/** Preview text for list cards - never show raw meta JSON. */
export function contractPreviewBody(raw: string | null | undefined, max = 140): string {
  const { body, attachmentPath, clientSignature } = decodeContractContent(raw);
  const bits: string[] = [];
  if (body) bits.push(body);
  else bits.push("Agreement terms to be defined.");
  if (attachmentPath) bits.push("Attachment included.");
  if (clientSignature) bits.push(`Signed by ${clientSignature}.`);
  const text = bits.join(" ");
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}
