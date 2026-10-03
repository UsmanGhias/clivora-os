import { Suspense } from "react";
import SignupForm from "./SignupForm";

export default function Page() {
  return (
    <Suspense fallback={<div className="text-center text-sm text-text-secondary">Loading…</div>}>
      <SignupForm />
    </Suspense>
  );
}
