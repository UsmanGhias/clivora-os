export interface JobCategory {
  id: string;
  label: string;
  description: string;
}

export const JOB_CATEGORIES: JobCategory[] = [
  { id: "software-development", label: "Software & Engineering", description: "Full-stack, frontend, backend, mobile, and systems engineering roles." },
  { id: "sales", label: "Sales & Growth", description: "Account executive, SDR, business development, and enterprise sales roles." },
  { id: "marketing", label: "Marketing & Content", description: "Growth marketing, SEO, performance media, copy, and brand strategy." },
  { id: "data-science", label: "AI & Data Science", description: "Machine learning, AI research, LLM engineering, and data analysis." },
  { id: "product", label: "Product Management", description: "Technical product managers, product owners, and strategy leads." },
  { id: "design", label: "Design & Creative", description: "UI/UX, visual design, product design, and creative direction." },
  { id: "devops-sysadmin", label: "DevOps & Cloud", description: "Cloud infrastructure, Kubernetes, SRE, and platform engineering." },
  { id: "finance-legal", label: "Finance & Legal", description: "Corporate finance, legal counsel, compliance, and accounting." },
  { id: "management", label: "Project & Operations", description: "Technical program management, operations, and scrum leadership." },
  { id: "human-resources", label: "People & HR", description: "Recruiting, talent acquisition, people operations, and HR." },
  { id: "customer-support", label: "Customer Success", description: "Technical support, customer experience, and client success." },
  { id: "general", label: "All Opportunities", description: "Curated remote opportunities across high-velocity teams." },
];

export const VALID_CATEGORY_SLUGS = JOB_CATEGORIES.map((c) => c.id);

export function getCategoryById(id: string): JobCategory | undefined {
  return JOB_CATEGORIES.find((c) => c.id === id);
}

export function formatCategoryTitle(slug: string): string {
  const found = getCategoryById(slug);
  if (found) return found.label;
  return slug
    .split("-")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}
