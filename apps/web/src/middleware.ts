import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "@/lib/supabase/env";

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  let response = NextResponse.next({ request });
  response.headers.set("X-Robots-Tag", "noindex, nofollow, noarchive");

  try {
    const supabase = createServerClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      {
        cookies: {
          getAll: () => request.cookies.getAll(),
          setAll: (cookies) => {
            cookies.forEach(({ name, value, options }) => {
              request.cookies.set(name, value);
              response.cookies.set(name, value, options);
            });
          },
        },
      }
    );

    // Only run auth checks on auth/app routes to avoid extra overhead on public pages
    const isAuthRoute =
      pathname.startsWith("/app") ||
      pathname === "/login" ||
      pathname === "/signup" ||
      pathname === "/auth/reset-password" ||
      pathname === "/connect/manage";

    if (isAuthRoute) {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      // Protected app routes: redirect to login if not signed in
      if (!user && (pathname.startsWith("/app") || pathname === "/connect/manage")) {
        const loginUrl = request.nextUrl.clone();
        loginUrl.pathname = "/login";
        loginUrl.searchParams.set("next", pathname);
        return NextResponse.redirect(loginUrl);
      }

      // Auth pages: redirect to /app if already logged in
      if (user && (pathname === "/login" || pathname === "/signup")) {
        return NextResponse.redirect(new URL("/app", request.url));
      }
    }
  } catch (e) {
    console.error("[middleware] Auth check error:", e);
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|brand/|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};

