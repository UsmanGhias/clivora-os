import { redirect } from "next/navigation";

/** Legacy URL - Connect manage now lives inside the portal shell. */
export default function ConnectManageRedirect() {
  redirect("/app/connect/manage");
}
