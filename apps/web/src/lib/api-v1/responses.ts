import { NextResponse } from "next/server";

const API_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
  Pragma: "no-cache",
};

export function apiJson(body: unknown, init: ResponseInit = {}) {
  const response = NextResponse.json(body, init);
  for (const [key, value] of Object.entries(API_HEADERS)) {
    response.headers.set(key, value);
  }
  return response;
}

export function apiError(
  code: string,
  message: string,
  status: number,
  details?: Record<string, unknown>,
) {
  return apiJson(
    {
      error: {
        code,
        message,
        ...(details ? { details } : {}),
      },
    },
    { status },
  );
}
