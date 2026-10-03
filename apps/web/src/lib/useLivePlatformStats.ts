"use client";

import { useEffect, useState } from "react";

export type PlatformStats = {
  totalJobs: number;
  formattedJobs: string;
  platformFee: string;
  verifiedTalent: string;
  activeContracts: string;
};

const DEFAULT_STATS: PlatformStats = {
  totalJobs: 1205,
  formattedJobs: "1,205+",
  platformFee: "$0",
  verifiedTalent: "500+",
  activeContracts: "350+",
};

export function useLivePlatformStats(): PlatformStats {
  const [stats, setStats] = useState<PlatformStats>(DEFAULT_STATS);

  useEffect(() => {
    let mounted = true;

    async function fetchStats() {
      try {
        const res = await fetch("/api/v1/stats");
        if (res.ok) {
          const data = await res.json();
          if (mounted && data.formattedJobs) {
            setStats(data);
          }
        }
      } catch (_) {
        // Fallback gracefully to default
      }
    }

    void fetchStats();
    const interval = setInterval(fetchStats, 30000);

    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, []);

  return stats;
}
