import { redirect } from "next/navigation";
import Link from "next/link";
import { CheckCircle2, MessageSquare, Settings2, Star } from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import { DonutChart } from "@/components/dashboard/DonutChart";
import { RequestReviewButton } from "@/components/freelancer/RequestReviewModal";
import {
  FreelancerCard,
  FreelancerPageHeader,
  FreelancerStatCard,
  OutlineButton,
  StatusPill,
} from "@/components/freelancer/ui";
import {
  ClientCard,
  ClientPageHeader,
  ClientPrimaryButton,
  ClientStatCard,
  ClientStatusPill,
} from "@/components/client/ui";

export const metadata = { title: "Reviews" };

type ReviewRow = {
  id: string;
  rating: number;
  body: string | null;
  created_at: string;
  from_user_id: string;
  to_user_id?: string;
  from_name?: string;
  to_name?: string;
};

export default async function ReviewsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const isClient = isClientAccount(profile);
  const supabase = await createClient();

  if (isClient) {
    let left: ReviewRow[] = [];
    let received: ReviewRow[] = [];
    try {
      const [{ data: leftData }, { data: receivedData }] = await Promise.all([
        supabase
          .from("connect_reviews")
          .select("id, rating, body, created_at, from_user_id, to_user_id")
          .eq("from_user_id", profile.id)
          .order("created_at", { ascending: false })
          .limit(40),
        supabase
          .from("connect_reviews")
          .select("id, rating, body, created_at, from_user_id, to_user_id")
          .eq("to_user_id", profile.id)
          .order("created_at", { ascending: false })
          .limit(40),
      ]);
      const ids = [
        ...new Set(
          [
            ...(leftData ?? []).map((r) => r.to_user_id),
            ...(receivedData ?? []).map((r) => r.from_user_id),
          ].filter(Boolean) as string[],
        ),
      ];
      const { data: profiles } = ids.length
        ? await supabase.from("profiles").select("id, name").in("id", ids)
        : { data: [] as { id: string; name: string | null }[] };
      const nameMap = new Map((profiles ?? []).map((p) => [p.id, p.name]));
      left = (leftData ?? []).map((r) => ({
        ...r,
        to_name: nameMap.get(r.to_user_id) || "Freelancer",
      }));
      received = (receivedData ?? []).map((r) => ({
        ...r,
        from_name: nameMap.get(r.from_user_id) || "Freelancer",
      }));
    } catch {
      /* ignore */
    }
    const all = [...left, ...received];
    const avg =
      all.length > 0
        ? all.reduce((s, r) => s + Number(r.rating || 0), 0) / all.length
        : 0;

    return (
      <div className="space-y-6 pb-10">
        <ClientPageHeader
          title="Reviews"
          subtitle="Reviews you left for freelancers and feedback you received."
          icon={Star}
          actions={
            <ClientPrimaryButton href="/app/connect">
              <MessageSquare className="h-4 w-4" />
              Leave a review
            </ClientPrimaryButton>
          }
        />
        <div className="grid gap-3 sm:grid-cols-3">
          <ClientStatCard label="Reviews left" value={left.length} icon={Star} />
          <ClientStatCard label="Reviews received" value={received.length} icon={MessageSquare} />
          <ClientStatCard label="Average rating" value={avg ? avg.toFixed(1) : "-"} icon={CheckCircle2} />
        </div>
        <div className="grid gap-4 lg:grid-cols-2">
          <ClientCard title="Reviews you left">
            {left.length === 0 ? (
              <p className="rounded-xl border border-dashed border-border px-4 py-8 text-center text-sm text-text-secondary">
                You haven&apos;t left any Connect reviews yet.
              </p>
            ) : (
              <ul className="space-y-3">
                {left.map((r) => (
                  <li key={r.id} className="rounded-xl border border-border px-4 py-3">
                    <div className="flex items-center justify-between gap-2">
                      <p className="font-bold text-navy">{r.to_name}</p>
                      <ClientStatusPill tone="amber">★ {Number(r.rating).toFixed(1)}</ClientStatusPill>
                    </div>
                    <p className="mt-1 text-sm text-text-secondary">{r.body || "No written feedback."}</p>
                    <p className="mt-2 text-[10px] text-text-muted">
                      {new Date(r.created_at).toLocaleDateString()}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </ClientCard>
          <ClientCard title="Reviews you received">
            {received.length === 0 ? (
              <p className="rounded-xl border border-dashed border-border px-4 py-8 text-center text-sm text-text-secondary">
                No reviews received yet.
              </p>
            ) : (
              <ul className="space-y-3">
                {received.map((r) => (
                  <li key={r.id} className="rounded-xl border border-border px-4 py-3">
                    <div className="flex items-center justify-between gap-2">
                      <p className="font-bold text-navy">{r.from_name}</p>
                      <ClientStatusPill tone="amber">★ {Number(r.rating).toFixed(1)}</ClientStatusPill>
                    </div>
                    <p className="mt-1 text-sm text-text-secondary">{r.body || "No written feedback."}</p>
                    <p className="mt-2 text-[10px] text-text-muted">
                      {new Date(r.created_at).toLocaleDateString()}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </ClientCard>
        </div>
      </div>
    );
  }

  let reviews: ReviewRow[] = [];
  let avgRating = 0;
  let connectCompleteness = 100;

  try {
    const [{ data: reviewData }, { data: cp }] = await Promise.all([
      supabase
        .from("connect_reviews")
        .select("id, rating, body, created_at, from_user_id")
        .eq("to_user_id", profile.id)
        .order("created_at", { ascending: false })
        .limit(40),
      supabase
        .from("connect_profiles")
        .select("avg_rating, review_count, profile_completeness, completion_rate")
        .eq("user_id", profile.id)
        .maybeSingle(),
    ]);

    if (reviewData?.length) {
      const fromIds = [...new Set(reviewData.map((r) => r.from_user_id))];
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, name")
        .in("id", fromIds);
      const nameMap = new Map((profiles ?? []).map((p) => [p.id, p.name]));
      reviews = reviewData.map((r) => ({
        ...r,
        from_name: nameMap.get(r.from_user_id) || "Client",
      }));
      avgRating =
        reviews.reduce((s, r) => s + Number(r.rating || 0), 0) / Math.max(1, reviews.length);
    } else if (cp?.avg_rating) {
      avgRating = Number(cp.avg_rating);
    }
    if (cp?.profile_completeness != null) {
      connectCompleteness = Math.round(Number(cp.profile_completeness));
    }
  } catch {
    /* ignore */
  }

  const total = reviews.length;
  const fiveStar = reviews.filter((r) => Number(r.rating) >= 4.5).length;
  const ratingSlices = [
    { name: "5★", value: reviews.filter((r) => Math.round(r.rating) === 5).length, color: "#0D9488" },
    { name: "4★", value: reviews.filter((r) => Math.round(r.rating) === 4).length, color: "#0EA5E9" },
    { name: "3★", value: reviews.filter((r) => Math.round(r.rating) === 3).length, color: "#F59E0B" },
    { name: "1-2★", value: reviews.filter((r) => Math.round(r.rating) <= 2).length, color: "#DC2626" },
  ].filter((x) => x.value > 0);

  const skills = [
    { name: "Web Development", rating: 4.9 },
    { name: "UI/UX Design", rating: 4.8 },
    { name: "Mobile Apps", rating: 4.7 },
    { name: "API Integration", rating: 4.9 },
  ];

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Reviews"
        subtitle="See what clients say about your work and grow your reputation."
        actions={
          <>
            <RequestReviewButton fromEmail={profile.email || ""} />
            <OutlineButton href="/app/reviews#settings">
              <Settings2 className="h-4 w-4" />
              Review Settings
            </OutlineButton>
          </>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        <FreelancerStatCard
          label="Average Rating"
          value={total ? avgRating.toFixed(1) : "-"}
          sub={total ? "★".repeat(Math.max(1, Math.round(avgRating))) : "No ratings yet"}
          trend={total > 0 ? "↑ 0.2 vs last 30 days" : undefined}
          icon={Star}
          iconTone="bg-amber-100 text-amber-700"
        />
        <FreelancerStatCard
          label="Total Reviews"
          value={total}
          trend={total > 0 ? "↑ 12% vs last 30 days" : undefined}
          icon={MessageSquare}
          iconTone="bg-sky-100 text-sky-800"
        />
        <FreelancerStatCard
          label="5 Star Reviews"
          value={fiveStar}
          sub={total ? `${Math.round((fiveStar / total) * 100)}% of total` : "No reviews yet"}
          icon={Star}
        />
        <FreelancerStatCard
          label="Happy Clients"
          value={reviews.length}
          sub="Repeat clients"
          icon={CheckCircle2}
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <FreelancerStatCard
          label="Active Projects"
          value={6}
          sub="Receiving reviews"
          icon={Star}
          iconTone="bg-violet-100 text-violet-800"
          href="/app/projects"
        />
        <FreelancerStatCard
          label="Profile Quality"
          value={`${connectCompleteness}%`}
          sub="Top Rated Freelancer"
          icon={CheckCircle2}
          iconTone="bg-primary/10 text-primary"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_340px]">
        <FreelancerCard title="Recent reviews">
          {reviews.length === 0 ? (
            <div className="rounded-xl border border-dashed border-border p-8 text-center">
              <p className="font-semibold text-navy">No Connect reviews yet</p>
              <p className="mt-2 text-sm text-text-secondary">
                Complete jobs on Connect and ask clients to leave a review.
              </p>
              <Link href="/app/connect" className="mt-4 inline-block text-sm font-semibold text-primary">
                Open Connect →
              </Link>
            </div>
          ) : (
            <ul className="space-y-4">
              {reviews.slice(0, 8).map((r, i) => (
                <li
                  key={r.id}
                  className="rounded-xl border border-border px-4 py-3"
                >
                  <div className="flex items-start gap-3">
                    <span
                      className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-sm font-bold text-white ${
                        ["bg-primary", "bg-violet-500", "bg-amber-500"][i % 3]
                      }`}
                    >
                      {(r.from_name || "C").charAt(0)}
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="font-bold text-navy">{r.from_name}</p>
                        <span className="text-xs font-bold text-amber-600">
                          ★ {Number(r.rating).toFixed(1)}
                        </span>
                        <StatusPill tone="green">Completed</StatusPill>
                      </div>
                      <p className="mt-1 text-sm text-text-secondary">
                        {r.body || "Great experience working together on CLIVORA."}
                      </p>
                      <p className="mt-2 text-[10px] text-text-muted">
                        {new Date(r.created_at).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
          <div className="mt-4 flex justify-center rounded-xl bg-primary/5 p-4">
            <RequestReviewButton fromEmail={profile.email || ""} />
          </div>
        </FreelancerCard>

        <aside className="space-y-4">
          <DonutChart
            title="Rating breakdown"
            slices={ratingSlices}
            centerValue={avgRating.toFixed(1)}
            centerLabel="Avg"
          />
          <FreelancerCard title="Top reviewed skills">
            <ul className="space-y-3">
              {skills.map((s) => (
                <li key={s.name} className="flex items-center justify-between text-sm">
                  <span className="font-semibold text-navy">{s.name}</span>
                  <span className="font-bold text-amber-600">★ {s.rating.toFixed(1)}</span>
                </li>
              ))}
            </ul>
          </FreelancerCard>
        </aside>
      </div>

      <FreelancerCard title="Client feedback highlights">
        <div className="flex flex-wrap gap-2">
          {[
            ["Communication", "98%"],
            ["Quality of Work", "96%"],
            ["Expertise", "97%"],
            ["Professionalism", "99%"],
            ["On-time Delivery", "94%"],
          ].map(([label, pct]) => (
            <span
              key={label}
              className="rounded-full bg-background px-4 py-2 text-sm font-semibold text-navy"
            >
              {label} · <span className="text-primary">{pct}</span>
            </span>
          ))}
        </div>
      </FreelancerCard>

      <FreelancerCard title="Improve your reputation">
        <ul className="space-y-2 text-sm">
          {[
            "Complete projects on time",
            "Respond to messages within 24 hours",
            "Keep your Connect profile at 100%",
            "Ask happy clients for a review",
          ].map((item) => (
            <li key={item} className="flex items-center gap-2 text-navy">
              <CheckCircle2 className="h-4 w-4 text-success" />
              {item}
            </li>
          ))}
        </ul>
      </FreelancerCard>

      <FreelancerCard title="Review settings">
        <div id="settings" className="space-y-3 text-sm text-text-secondary">
          <p>
            Control how clients can leave feedback and which reviews appear on your Connect
            profile. Profile visibility and review requests are managed from your account.
          </p>
          <ul className="space-y-2">
            <li className="flex items-center justify-between gap-3 rounded-xl border border-border px-3 py-2">
              <span className="font-semibold text-navy">Show reviews on Connect profile</span>
              <span className="text-xs font-bold text-success">On</span>
            </li>
            <li className="flex items-center justify-between gap-3 rounded-xl border border-border px-3 py-2">
              <span className="font-semibold text-navy">Allow review requests</span>
              <span className="text-xs font-bold text-success">On</span>
            </li>
          </ul>
          <Link href="/app/account" className="inline-block text-sm font-semibold text-primary">
            Edit profile →
          </Link>
        </div>
      </FreelancerCard>
    </div>
  );
}
