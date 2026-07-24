"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
import { Toggle } from "@/components/ui/toggle";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, t } from "@/lib/i18n";
import { FormEvent, useEffect, useState } from "react";

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
  created_at: string;
  updated_at: string;
};

type ListResp = {
  items: Promo[];
  total: number;
  has_more: boolean;
  page: number;
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
};

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
  };
}

export default function PromoCodesPage() {
  const [items, setItems] = useState<Promo[]>([]);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ limit: "50", page: String(page) });
      if (q.trim()) params.set("q", q.trim());
      const res = await apiFetch<ListResp>(`/api/v1/admin/promo-codes?${params}`);
      setItems(res.items ?? []);
      setTotal(res.total ?? 0);
      setHasMore(res.has_more ?? false);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [page]);

  function resetForm() {
    setForm(emptyForm());
    setEditingId(null);
  }

  function startEdit(p: Promo) {
    setEditingId(p.id);
    setForm(formFromPromo(p));
    setSuccess(null);
    setError(null);
  }

  function buildPayload() {
    if (!form.code.trim()) throw new Error(t("promos.codeRequired"));
    const value = Number(form.discount_value);
    if (!Number.isFinite(value) || value <= 0) {
      throw new Error(t("promos.valueRequired"));
    }
    if (form.discount_type === "percent" && value > 100) {
      throw new Error(t("promos.percentMax"));
    }

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
      await load();
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
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  function discountLabel(p: Promo) {
    return p.discount_type === "percent"
      ? `${p.discount_value}%`
      : `$${p.discount_value}`;
  }

  return (
    <div className="space-y-8">
      <PageHeader title={t("promos.title")} subtitle={t("promos.subtitle")} />

      {error ? <Alert variant="error">{error}</Alert> : null}
      {success ? <Alert variant="success">{success}</Alert> : null}

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
        <section className="overflow-hidden rounded-xl border bg-white shadow-sm">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-3">
            <h2 className="text-sm font-semibold">{t("promos.existing")}</h2>
            <div className="ml-auto flex gap-2">
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder={t("promos.search")}
                className="rounded-lg border px-3 py-1.5 text-sm"
              />
              <button
                type="button"
                onClick={() => {
                  setPage(1);
                  void load();
                }}
                className="rounded-lg bg-zinc-900 px-3 py-1.5 text-sm text-white"
              >
                {t("app.search")}
              </button>
            </div>
          </div>

          {loading ? (
            <p className="px-4 py-8 text-sm text-zinc-500">{t("app.loading")}</p>
          ) : items.length === 0 ? (
            <EmptyState message={t("app.noData")} />
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                  <tr>
                    <th className="px-4 py-2">{t("promos.colCode")}</th>
                    <th className="px-4 py-2">{t("promos.colDiscount")}</th>
                    <th className="px-4 py-2">{t("promos.colUses")}</th>
                    <th className="px-4 py-2">{t("promos.colValid")}</th>
                    <th className="px-4 py-2">{t("promos.colStatus")}</th>
                    <th className="px-4 py-2">{t("app.actions")}</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((p) => (
                    <tr key={p.id} className="border-t">
                      <td className="px-4 py-3">
                        <p className="font-semibold">{p.code}</p>
                        {p.description ? (
                          <p className="text-xs text-zinc-500">{p.description}</p>
                        ) : null}
                      </td>
                      <td className="px-4 py-3">{discountLabel(p)}</td>
                      <td className="px-4 py-3">
                        {p.used_count}
                        {p.max_uses != null ? ` / ${p.max_uses}` : ""}
                      </td>
                      <td className="px-4 py-3 text-xs text-zinc-600">
                        {p.valid_until ? formatDate(p.valid_until) : t("promos.noExpiry")}
                      </td>
                      <td className="px-4 py-3">
                        <StatusBadge status={p.is_active ? "active" : "inactive"} />
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex gap-2">
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
          )}

          <Pagination
            page={page}
            hasMore={hasMore}
            total={total}
            onPageChange={setPage}
          />
        </section>

        <section className="rounded-xl border bg-white p-4 shadow-sm">
          <h2 className="mb-3 text-sm font-semibold">
            {editingId ? t("promos.editTitle") : t("promos.createTitle")}
          </h2>
          <form className="space-y-3" onSubmit={(e) => void handleSubmit(e)}>
            <label className="block text-xs font-medium text-zinc-600">
              {t("promos.code")}
              <input
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm uppercase"
                value={form.code}
                onChange={(e) => setForm({ ...form, code: e.target.value })}
                required
              />
            </label>
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
                  onChange={(e) =>
                    setForm({ ...form, applies_premium: e.target.checked })
                  }
                />
                Premium
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.applies_business}
                  onChange={(e) =>
                    setForm({ ...form, applies_business: e.target.checked })
                  }
                />
                Business
              </label>
            </div>
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
                  onChange={(e) =>
                    setForm({ ...form, max_uses_per_user: e.target.value })
                  }
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
    </div>
  );
}
