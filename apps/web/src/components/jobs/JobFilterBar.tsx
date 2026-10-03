"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { JOB_LANGUAGES, POPULAR_TECH_STACKS } from "@/lib/job-languages";
import { JOB_CATEGORIES } from "@/lib/job-categories";
import {
  Search,
  Filter,
  Bookmark,
  Check,
  RotateCcw,
  Sparkles,
  Globe,
  SlidersHorizontal,
  X,
} from "lucide-react";

const STORAGE_KEY = "clivora_saved_job_filters_v1";

interface SavedFilterState {
  lang?: string;
  category?: string;
  tech?: string;
  type?: string;
  q?: string;
}

export function JobFilterBar() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const currentQ = searchParams.get("q") || "";
  const currentLang = searchParams.get("lang") || "all";
  const currentCategory = searchParams.get("category") || "all";
  const currentTech = searchParams.get("tech") || "all";
  const currentType = searchParams.get("type") || "all";

  const [searchVal, setSearchVal] = useState(currentQ);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [savedFilter, setSavedFilter] = useState<SavedFilterState | null>(null);
  const [justSaved, setJustSaved] = useState(false);

  // Load saved filter from localStorage
  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        setSavedFilter(parsed);
      }
    } catch {
      // Ignore localStorage errors
    }
  }, []);

  const updateFilters = (changes: Record<string, string | null>) => {
    const params = new URLSearchParams(searchParams.toString());
    params.delete("page"); // Reset page on filter change

    for (const [key, val] of Object.entries(changes)) {
      if (!val || val === "all") {
        params.delete(key);
      } else {
        params.set(key, val);
      }
    }

    const queryStr = params.toString();
    router.push(queryStr ? `/jobs?${queryStr}` : "/jobs");
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    updateFilters({ q: searchVal.trim() || null });
  };

  const saveCurrentFilter = () => {
    const filterToSave: SavedFilterState = {
      lang: currentLang !== "all" ? currentLang : undefined,
      category: currentCategory !== "all" ? currentCategory : undefined,
      tech: currentTech !== "all" ? currentTech : undefined,
      type: currentType !== "all" ? currentType : undefined,
      q: currentQ ? currentQ : undefined,
    };

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(filterToSave));
      setSavedFilter(filterToSave);
      setJustSaved(true);
      setTimeout(() => setJustSaved(false), 2500);
    } catch {
      // Ignore
    }
  };

  const applySavedFilter = () => {
    if (!savedFilter) return;
    updateFilters({
      lang: savedFilter.lang || null,
      category: savedFilter.category || null,
      tech: savedFilter.tech || null,
      type: savedFilter.type || null,
      q: savedFilter.q || null,
    });
    if (savedFilter.q) setSearchVal(savedFilter.q);
  };

  const clearSavedFilter = (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      localStorage.removeItem(STORAGE_KEY);
      setSavedFilter(null);
    } catch {
      // Ignore
    }
  };

  const resetAllFilters = () => {
    setSearchVal("");
    router.push("/jobs");
  };

  const hasActiveFilters =
    Boolean(currentQ) ||
    currentLang !== "all" ||
    currentCategory !== "all" ||
    currentTech !== "all" ||
    currentType !== "all";

  return (
    <div className="space-y-4">
      {/* Search Input & Action Controls */}
      <form onSubmit={handleSearchSubmit} className="flex flex-col gap-2.5 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-400" />
          <input
            type="search"
            value={searchVal}
            onChange={(e) => setSearchVal(e.target.value)}
            placeholder="Search by role title, technology stack, or company name..."
            className="w-full rounded-2xl border border-slate-300 bg-white py-3.5 pl-12 pr-4 text-sm text-slate-900 shadow-xs outline-none transition-all placeholder:text-slate-400 focus:border-teal-600 focus:ring-2 focus:ring-teal-600/20"
          />
        </div>

        <div className="flex items-center gap-2">
          <button
            type="submit"
            className="flex-1 sm:flex-none rounded-2xl bg-teal-600 px-6 py-3.5 text-sm font-semibold text-white shadow-sm transition-all hover:bg-teal-700 hover:shadow active:scale-95"
          >
            Search
          </button>
          <button
            type="button"
            onClick={() => setShowAdvanced(!showAdvanced)}
            className={`flex items-center gap-1.5 rounded-2xl border px-4 py-3.5 text-sm font-semibold transition-all ${
              showAdvanced || hasActiveFilters
                ? "border-teal-500 bg-teal-50 text-teal-800"
                : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"
            }`}
          >
            <SlidersHorizontal className="h-4 w-4" />
            <span>Filters</span>
          </button>
        </div>
      </form>

      {/* Spoken Language Filter Tabs */}
      <div className="rounded-2xl border border-slate-200/90 bg-white p-3.5 shadow-2xs">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <Globe className="h-4 w-4 text-teal-600 shrink-0" />
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Language Division:
            </span>
          </div>

          {/* Save Filter / Saved Filter Badge */}
          <div className="flex items-center gap-2">
            {savedFilter && (
              <button
                type="button"
                onClick={applySavedFilter}
                className="inline-flex items-center gap-1.5 rounded-xl border border-teal-200 bg-teal-50/90 px-3 py-1 text-xs font-semibold text-teal-800 transition-colors hover:bg-teal-100"
                title="Click to apply your saved filter configuration"
              >
                <Bookmark className="h-3.5 w-3.5 text-teal-600 fill-teal-600" />
                <span>Load Saved Filter</span>
                <span
                  role="button"
                  tabIndex={0}
                  onClick={clearSavedFilter}
                  className="ml-1 rounded-full p-0.5 hover:bg-teal-200"
                  title="Remove saved filter"
                >
                  <X className="h-3 w-3" />
                </span>
              </button>
            )}

            <button
              type="button"
              onClick={saveCurrentFilter}
              className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-semibold text-slate-700 transition-colors hover:bg-slate-100 active:scale-95"
            >
              {justSaved ? (
                <>
                  <Check className="h-3.5 w-3.5 text-emerald-600" />
                  <span className="text-emerald-700">Filter Saved!</span>
                </>
              ) : (
                <>
                  <Bookmark className="h-3.5 w-3.5 text-slate-500" />
                  <span>Save This Filter</span>
                </>
              )}
            </button>
          </div>
        </div>

        {/* Language Pills */}
        <div className="mt-3 flex flex-wrap items-center gap-1.5">
          {JOB_LANGUAGES.map((lang) => {
            const isSelected = currentLang === lang.code;
            return (
              <button
                key={lang.code}
                type="button"
                onClick={() => updateFilters({ lang: lang.code === "all" ? null : lang.code })}
                className={`flex items-center gap-1.5 rounded-xl px-3.5 py-1.5 text-xs font-semibold transition-all ${
                  isSelected
                    ? "bg-teal-700 text-white shadow-2xs"
                    : "border border-slate-200 bg-slate-50/80 text-slate-700 hover:border-teal-300 hover:bg-teal-50/60"
                }`}
              >
                <span>{lang.flag}</span>
                <span>{lang.nativeLabel}</span>
                {lang.code !== "all" && (
                  <span
                    className={`rounded-full px-1.5 py-px text-[10px] ${
                      isSelected ? "bg-teal-800 text-teal-100" : "bg-slate-200 text-slate-600"
                    }`}
                  >
                    {lang.code.toUpperCase()}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Tech Stack Pills Bar */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-thin">
        <span className="shrink-0 text-xs font-bold uppercase tracking-wider text-slate-400">
          Tech Stack:
        </span>
        {POPULAR_TECH_STACKS.map((tech) => {
          const isSelected = currentTech === tech.id;
          return (
            <button
              key={tech.id}
              type="button"
              onClick={() => updateFilters({ tech: tech.id === "all" ? null : tech.id })}
              className={`shrink-0 rounded-lg px-2.5 py-1 text-xs font-medium transition-all ${
                isSelected
                  ? "bg-slate-900 text-white font-bold shadow-2xs"
                  : "border border-slate-200 bg-white text-slate-600 hover:border-slate-300 hover:bg-slate-50"
              }`}
            >
              {tech.label}
            </button>
          );
        })}
      </div>

      {/* Advanced Filter Collapsible Area */}
      {showAdvanced && (
        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            {/* Category Select */}
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Job Category
              </label>
              <select
                value={currentCategory}
                onChange={(e) => updateFilters({ category: e.target.value })}
                className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs font-semibold text-slate-800 outline-none focus:border-teal-600 focus:ring-1 focus:ring-teal-600"
              >
                <option value="all">All Categories (12 Fields)</option>
                {JOB_CATEGORIES.map((cat) => (
                  <option key={cat.id} value={cat.id}>
                    {cat.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Employment Type */}
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Engagement Type
              </label>
              <select
                value={currentType}
                onChange={(e) => updateFilters({ type: e.target.value })}
                className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs font-semibold text-slate-800 outline-none focus:border-teal-600 focus:ring-1 focus:ring-teal-600"
              >
                <option value="all">All Engagement Types</option>
                <option value="full_time">Full-Time Remote</option>
                <option value="contract">Contract / Project</option>
                <option value="part_time">Part-Time</option>
                <option value="freelance">Freelance</option>
              </select>
            </div>

            {/* Filter Actions */}
            <div className="flex items-end gap-2">
              <button
                type="button"
                onClick={resetAllFilters}
                className="flex items-center justify-center gap-1.5 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2 text-xs font-bold text-slate-700 hover:bg-slate-100 transition-colors"
              >
                <RotateCcw className="h-3.5 w-3.5" />
                Reset Filters
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Active Filter Badges */}
      {hasActiveFilters && (
        <div className="flex flex-wrap items-center gap-2 pt-1">
          <span className="text-xs font-bold text-slate-400">Active:</span>
          {currentLang !== "all" && (
            <span className="inline-flex items-center gap-1 rounded-full border border-teal-200 bg-teal-50 px-3 py-0.5 text-xs font-semibold text-teal-800">
              Language: {currentLang.toUpperCase()}
              <button
                type="button"
                onClick={() => updateFilters({ lang: null })}
                className="hover:text-teal-950"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          )}
          {currentTech !== "all" && (
            <span className="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-slate-100 px-3 py-0.5 text-xs font-semibold text-slate-800">
              Tech: {currentTech}
              <button
                type="button"
                onClick={() => updateFilters({ tech: null })}
                className="hover:text-slate-950"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          )}
          {currentCategory !== "all" && (
            <span className="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-slate-100 px-3 py-0.5 text-xs font-semibold text-slate-800">
              Category: {currentCategory}
              <button
                type="button"
                onClick={() => updateFilters({ category: null })}
                className="hover:text-slate-950"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          )}
          {currentType !== "all" && (
            <span className="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-slate-100 px-3 py-0.5 text-xs font-semibold text-slate-800">
              Type: {currentType.replace("_", " ")}
              <button
                type="button"
                onClick={() => updateFilters({ type: null })}
                className="hover:text-slate-950"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          )}
          {currentQ && (
            <span className="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-slate-100 px-3 py-0.5 text-xs font-semibold text-slate-800">
              Query: &quot;{currentQ}&quot;
              <button
                type="button"
                onClick={() => updateFilters({ q: null })}
                className="hover:text-slate-950"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          )}
          <button
            type="button"
            onClick={resetAllFilters}
            className="text-xs font-bold text-teal-700 underline hover:text-teal-900 ml-1"
          >
            Clear all
          </button>
        </div>
      )}
    </div>
  );
}
