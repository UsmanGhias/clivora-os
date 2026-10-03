import { apiJson } from "@/lib/api-v1/responses";
import { site } from "@/lib/site";

export const runtime = "nodejs";

export async function GET() {
  return apiJson({
    ok: true,
    service: "clivora-public-api",
    version: "v1",
    appVersion: site.appVersion,
    timestamp: new Date().toISOString(),
  });
}
