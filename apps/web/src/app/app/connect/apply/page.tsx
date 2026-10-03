import { Suspense } from "react";
import { ConnectApplyPanel } from "@/components/connect/ConnectApplyPanel";

export default function ConnectApplyPage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-[40vh] items-center justify-center text-sm text-text-secondary">
          Loading…
        </div>
      }
    >
      <ConnectApplyPanel />
    </Suspense>
  );
}
