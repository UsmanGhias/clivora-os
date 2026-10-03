/**
 * CLIVORA Canonical Product Manifest
 * Single source of truth for platform versions, capabilities, feature flags, and verification metadata.
 */

export const productManifest = {
  name: "Clivora",
  brand: "CLIVORA",
  tagline: "Complete Freelancer OS - Connect, CRM & Invoices",
  edition: "community",
  license: "AGPL-3.0",

  versions: {
    web: "4.2.3",
    android: "5.3.21",
    driftSchema: 18,
    lastVerifiedDate: "September 26, 2026",
  },

  capabilities: {
    /** Clivora charges $0 deal commission on client-freelancer transactions */
    zeroPlatformDealFees: true,

    /**
     * Clivora uses direct milestone invoicing and settlement.
     * We do NOT hold client funds in custodial escrow.
     */
    custodialEscrow: false,
    directMilestoneSettlement: true,
    milestoneLedger: true,

    /** Two-way mutual accept before direct contact info is exchanged */
    privateConnectProtocol: true,

    /** AI features ship in the Enterprise edition */
    aiAssistant: false,

    /** Offline-first SQLite/Drift client on Android with background cloud sync */
    offlineSync: true,
  },

  plans: {
    free: {
      id: "free",
      name: "Free",
      priceUsd: 0,
      period: "forever",
      clients: 3,
      projects: 5,
      invoicesPerMonth: 10,
      templates: 3,
      fileVaultMb: 100,
      platformFeePercent: 0,
      connectAccess: "Browse & apply with free basic profile",
    },
    pro: {
      id: "pro",
      name: "Pro",
      priceUsd: 9,
      listPriceUsd: 14,
      period: "month",
      founderLaunchFree: true,
      clients: "Unlimited",
      projects: "Unlimited",
      invoicesPerMonth: "Unlimited",
      templates: "Unlimited",
      fileVaultGb: 5,
      platformFeePercent: 0,
      connectAccess: "Verified badge, proposal boosts, e-signatures",
    },
    proPlus: {
      id: "pro_plus",
      name: "Pro Plus",
      priceUsd: 19,
      listPriceUsd: 29,
      period: "month",
      founderLaunchFree: true,
      clients: "Unlimited",
      projects: "Unlimited",
      invoicesPerMonth: "Unlimited",
      templates: "Unlimited",
      fileVaultGb: 50,
      platformFeePercent: 0,
      connectAccess: "Priority directory placement, direct talent outreach, team collaboration",
    },
  },

  comparisons: {
    verifiedDate: "September 18, 2026",
    upwork: {
      freelancerFee: "0% to 15% variable fee",
      clientFee: "Up to 7.99% Marketplace Fee + $0.99–$14.99 initiation fee",
      biddingTokens: "8–16+ connects per proposal ($0.15/ea), auction bids up to 50+",
      payoutHold: "5 to 14 days mandatory hold",
      clivoraDifferentiator: "$0 deal fees, direct milestone payouts, complete CRM and project OS",
    },
  },
} as const;

export type ProductManifest = typeof productManifest;
