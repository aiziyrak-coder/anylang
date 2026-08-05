"use client";

import { Alert } from "@/components/admin/alert";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { StatusBadge } from "@/components/admin/status-badge";
import { Toggle } from "@/components/ui/toggle";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, formatNumber, t } from "@/lib/i18n";
import { FormEvent, useCallback, useEffect, useState } from "react";

type CodeType = "standard" | "campaign" | "referral" | "influencer";
type Segment = "all" | "new_users";

type Promo = {
  id: number;
  code: string;
  description: string | null;
  discount_type: "percent" | "fixed";
  discount_value: string;
  applies_to_plans: string[] | null;
  min_months: number | null;
  max_uses: number | null;
  used_count: number;
  max_uses_per_user: number;
  valid_from: string | null;
  valid_until: string | null;
  is_active: boolean;
  is_paused: boolean;
  campaign_key: string | null;
  variant: string | null;
  code_type: CodeType;
  segment: Segment;
  new_user_max_age_days: number;
  allowed_countries: string[] | null;
  allowed_languages: string[] | null;
  influencer_label: string | null;
  status: string;
};

type FormState = {
  code: string;
  description: string;
  discount_type: "percent" | "fixed";
  discount_value: string;
  applies_premium: boolean;
  applies_business: boolean;
  min_months: string;
  max_uses: string;
  max_uses_per_user: string;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
  code_type: CodeType;
  segment: Segment;
  new_user_max_age_days: string;
  countries: string;
  languages: string;
  influencer_label: string;
  campaign_key: string;
};

type Dashboard = {
  days: number;
  summary: {
    codes_total: number;
    codes_live: number;
    codes_paused: number;
    uses_all_time: number;
    redemptions_window: number;
    unique_users_window: number;
    discount_sum_window: number;
    redemptions_24h: number;
  };
  by_type: { code_type: string; codes: number; uses: number }[];
  top_codes: {
    id: number;
    code: string;
    code_type: string;
    variant: string | null;
    window_uses: number;
    window_discount: number;
    used_count: number;
    max_uses: number | null;
  }[];
  ab_campaigns: {
    campaign_key: string;
    variants: { variant: string | null; code: string; uses: number }[];
  }[];
  abuse: {
    velocity_alert: boolean;
    multi_redeem_users: { user_id: number; email: string; count: number }[];
    fresh_account_redeems: {
      code: string;
      user_id: number;
      email: string;
      redeemed_at: string | null;
    }[];
  };
};

type Tab = "list" | "dashboard" | "campaign";

const emptyForm = (): FormState => ({
  code: "",
  description: "",
  discount_type: "percent",
  discount_value: "10",
  applies_premium: true,
  applies_business: true,
  min_months: "",
  max_uses: "",
  max_uses_per_user: "1",
  valid_from: "",
  valid_until: "",
  is_active: true,
  code_type: "standard",
  segment: "all",
  new_user_max_age_days: "7",
  countries: "",
  languages: "",
  influencer_label: "",
  campaign_key: "",
});

function toLocalInput(iso: string | null): string {
  if (!iso) return "";
  try {
    const d = new Date(iso);
    const pad = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  } catch {
    return "";
  }
}

function formFromPromo(p: Promo): FormState {
  const plans = p.applies_to_plans ?? [];
  const all = plans.length === 0;
  return {
    code: p.code,
    description: p.description ?? "",
    discount_type: p.discount_type,
    discount_value: p.discount_value,
    applies_premium: all || plans.includes("premium"),
    applies_business: all || plans.includes("business"),
    min_months: p.min_months != null ? String(p.min_months) : "",
    max_uses: p.max_uses != null ? String(p.max_uses) : "",
    max_uses_per_user: String(p.max_uses_per_user ?? 1),
    valid_from: toLocalInput(p.valid_from),
    valid_until: toLocalInput(p.valid_until),
    is_active: p.is_active,
    code_type: p.code_type || "standard",
    segment: p.segment || "all",
    new_user_max_age_days: String(p.new_user_max_age_days ?? 7),
    countries: (p.allowed_countries || []).join(", "),
    languages: (p.allowed_languages || []).join(", "),
    influencer_label: p.influencer_label ?? "",
    campaign_key: p.campaign_key ?? "",
  };
}

function parseList(raw: string): string[] | null {
  const items = raw
    .split(/[,;\s]+/)
    .map((x) => x.trim())
    .filter(Boolean);
  return items.length ? items : null;
}

function typeLabel(ct: string) {
  const map: Record<string, string> = {
    standard: t("promos.typeStandard"),
    campaign: t("promos.typeCampaign"),
    referral: t("promos.typeReferral"),
    influencer: t("promos.typeInfluencer"),
  };
  return map[ct] ?? ct;
}

function statusForBadge(p: Promo): string {
  if (p.is_paused) return "paused";
  if (p.status === "expired") return "expired";
  if (p.status === "exhausted") return "inactive";
  return p.is_active ? "active" : "inactive";
}

export default function PromoCodesPage() {
  const list = useAdminList<Promo, { active_only: string; code_type: string }>({
    queryKey: "admin-promo-codes",
    path: "/api/v1/admin/promo-codes",
    defaultSort: "id",
    initialFilters: { active_only: "", code_type: "" },
  });

  const [tab, setTab] = useState<Tab>("list");
  const [form, setForm] = useState<FormState>(emptyForm);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  const [dashDays, setDashDays] = useState(7);
  const [dash, setDash] = useState<Dashboard | null>(null);
  const [dashLoading, setDashLoading] = useState(false);

  const [camp, setCamp] = useState({
    campaign_key: "",
    code_a: "",
    code_b: "",
    description: "",
    discount_type: "percent" as "percent" | "fixed",
    discount_value_a: "10",
    discount_value_b: "15",
    applies_premium: true,
    applies_business: true,
    segment: "new_users" as Segment,
    new_user_max_age_days: "7",
    countries: "",
    languages: "",
    max_uses: "",
    valid_until: "",
  });

  const loadDash = useCallback(async () => {
    setDashLoading(true);
    try {
      const data = await apiFetch<Dashboard>(
        `/api/v1/admin/promo-codes/dashboard?days=${dashDays}`
      );
      setDash(data);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setDashLoading(false);
    }
  }, [dashDays]);

  useEffect(() => {
    if (tab === "dashboard") void loadDash();
  }, [tab, loadDash]);

  function resetForm() {
    setForm(emptyForm());
    setEditingId(null);
  }

  function startEdit(p: Promo) {
    setEditingId(p.id);
    setForm(formFromPromo(p));
    setSuccess(null);
    setError(null);
    setTab("list");
  }

  function buildPayload() {
    if (!form.code.trim()) throw new Error(t("promos.codeRequired"));
    const value = Number(form.discount_value);
    if (!Number.isFinite(value) || value <= 0) throw new Error(t("promos.valueRequired"));
    if (form.discount_type === "percent" && value > 100) throw new Error(t("promos.percentMax"));

    const plans: string[] = [];
    if (form.applies_premium) plans.push("premium");
    if (form.applies_business) plans.push("business");
    if (plans.length === 0) throw new Error(t("promos.plansRequired"));
    const both = form.applies_premium && form.applies_business;

    return {
      code: form.code.trim().toUpperCase(),
      description: form.description.trim() || null,
      discount_type: form.discount_type,
      discount_value: value,
      applies_to_plans: both ? null : plans,
      min_months: form.min_months ? Number(form.min_months) : null,
      max_uses: form.max_uses ? Number(form.max_uses) : null,
      max_uses_per_user: Number(form.max_uses_per_user) || 1,
      valid_from: form.valid_from ? new Date(form.valid_from).toISOString() : null,
      valid_until: form.valid_until ? new Date(form.valid_until).toISOString() : null,
      is_active: form.is_active,
      code_type: form.code_type,
      segment: form.segment,
      new_user_max_age_days: Number(form.new_user_max_age_days) || 7,
      allowed_countries: parseList(form.countries)?.map((c) => c.toUpperCase()) ?? null,
      allowed_languages: parseList(form.languages),
      influencer_label: form.influencer_label.trim() || null,
      campaign_key: form.campaign_key.trim() || null,
    };
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const payload = buildPayload();
      if (editingId) {
        await apiFetch(`/api/v1/admin/promo-codes/${editingId}`, {
          method: "PATCH",
          body: JSON.stringify(payload),
        });
        setSuccess(t("promos.updated", { code: payload.code }));
      } else {
        await apiFetch("/api/v1/admin/promo-codes", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        setSuccess(t("promos.created", { code: payload.code }));
        resetForm();
      }
      await list.refetch();
    } catch (err) {
      if (err instanceof ApiError) setError(err.message);
      else if (err instanceof Error) setError(err.message);
      else setError(t("app.error"));
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(p: Promo) {
    if (!window.confirm(t("promos.confirmDelete", { code: p.code }))) return;
    setError(null);
    try {
      await apiFetch(`/api/v1/admin/promo-codes/${p.id}`, { method: "DELETE" });
      setSuccess(t("promos.deleted", { code: p.code }));
      if (editingId === p.id) resetForm();
      await list.refetch();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  async function togglePause(p: Promo) {
    setBusyId(p.id);
    setError(null);
    try {
      await apiFetch(`/api/v1/admin/promo-codes/${p.id}/pause`, {
        method: "POST",
        body: JSON.stringify({ paused: !p.is_paused }),
      });
      setSuccess(p.is_paused ? t("promos.resume") : t("promos.pause"));
      await list.refetch();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function expireStale() {
    setError(null);
    try {
      const res = await apiFetch<{ expired: number }>("/api/v1/admin/promo-codes/expire-stale", {
        method: "POST",
      });
      setSuccess(t("promos.expiredCount", { n: res.expired }));
      await list.refetch();
      if (tab === "dashboard") await loadDash();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  async function createCampaign(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const plans: string[] = [];
      if (camp.applies_premium) plans.push("premium");
      if (camp.applies_business) plans.push("business");
      if (plans.length === 0) throw new Error(t("promos.plansRequired"));
      const both = camp.applies_premium && camp.applies_business;
      const data = await apiFetch<{ campaign_key: string }>("/api/v1/admin/promo-codes/campaign", {
        method: "POST",
        body: JSON.stringify({
          campaign_key: camp.campaign_key.trim() || null,
          code_a: camp.code_a.trim().toUpperCase(),
          code_b: camp.code_b.trim().toUpperCase(),
          description: camp.description.trim() || null,
          discount_type: camp.discount_type,
          discount_value_a: Number(camp.discount_value_a),
          discount_value_b: Number(camp.discount_value_b),
          applies_to_plans: both ? null : plans,
          segment: camp.segment,
          new_user_max_age_days: Number(camp.new_user_max_age_days) || 7,
          allowed_countries: parseList(camp.countries)?.map((c) => c.toUpperCase()) ?? null,
          allowed_languages: parseList(camp.languages),
          max_uses: camp.max_uses ? Number(camp.max_uses) : null,
          valid_until: camp.valid_until ? new Date(camp.valid_until).toISOString() : null,
        }),
      });
      setSuccess(t("promos.campaignCreated", { key: data.campaign_key }));
      await list.refetch();
      setTab("list");
    } catch (err) {
      if (err instanceof ApiError) setError(err.message);
      else if (err instanceof Error) setError(err.message);
      else setError(t("app.error"));
    } finally {
      setSaving(false);
    }
  }

  function discountLabel(p: Promo) {
    return p.discount_type === "percent" ? `${p.discount_value}%` : `$${p.discount_value}`;
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("promos.title")} subtitle={t("promos.subtitle")}>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => void expireStale()}
            className="rounded-lg border px-3 py-1.5 text-sm hover:bg-zinc-50"
          >
            {t("promos.expireStale")}
          </button>
        </div>
      </PageHeader>

      <div className="flex flex-wrap gap-1 border-b pb-2">
        {(
          [
            ["list", "promos.tabList"],
            ["dashboard", "promos.tabDashboard"],
            ["campaign", "promos.tabCampaign"],
          ] as const
        ).map(([id, key]) => (
          <button
            key={id}
            type="button"
            onClick={() => setTab(id)}
            className={`rounded-lg px-3 py-1.5 text-sm ${
              tab === id ? "bg-zinc-900 text-white" : "text-zinc-600 hover:bg-zinc-100"
            }`}
          >
            {t(key)}
          </button>
        ))}
      </div>

      {error ? <Alert variant="error">{error}</Alert> : null}
      {success ? <Alert variant="success">{success}</Alert> : null}

      {tab === "list" ? (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_400px]">
          <section className="overflow-hidden rounded-xl border bg-white shadow-sm">
            <div className="border-b px-4 py-3">
              <h2 className="mb-3 text-sm font-semibold">{t("promos.existing")}</h2>
              <DataToolbar
                search={{
                  value: list.q,
                  onChange: list.setQ,
                  placeholder: t("promos.search"),
                }}
                showClear={list.hasActiveFilters}
                onClear={list.clearFilters}
                filters={
                  <>
                    <select
                      value={list.filters.active_only}
                      onChange={(e) => list.setFilter("active_only", e.target.value)}
                      className="rounded-lg border px-3 py-2 text-sm"
                    >
                      <option value="">{t("app.all")}</option>
                      <option value="true">{t("promos.activeOnly")}</option>
                    </select>
                    <select
                      value={list.filters.code_type}
                      onChange={(e) => list.setFilter("code_type", e.target.value)}
                      className="rounded-lg border px-3 py-2 text-sm"
                    >
                      <option value="">{t("promos.allTypes")}</option>
                      <option value="standard">{t("promos.typeStandard")}</option>
                      <option value="campaign">{t("promos.typeCampaign")}</option>
                      <option value="referral">{t("promos.typeReferral")}</option>
                      <option value="influencer">{t("promos.typeInfluencer")}</option>
                    </select>
                  </>
                }
              />
            </div>

            <ListState
              isLoading={list.isLoading}
              error={list.error}
              isEmpty={list.items.length === 0}
              hasActiveFilters={list.hasActiveFilters}
              onClearFilters={list.clearFilters}
              onRetry={() => void list.refetch()}
            >
              <div className="overflow-x-auto">
                <table className="min-w-full text-left text-sm">
                  <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                    <tr>
                      <SortableTh
                        label={t("promos.colCode")}
                        sortKey="code"
                        sortBy={list.sort}
                        sortDir={list.order}
                        onSort={list.toggleSort}
                      />
                      <th className="px-4 py-2">{t("promos.colType")}</th>
                      <th className="px-4 py-2">{t("promos.colDiscount")}</th>
                      <SortableTh
                        label={t("promos.colUses")}
                        sortKey="used_count"
                        sortBy={list.sort}
                        sortDir={list.order}
                        onSort={list.toggleSort}
                      />
                      <SortableTh
                        label={t("promos.colValid")}
                        sortKey="valid_until"
                        sortBy={list.sort}
                        sortDir={list.order}
                        onSort={list.toggleSort}
                      />
                      <th className="px-4 py-2">{t("promos.colStatus")}</th>
                      <th className="px-4 py-2">{t("app.actions")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {list.items.map((p) => (
                      <tr key={p.id} className="border-t">
                        <td className="px-4 py-3">
                          <p className="font-semibold">
                            {p.code}
                            {p.variant ? (
                              <span className="ml-1 rounded bg-zinc-100 px-1.5 text-[10px]">
                                {p.variant}
                              </span>
                            ) : null}
                          </p>
                          <p className="text-xs text-zinc-500">
                            {p.influencer_label || p.campaign_key || p.description || "—"}
                          </p>
                        </td>
                        <td className="px-4 py-3 text-xs">{typeLabel(p.code_type)}</td>
                        <td className="px-4 py-3">{discountLabel(p)}</td>
                        <td className="px-4 py-3">
                          {p.used_count}
                          {p.max_uses != null ? ` / ${p.max_uses}` : ""}
                        </td>
                        <td className="px-4 py-3 text-xs text-zinc-600">
                          {p.valid_until ? formatDate(p.valid_until) : t("promos.noExpiry")}
                        </td>
                        <td className="px-4 py-3">
                          <StatusBadge status={statusForBadge(p)} />
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex flex-wrap gap-2">
                            <button
                              type="button"
                              disabled={busyId === p.id}
                              className="text-sm font-medium text-amber-700"
                              onClick={() => void togglePause(p)}
                            >
                              {p.is_paused ? t("promos.resume") : t("promos.pause")}
                            </button>
                            <button
                              type="button"
                              className="text-sm font-medium text-emerald-700"
                              onClick={() => startEdit(p)}
                            >
                              {t("app.edit")}
                            </button>
                            <button
                              type="button"
                              className="text-sm font-medium text-red-600"
                              onClick={() => void handleDelete(p)}
                            >
                              {t("app.delete")}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination
                page={list.page}
                total={list.total}
                hasMore={list.hasMore}
                onPageChange={list.setPage}
                limit={list.limit}
                onLimitChange={list.setLimit}
              />
            </ListState>
          </section>

          <section className="rounded-xl border bg-white p-4 shadow-sm">
            <h2 className="mb-3 text-sm font-semibold">
              {editingId ? t("promos.editTitle") : t("promos.createTitle")}
            </h2>
            <form className="space-y-3" onSubmit={(e) => void handleSubmit(e)}>
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.codeType")}
                <select
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                  value={form.code_type}
                  onChange={(e) =>
                    setForm({ ...form, code_type: e.target.value as CodeType })
                  }
                >
                  <option value="standard">{t("promos.typeStandard")}</option>
                  <option value="campaign">{t("promos.typeCampaign")}</option>
                  <option value="referral">{t("promos.typeReferral")}</option>
                  <option value="influencer">{t("promos.typeInfluencer")}</option>
                </select>
              </label>
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.code")}
                <input
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm uppercase"
                  value={form.code}
                  onChange={(e) => setForm({ ...form, code: e.target.value })}
                  required
                />
              </label>
              {(form.code_type === "referral" || form.code_type === "influencer") && (
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.influencerLabel")}
                  <input
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.influencer_label}
                    onChange={(e) => setForm({ ...form, influencer_label: e.target.value })}
                  />
                </label>
              )}
              {form.code_type === "campaign" && (
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.campaignKey")}
                  <input
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.campaign_key}
                    onChange={(e) => setForm({ ...form, campaign_key: e.target.value })}
                  />
                </label>
              )}
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.description")}
                <textarea
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                  rows={2}
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                />
              </label>
              <div className="grid grid-cols-2 gap-2">
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.discountType")}
                  <select
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.discount_type}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        discount_type: e.target.value as "percent" | "fixed",
                      })
                    }
                  >
                    <option value="percent">{t("promos.percent")}</option>
                    <option value="fixed">{t("promos.fixed")}</option>
                  </select>
                </label>
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.discountValue")}
                  <input
                    type="number"
                    step="0.01"
                    min="0.01"
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.discount_value}
                    onChange={(e) => setForm({ ...form, discount_value: e.target.value })}
                    required
                  />
                </label>
              </div>
              <div className="space-y-1">
                <p className="text-xs font-medium text-zinc-600">{t("promos.plans")}</p>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={form.applies_premium}
                    onChange={(e) => setForm({ ...form, applies_premium: e.target.checked })}
                  />
                  Premium
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={form.applies_business}
                    onChange={(e) => setForm({ ...form, applies_business: e.target.checked })}
                  />
                  Business
                </label>
              </div>
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.segment")}
                <select
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                  value={form.segment}
                  onChange={(e) => setForm({ ...form, segment: e.target.value as Segment })}
                >
                  <option value="all">{t("promos.segmentAll")}</option>
                  <option value="new_users">{t("promos.segmentNew")}</option>
                </select>
              </label>
              {form.segment === "new_users" ? (
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.newUserDays")}
                  <input
                    type="number"
                    min={1}
                    max={90}
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.new_user_max_age_days}
                    onChange={(e) =>
                      setForm({ ...form, new_user_max_age_days: e.target.value })
                    }
                  />
                </label>
              ) : null}
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.countries")}
                <input
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm uppercase"
                  placeholder="UZ, KZ, RU"
                  value={form.countries}
                  onChange={(e) => setForm({ ...form, countries: e.target.value })}
                />
              </label>
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.languages")}
                <input
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                  placeholder="uz_UZ, ru_RU, us_US"
                  value={form.languages}
                  onChange={(e) => setForm({ ...form, languages: e.target.value })}
                />
              </label>
              <div className="grid grid-cols-2 gap-2">
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.minMonths")}
                  <select
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.min_months}
                    onChange={(e) => setForm({ ...form, min_months: e.target.value })}
                  >
                    <option value="">{t("promos.anyMonths")}</option>
                    <option value="1">1</option>
                    <option value="3">3</option>
                    <option value="6">6</option>
                    <option value="12">12</option>
                  </select>
                </label>
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.maxUsesPerUser")}
                  <input
                    type="number"
                    min="1"
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.max_uses_per_user}
                    onChange={(e) => setForm({ ...form, max_uses_per_user: e.target.value })}
                  />
                </label>
              </div>
              <label className="block text-xs font-medium text-zinc-600">
                {t("promos.maxUses")}
                <input
                  type="number"
                  min="1"
                  className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                  value={form.max_uses}
                  onChange={(e) => setForm({ ...form, max_uses: e.target.value })}
                  placeholder={t("promos.unlimited")}
                />
              </label>
              <div className="grid grid-cols-1 gap-2">
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.validFrom")}
                  <input
                    type="datetime-local"
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.valid_from}
                    onChange={(e) => setForm({ ...form, valid_from: e.target.value })}
                  />
                </label>
                <label className="block text-xs font-medium text-zinc-600">
                  {t("promos.validUntil")}
                  <input
                    type="datetime-local"
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={form.valid_until}
                    onChange={(e) => setForm({ ...form, valid_until: e.target.value })}
                  />
                </label>
              </div>
              <div className="flex items-center justify-between rounded-lg border px-3 py-2">
                <span className="text-sm">{t("promos.active")}</span>
                <Toggle
                  label={t("promos.active")}
                  checked={form.is_active}
                  onChange={(v) => setForm({ ...form, is_active: v })}
                />
              </div>
              <div className="flex gap-2 pt-1">
                <button
                  type="submit"
                  disabled={saving}
                  className="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white disabled:opacity-60"
                >
                  {saving ? t("app.saving") : editingId ? t("app.edit") : t("promos.create")}
                </button>
                {editingId ? (
                  <button
                    type="button"
                    onClick={resetForm}
                    className="rounded-lg border px-3 py-2 text-sm"
                  >
                    {t("app.cancel")}
                  </button>
                ) : null}
              </div>
            </form>
          </section>
        </div>
      ) : null}

      {tab === "dashboard" ? (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center gap-2">
            <label className="text-xs text-zinc-500">{t("promos.days")}</label>
            <select
              value={dashDays}
              onChange={(e) => setDashDays(Number(e.target.value))}
              className="rounded-lg border px-2 py-1.5 text-sm"
            >
              <option value={1}>1</option>
              <option value={7}>7</option>
              <option value={30}>30</option>
              <option value={90}>90</option>
            </select>
            <button
              type="button"
              onClick={() => void loadDash()}
              className="rounded-lg border px-3 py-1.5 text-sm hover:bg-zinc-50"
            >
              {t("promos.reload")}
            </button>
          </div>
          {dashLoading && !dash ? (
            <p className="text-sm text-zinc-500">{t("app.loading")}</p>
          ) : null}
          {dash ? (
            <>
              <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
                {[
                  [t("promos.dashRedemptions"), dash.summary.redemptions_window],
                  [t("promos.dashUsers"), dash.summary.unique_users_window],
                  [t("promos.dashDiscount"), `$${formatNumber(dash.summary.discount_sum_window)}`],
                  [t("promos.dash24h"), dash.summary.redemptions_24h],
                  [t("promos.dashLive"), dash.summary.codes_live],
                  [t("promos.dashPaused"), dash.summary.codes_paused],
                ].map(([label, value]) => (
                  <div key={String(label)} className="rounded-xl border bg-white p-4">
                    <div className="text-xs text-zinc-500">{label}</div>
                    <div className="mt-1 text-lg font-semibold">{value}</div>
                  </div>
                ))}
              </div>

              <div className="grid gap-4 lg:grid-cols-2">
                <div className="rounded-xl border bg-white p-4">
                  <h3 className="mb-3 font-semibold">{t("promos.topCodes")}</h3>
                  {dash.top_codes.length === 0 ? (
                    <p className="text-sm text-zinc-500">{t("promos.noData")}</p>
                  ) : (
                    <ul className="space-y-2 text-sm">
                      {dash.top_codes.map((c) => (
                        <li key={c.id} className="flex justify-between border-b py-1">
                          <span>
                            <strong>{c.code}</strong>{" "}
                            <span className="text-xs text-zinc-500">
                              {typeLabel(c.code_type)}
                              {c.variant ? ` · ${c.variant}` : ""}
                            </span>
                          </span>
                          <span>
                            {c.window_uses} · ${formatNumber(c.window_discount)}
                          </span>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>

                <div className="rounded-xl border bg-white p-4">
                  <h3 className="mb-3 font-semibold">{t("promos.abTitle")}</h3>
                  {dash.ab_campaigns.length === 0 ? (
                    <p className="text-sm text-zinc-500">{t("promos.noData")}</p>
                  ) : (
                    <ul className="space-y-3 text-sm">
                      {dash.ab_campaigns.map((c) => (
                        <li key={c.campaign_key}>
                          <div className="font-medium">{c.campaign_key}</div>
                          <div className="mt-1 flex gap-3 text-zinc-600">
                            {c.variants.map((v) => (
                              <span key={`${v.code}-${v.variant}`}>
                                {v.variant || "?"}: {v.code} ({v.uses})
                              </span>
                            ))}
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>

              <div className="rounded-xl border bg-white p-4">
                <h3 className="mb-2 font-semibold">{t("promos.abuseTitle")}</h3>
                {dash.abuse.velocity_alert ? (
                  <Alert variant="error">{t("promos.abuseVelocity")}</Alert>
                ) : null}
                <div className="mt-3 grid gap-4 md:grid-cols-2">
                  <div>
                    <p className="mb-2 text-xs font-medium text-zinc-500">
                      {t("promos.abuseMulti")}
                    </p>
                    {dash.abuse.multi_redeem_users.length === 0 ? (
                      <p className="text-sm text-zinc-500">{t("promos.noData")}</p>
                    ) : (
                      <ul className="space-y-1 text-sm">
                        {dash.abuse.multi_redeem_users.map((u) => (
                          <li key={u.user_id}>
                            #{u.user_id} {u.email} — {u.count}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-medium text-zinc-500">
                      {t("promos.abuseFresh")}
                    </p>
                    {dash.abuse.fresh_account_redeems.length === 0 ? (
                      <p className="text-sm text-zinc-500">{t("promos.noData")}</p>
                    ) : (
                      <ul className="space-y-1 text-sm">
                        {dash.abuse.fresh_account_redeems.map((r, i) => (
                          <li key={`${r.user_id}-${i}`}>
                            {r.code} · #{r.user_id} {r.email}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </div>
              </div>
            </>
          ) : null}
        </div>
      ) : null}

      {tab === "campaign" ? (
        <form
          onSubmit={(e) => void createCampaign(e)}
          className="max-w-xl space-y-3 rounded-xl border bg-white p-6"
        >
          <h2 className="text-sm font-semibold">{t("promos.campaignCreate")}</h2>
          <label className="block text-xs font-medium text-zinc-600">
            {t("promos.campaignKey")}
            <input
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              value={camp.campaign_key}
              onChange={(e) => setCamp({ ...camp, campaign_key: e.target.value })}
              placeholder="spring_sale"
            />
          </label>
          <div className="grid grid-cols-2 gap-2">
            <label className="block text-xs font-medium text-zinc-600">
              {t("promos.codeA")}
              <input
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm uppercase"
                value={camp.code_a}
                onChange={(e) => setCamp({ ...camp, code_a: e.target.value })}
                required
              />
            </label>
            <label className="block text-xs font-medium text-zinc-600">
              {t("promos.codeB")}
              <input
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm uppercase"
                value={camp.code_b}
                onChange={(e) => setCamp({ ...camp, code_b: e.target.value })}
                required
              />
            </label>
          </div>
          <div className="grid grid-cols-3 gap-2">
            <label className="block text-xs font-medium text-zinc-600">
              {t("promos.discountType")}
              <select
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                value={camp.discount_type}
                onChange={(e) =>
                  setCamp({
                    ...camp,
                    discount_type: e.target.value as "percent" | "fixed",
                  })
                }
              >
                <option value="percent">{t("promos.percent")}</option>
                <option value="fixed">{t("promos.fixed")}</option>
              </select>
            </label>
            <label className="block text-xs font-medium text-zinc-600">
              {t("promos.valueA")}
              <input
                type="number"
                step="0.01"
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                value={camp.discount_value_a}
                onChange={(e) => setCamp({ ...camp, discount_value_a: e.target.value })}
                required
              />
            </label>
            <label className="block text-xs font-medium text-zinc-600">
              {t("promos.valueB")}
              <input
                type="number"
                step="0.01"
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                value={camp.discount_value_b}
                onChange={(e) => setCamp({ ...camp, discount_value_b: e.target.value })}
                required
              />
            </label>
          </div>
          <label className="block text-xs font-medium text-zinc-600">
            {t("promos.segment")}
            <select
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              value={camp.segment}
              onChange={(e) => setCamp({ ...camp, segment: e.target.value as Segment })}
            >
              <option value="all">{t("promos.segmentAll")}</option>
              <option value="new_users">{t("promos.segmentNew")}</option>
            </select>
          </label>
          <label className="block text-xs font-medium text-zinc-600">
            {t("promos.countries")}
            <input
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm uppercase"
              value={camp.countries}
              onChange={(e) => setCamp({ ...camp, countries: e.target.value })}
            />
          </label>
          <label className="block text-xs font-medium text-zinc-600">
            {t("promos.languages")}
            <input
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              value={camp.languages}
              onChange={(e) => setCamp({ ...camp, languages: e.target.value })}
            />
          </label>
          <label className="block text-xs font-medium text-zinc-600">
            {t("promos.validUntil")}
            <input
              type="datetime-local"
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              value={camp.valid_until}
              onChange={(e) => setCamp({ ...camp, valid_until: e.target.value })}
            />
          </label>
          <div className="flex gap-4 text-sm">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={camp.applies_premium}
                onChange={(e) => setCamp({ ...camp, applies_premium: e.target.checked })}
              />
              Premium
            </label>
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={camp.applies_business}
                onChange={(e) => setCamp({ ...camp, applies_business: e.target.checked })}
              />
              Business
            </label>
          </div>
          <button
            type="submit"
            disabled={saving}
            className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
          >
            {saving ? t("app.saving") : t("promos.campaignCreate")}
          </button>
        </form>
      ) : null}
    </div>
  );
}
