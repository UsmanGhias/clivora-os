import { Suspense } from "react";
import LoginForm from "./LoginForm";

export default function Page() {
  return (
    <Suspense fallback={<div className="text-center text-sm text-text-secondary">Loading…</div>}>
      <LoginForm />
    </Suspense>
  );
}
