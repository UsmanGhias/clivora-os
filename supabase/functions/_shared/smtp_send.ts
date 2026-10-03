/** Email sender for CLIVORA Edge Functions.
 * Uses Resend when RESEND_API_KEY is set, otherwise SMTP over TLS.
 * Secrets: RESEND_API_KEY, RESEND_FROM, or SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM.
 * Set them with `supabase secrets set`; nothing has a built-in default.
 */

export type SmtpSendInput = {
  to: string;
  subject: string;
  html: string;
};

function env(name: string, fallback = ""): string {
  return (Deno.env.get(name) ?? fallback).trim();
}

export function smtpConfigured(): boolean {
  return Boolean(
    env("RESEND_API_KEY") ||
    (env("SMTP_HOST") && env("SMTP_USER") && env("SMTP_PASS"))
  );
}

export function smtpFromAddress(): string {
  return env("RESEND_FROM") || env("SMTP_FROM") || `CLIVORA <${env("SMTP_USER")}>`;
}

function encodeBase64(s: string): string {
  return btoa(s);
}

function parseFrom(from: string): { email: string; name?: string } {
  const m = from.match(/^(.*?)\s*<([^>]+)>$/);
  if (m) return { name: m[1].trim().replace(/^"|"$/g, ""), email: m[2].trim() };
  return { email: from.trim() };
}

function dotStuff(body: string): string {
  return body.replace(/\r\n/g, "\n").split("\n").map((line) => (line.startsWith(".") ? "." + line : line)).join("\r\n");
}

/** Primary: Resend API over HTTPS. Fallback: minimal SMTP over TLS (implicit TLS, usually port 465). */
export async function sendSmtpEmail(input: SmtpSendInput): Promise<void> {
  const fromRaw = smtpFromAddress();
  const resendApiKey = env("RESEND_API_KEY");

  // Prefer Resend when configured; it avoids mailbox sending limits.
  if (resendApiKey) {
    try {
      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: fromRaw,
          to: [input.to],
          subject: input.subject,
          html: input.html,
        }),
      });

      if (resp.ok) {
        return;
      }
      const errText = await resp.text();
      console.warn("[email] Resend API error:", resp.status, errText);
    } catch (fetchErr) {
      console.warn("[email] Resend fetch exception:", fetchErr);
    }
  }

  // Fall back to SMTP over TLS
  const host = env("SMTP_HOST");
  const port = Number(env("SMTP_PORT", "465")) || 465;
  const user = env("SMTP_USER");
  const pass = env("SMTP_PASS");
  if (!host || !user || !pass) {
    throw new Error("Email sending failed: set RESEND_API_KEY or SMTP_HOST, SMTP_USER and SMTP_PASS");
  }

  const from = parseFrom(fromRaw);
  const conn = await Deno.connectTls({ hostname: host, port });
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  let leftover = "";

  async function readReply(): Promise<{ code: string; text: string }> {
    while (true) {
      const chunk = new Uint8Array(4096);
      const n = await conn.read(chunk);
      if (n === null) throw new Error("SMTP connection closed");
      leftover += decoder.decode(chunk.subarray(0, n));
      const parts = leftover.split(/\r?\n/);
      leftover = parts.pop() ?? "";
      const lines = parts.filter((l) => l.length > 0);
      if (!lines.length) continue;
      // Find final line of multi-line reply (code + space)
      for (let i = lines.length - 1; i >= 0; i--) {
        const m = lines[i].match(/^(\d{3})([\s-])/);
        if (m && m[2] === " ") {
          return { code: m[1], text: lines.join("\n") };
        }
      }
    }
  }

  async function cmd(line: string, expectCode: string): Promise<void> {
    await conn.write(encoder.encode(line + "\r\n"));
    const reply = await readReply();
    if (reply.code !== expectCode) {
      throw new Error(`SMTP ${expectCode} expected, got ${reply.code}: ${reply.text.slice(0, 180)}`);
    }
  }

  try {
    const greet = await readReply();
    if (greet.code !== "220") throw new Error(`SMTP greet: ${greet.text}`);
    await cmd(`EHLO ${env("SMTP_HELO_DOMAIN") || user.split("@")[1] || "localhost"}`, "250");
    await cmd("AUTH LOGIN", "334");
    await cmd(encodeBase64(user), "334");
    await cmd(encodeBase64(pass), "235");
    await cmd(`MAIL FROM:<${from.email}>`, "250");
    await cmd(`RCPT TO:<${input.to}>`, "250");
    await cmd("DATA", "354");

    const subjectSafe = input.subject.replace(/[\r\n]+/g, " ");
    const fromHeader = from.name
      ? `"${from.name.replace(/"/g, "")}" <${from.email}>`
      : from.email;
    const message = [
      `From: ${fromHeader}`,
      `To: ${input.to}`,
      `Subject: ${subjectSafe}`,
      "MIME-Version: 1.0",
      "Content-Type: text/html; charset=UTF-8",
      "Content-Transfer-Encoding: 8bit",
      "",
      input.html,
    ].join("\r\n");

    await conn.write(encoder.encode(dotStuff(message) + "\r\n.\r\n"));
    const dataReply = await readReply();
    if (dataReply.code !== "250") {
      throw new Error(`SMTP DATA failed: ${dataReply.text.slice(0, 180)}`);
    }
    await cmd("QUIT", "221").catch(() => undefined);
  } finally {
    try {
      conn.close();
    } catch {
      /* ignore */
    }
  }
}
