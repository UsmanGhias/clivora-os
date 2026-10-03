import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.9.6/index.ts";

type PushBody = {
  user_uid?: string;
  title?: string;
  body?: string;
  kind?: string;
  entity_id?: string;
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
};

async function loadServiceAccount(admin: ReturnType<typeof createClient>): Promise<ServiceAccount | null> {
  const fromEnv = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (fromEnv) {
    try {
      return JSON.parse(fromEnv) as ServiceAccount;
    } catch {
      /* fall through */
    }
  }
  const { data, error } = await admin
    .from("_internal_secrets")
    .select("value")
    .eq("key", "firebase_service_account_json")
    .maybeSingle();
  if (error || !data?.value) return null;
  try {
    return JSON.parse(data.value as string) as ServiceAccount;
  } catch {
    return null;
  }
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const key = await importPKCS8(sa.private_key.replace(/\\n/g, "\n"), "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience(sa.token_uri || "https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);

  const res = await fetch(sa.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`token exchange failed: ${await res.text()}`);
  const json = await res.json();
  return json.access_token as string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !serviceKey || !anonKey) {
    return new Response(JSON.stringify({ error: "Push service is not configured" }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!bearer) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  let payload: PushBody;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), { status: 400 });
  }

  const userUid = payload.user_uid?.trim();
  const title = payload.title?.trim() || "CLIVORA";
  const body = payload.body?.trim() || "";
  if (!userUid) {
    return new Response(JSON.stringify({ error: "user_uid required" }), { status: 400 });
  }

  // Validate caller identity BEFORE creating privileged admin client
  if (bearer !== serviceKey) {
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
    }
    if (userData.user.id !== userUid) {
      return new Response(JSON.stringify({ error: "Target is not authorized" }), { status: 403 });
    }
  }

  const admin = createClient(supabaseUrl, serviceKey);

  const { data: tokenRows, error: tokenErr } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_uid", userUid);
  if (tokenErr) {
    return new Response(JSON.stringify({ error: tokenErr.message }), { status: 500 });
  }
  const tokens = (tokenRows ?? []).map((r: { token: string }) => r.token).filter(Boolean);
  if (tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: "no_tokens" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const sa = await loadServiceAccount(admin);
  if (!sa?.private_key || !sa.client_email || !sa.project_id) {
    return new Response(
      JSON.stringify({ error: "Push provider is not configured" }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    );
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }

  let sent = 0;
  const errors: string[] = [];
  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: {
              kind: payload.kind ?? "info",
              entity_id: payload.entity_id ?? "",
              title,
              body,
            },
            android: { priority: "HIGH" },
          },
        }),
      },
    );
    if (res.ok) sent++;
    else errors.push(`FCM request failed (${res.status})`);
  }

  return new Response(JSON.stringify({ sent, errors }), {
    headers: { "Content-Type": "application/json" },
  });
});
