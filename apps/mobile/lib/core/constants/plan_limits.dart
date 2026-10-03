/// Free vs Pro numeric limits for CLIVORA.
abstract final class PlanLimits {
  static const freePlan = 'free';
  static const proPlan = 'pro';
  static const proPlusPlan = 'pro_plus';
  static const starterPlan = 'starter';
  static const professionalPlan = 'professional';
  static const agencyPlan = 'agency';

  // Founder tier (1-Year Free Founder Access)
  static const freeMaxClients = 10000;
  static const freeMaxProjects = 10000;
  static const freeMaxInvoicesPerMonth = 10000;
  static const freeMaxEmailsPerMonth = 5000;
  static const freeMaxTemplates = 10000;
  static const freeMaxTasksPerProject = 10000;
  static const freeMaxWorkflows = 1000;
  static const freeStorageBytes = 50 * 1024 * 1024 * 1024; // 50 GB

  // Pro tier
  static const proStorageBytes = 50 * 1024 * 1024 * 1024; // 50 GB
  static const proMaxEmailsPerMonth = 5000;

  // Pro Plus tier
  static const proPlusStorageBytes = 50 * 1024 * 1024 * 1024; // 50 GB
  static const proPlusMaxEmailsPerMonth = 5000;

  // Client free caps
  static const freeMaxClientContracts = 10000;
  static const freeMaxClientInvoiceDownloads = 10000;
}
