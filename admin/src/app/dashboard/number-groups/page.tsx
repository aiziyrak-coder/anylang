"use client";

import { Toggle } from "@/components/ui/toggle";
import { Alert } from "@/components/admin/alert";
import { PageHeader } from "@/components/admin/page-header";
import { ApiError, apiFetch, apiFetchBlob } from "@/lib/api";
import { formatDate, t } from "@/lib/i18n";
import type { NumberGroup } from "@/lib/types";
import { cn } from "@/lib/utils";
import { FormEvent, useCallback, useEffect, useState } from "react";

type GroupFormState = {
  name: string;
  price: string;
  patterns: string;
  bonus_plan: string;
  priority: string;
  is_active: boolean;
  dynamic_pricing: boolean;
  sold_threshold: string;
  sold_multiplier: string;
  fill_threshold: string;
  fill_multiplier: string;
  max_multiplier: string;
};

type InventoryItem = {
  id: number;
  name: string;
  is_active: boolean;
  patterns: string[];
  base_price: string;
  effective_price: string;
  currency: string;
  assigned: number;
  reserved: number;
  free_est: number | null;
  capacity_est: number | null;
  fill_pct: number;
  sold_7d: number;
  dynamic_pricing: boolean;
  pricing_rules: Record<string, unknown>;
};

type SimResult = {
  pattern: string;
  estimated_size: number | null;
  preview: string[];
  truncated: boolean;
  valid: boolean;
};

type SalesData = {
  days: number;
  history: {
    payment_id: number;
    number: string | null;
    amount: string;
    paid_at: string;
    group_name: string | null;
    pattern: string | null;
  }[];
  top_groups: { group_name: string; sold: number; revenue: string }[];
  top_patterns: { pattern: string; sold: number; revenue: string }[];
  total_sold: number;
  total_revenue: string;
};

const emptyForm = (): GroupFormState => ({
  name: "",
  price: "0",
  patterns: "",
  bonus_plan: "",
  priority: "0",
  is_active: true,
  dynamic_pricing: false,
  sold_threshold: "5",
  sold_multiplier: "1.15",
  fill_threshold: "70",
  fill_multiplier: "1.3",
  max_multiplier: "2",
});

function formFromInventory(item: InventoryItem): GroupFormState {
  const rules = (item.pricing_rules || {}) as {
    enabled?: boolean;
    max_multiplier?: number;
    demand_thresholds?: {
      min_sold_7d?: number;
      min_fill_pct?: number;
      multiplier?: number;
    }[];
  };
  const soldTh = rules.demand_thresholds?.find((x) => x.min_sold_7d != null);
  const fillTh = rules.demand_thresholds?.find((x) => x.min_fill_pct != null);
  return {
    name: item.name,
    price: item.base_price,
    patterns: item.patterns.join(", "),
    bonus_plan: "",
    priority: "0",
    is_active: item.is_active,
    dynamic_pricing: Boolean(rules.enabled ?? item.dynamic_pricing),
    sold_threshold: String(soldTh?.min_sold_7d ?? 5),
    sold_multiplier: String(soldTh?.multiplier ?? 1.15),
    fill_threshold: String(fillTh?.min_fill_pct ?? 70),
    fill_multiplier: String(fillTh?.multiplier ?? 1.3),
    max_multiplier: String(rules.max_multiplier ?? 2),
  };
}

export default function NumberGroupsPage() {
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [totals, setTotals] = useState<{
    assigned: number;
    reserved: number;
    free_est: number;
  } | null>(null);
  const [form, setForm] = useState<GroupFormState>(emptyForm);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [simPattern, setSimPattern] = useState("AAAAAAA");
  const [sim, setSim] = useState<SimResult | null>(null);
  const [simBusy, setSimBusy] = useState(false);

  const [sales, setSales] = useState<SalesData | null>(null);
  const [tab, setTab] = useState<"inventory" | "sales">("inventory");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const inv = await apiFetch<{
        items: InventoryItem[];
        totals: { assigned: number; reserved: number; free_est: number };
      }>("/api/v1/admin/number-groups/inventory");
      setInventory(inv.items);
      setTotals(inv.totals);
      const s = await apiFetch<SalesData>("/api/v1/admin/number-groups/sales?days=90");
      setSales(s);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  function resetForm() {
    setForm(emptyForm());
    setEditingId(null);
    setSuccess(null);
  }

  async function startEdit(item: InventoryItem) {
    setEditingId(item.id);
    try {
      const groups = await apiFetch<NumberGroup[]>("/api/v1/admin/number-groups");
      const full = groups.find((g) => g.id === item.id);
      const base = formFromInventory(item);
      if (full) {
        base.bonus_plan = full.bonus_plan ?? "";
        base.priority = String(full.priority);
        base.patterns = full.patterns.join(", ");
        base.price = full.price;
      }
      setForm(base);
    } catch {
      setForm(formFromInventory(item));
    }
    setSuccess(null);
    setError(null);
  }

  function buildPricingRules() {
    if (!form.dynamic_pricing) return { enabled: false, demand_thresholds: [], max_multiplier: 2 };
    return {
      enabled: true,
      max_multiplier: Number(form.max_multiplier) || 2,
      demand_thresholds: [
        {
          min_sold_7d: Number(form.sold_threshold) || 5,
          multiplier: Number(form.sold_multiplier) || 1.15,
        },
        {
          min_fill_pct: Number(form.fill_threshold) || 70,
          multiplier: Number(form.fill_multiplier) || 1.3,
        },
      ],
    };
  }

  function buildPayload() {
    const patterns = form.patterns
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean);

    if (!form.name.trim()) throw new Error(t("numberGroups.nameRequired"));
    if (patterns.length === 0) throw new Error(t("numberGroups.patternsRequired"));

    return {
      name: form.name.trim(),
      price: Number(form.price),
      patterns,
      bonus_plan: form.bonus_plan.trim() || null,
      priority: Number(form.priority) || 0,
      is_active: form.is_active,
      pricing_rules: buildPricingRules(),
    };
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const payload = buildPayload();
      if (editingId) {
        const updated = await apiFetch<NumberGroup>(
          `/api/v1/admin/number-groups/${editingId}`,
          { method: "PATCH", body: JSON.stringify(payload) },
        );
        setSuccess(t("numberGroups.updated", { name: updated.name }));
      } else {
        const created = await apiFetch<NumberGroup>("/api/v1/admin/number-groups", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        setSuccess(t("numberGroups.created", { name: created.name }));
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

  async function runSim() {
    setSimBusy(true);
    setError(null);
    try {
      const data = await apiFetch<SimResult>("/api/v1/admin/number-groups/simulate", {
        method: "POST",
        body: JSON.stringify({ pattern: simPattern.trim(), preview_limit: 24 }),
      });
      setSim(data);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setSimBusy(false);
    }
  }

  async function exportGroups(fmt: "csv" | "json") {
    try {
      const { blob, filename } = await apiFetchBlob(
        `/api/v1/admin/number-groups/export?fmt=${fmt}`,
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      setSuccess(t("app.success"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  async function importCsv(file: File) {
    const text = await file.text();
    const lines = text.split(/\r?\n/).filter((l) => l.trim());
    if (lines.length < 2) {
      setError(t("numberGroups.importEmpty"));
      return;
    }
    const header = lines[0].split(",").map((h) => h.trim().replace(/^"|"$/g, ""));
    const items: Record<string, string>[] = [];
    for (const line of lines.slice(1)) {
      const cols = line.split(",").map((c) => c.trim().replace(/^"|"$/g, ""));
      const row: Record<string, string> = {};
      header.forEach((h, i) => {
        row[h] = cols[i] ?? "";
      });
      if (row.name) items.push(row);
    }
    try {
      const res = await apiFetch<{ created: number; updated: number; errors: string[] }>(
        "/api/v1/admin/number-groups/import",
        { method: "POST", body: JSON.stringify({ items, upsert: true }) },
      );
      setSuccess(
        t("numberGroups.importResult", {
          created: res.created,
          updated: res.updated,
        }),
      );
      if (res.errors?.length) setError(res.errors.slice(0, 3).join("; "));
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader title={t("numberGroups.title")} subtitle={t("numberGroups.subtitle")}>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => void exportGroups("csv")}
            className="rounded-lg border px-3 py-2 text-sm"
          >
            {t("numberGroups.exportCsv")}
          </button>
          <button
            type="button"
            onClick={() => void exportGroups("json")}
            className="rounded-lg border px-3 py-2 text-sm"
          >
            {t("numberGroups.exportJson")}
          </button>
          <label className="cursor-pointer rounded-lg border px-3 py-2 text-sm">
            {t("numberGroups.importCsv")}
            <input
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) void importCsv(f);
                e.target.value = "";
              }}
            />
          </label>
        </div>
      </PageHeader>

      {error ? <Alert variant="error">{error}</Alert> : null}
      {success ? <Alert variant="success">{success}</Alert> : null}

      {totals ? (
        <div className="grid gap-3 sm:grid-cols-3">
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("numberGroups.invAssigned")}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">{totals.assigned}</p>
          </div>
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("numberGroups.invReserved")}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums text-amber-700">
              {totals.reserved}
            </p>
          </div>
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("numberGroups.invFree")}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums text-emerald-700">
              {totals.free_est}
            </p>
          </div>
        </div>
      ) : null}

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
        <div className="space-y-6">
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setTab("inventory")}
              className={cn(
                "rounded-lg px-3 py-1.5 text-sm",
                tab === "inventory" ? "bg-zinc-900 text-white" : "border",
              )}
            >
              {t("numberGroups.tabInventory")}
            </button>
            <button
              type="button"
              onClick={() => setTab("sales")}
              className={cn(
                "rounded-lg px-3 py-1.5 text-sm",
                tab === "sales" ? "bg-zinc-900 text-white" : "border",
              )}
            >
              {t("numberGroups.tabSales")}
            </button>
          </div>

          {tab === "inventory" ? (
            <section className="overflow-hidden rounded-xl border bg-white shadow-sm">
              <div className="border-b px-4 py-3">
                <h2 className="text-sm font-semibold">{t("numberGroups.existing")}</h2>
              </div>
              {loading ? (
                <p className="px-4 py-8 text-sm text-zinc-500">{t("app.loading")}</p>
              ) : inventory.length === 0 ? (
                <p className="px-4 py-8 text-sm text-zinc-500">{t("app.noData")}</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y text-sm">
                    <thead className="bg-zinc-50">
                      <tr>
                        <th className="px-3 py-2 text-left">{t("numberGroups.colName")}</th>
                        <th className="px-3 py-2 text-left">{t("numberGroups.colPrice")}</th>
                        <th className="px-3 py-2 text-left">{t("numberGroups.invAssigned")}</th>
                        <th className="px-3 py-2 text-left">{t("numberGroups.invReserved")}</th>
                        <th className="px-3 py-2 text-left">{t("numberGroups.invFree")}</th>
                        <th className="px-3 py-2 text-left">{t("numberGroups.fill")}</th>
                        <th className="px-3 py-2" />
                      </tr>
                    </thead>
                    <tbody className="divide-y">
                      {inventory.map((g) => (
                        <tr key={g.id}>
                          <td className="px-3 py-2">
                            <p className="font-medium">{g.name}</p>
                            <p className="font-mono text-[10px] text-zinc-400">
                              {g.patterns.join(", ")}
                            </p>
                            {g.dynamic_pricing ? (
                              <span className="text-[10px] text-violet-700">
                                {t("numberGroups.dynamicOn")}
                              </span>
                            ) : null}
                          </td>
                          <td className="px-3 py-2 tabular-nums">
                            <span className="font-medium">
                              {g.currency} {g.effective_price}
                            </span>
                            {g.effective_price !== g.base_price ? (
                              <span className="block text-[10px] text-zinc-400 line-through">
                                {g.base_price}
                              </span>
                            ) : null}
                          </td>
                          <td className="px-3 py-2 tabular-nums">{g.assigned}</td>
                          <td className="px-3 py-2 tabular-nums text-amber-700">{g.reserved}</td>
                          <td className="px-3 py-2 tabular-nums text-emerald-700">
                            {g.free_est ?? "—"}
                          </td>
                          <td className="px-3 py-2 tabular-nums">{g.fill_pct}%</td>
                          <td className="px-3 py-2 text-right">
                            <button
                              type="button"
                              onClick={() => void startEdit(g)}
                              className="text-sm font-medium hover:underline"
                            >
                              {t("app.edit")}
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          ) : (
            <section className="space-y-4">
              <div className="rounded-xl border bg-white p-4">
                <p className="text-sm font-semibold">
                  {t("numberGroups.salesSummary", {
                    sold: sales?.total_sold ?? 0,
                    revenue: sales?.total_revenue ?? "0",
                  })}
                </p>
              </div>
              <div className="grid gap-4 md:grid-cols-2">
                <div className="rounded-xl border bg-white p-4">
                  <h3 className="mb-2 text-sm font-semibold">{t("numberGroups.topGroups")}</h3>
                  <ul className="space-y-1 text-sm">
                    {(sales?.top_groups ?? []).map((g) => (
                      <li key={g.group_name} className="flex justify-between gap-2">
                        <span>{g.group_name}</span>
                        <span className="tabular-nums text-zinc-600">
                          {g.sold} · ${g.revenue}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
                <div className="rounded-xl border bg-white p-4">
                  <h3 className="mb-2 text-sm font-semibold">{t("numberGroups.topPatterns")}</h3>
                  <ul className="space-y-1 text-sm">
                    {(sales?.top_patterns ?? []).map((p) => (
                      <li key={p.pattern} className="flex justify-between gap-2">
                        <span className="font-mono text-xs">{p.pattern}</span>
                        <span className="tabular-nums text-zinc-600">
                          {p.sold} · ${p.revenue}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
              <div className="overflow-hidden rounded-xl border bg-white">
                <div className="border-b px-4 py-3 text-sm font-semibold">
                  {t("numberGroups.soldHistory")}
                </div>
                <ul className="divide-y text-sm">
                  {(sales?.history ?? []).slice(0, 40).map((h) => (
                    <li key={h.payment_id} className="flex justify-between gap-3 px-4 py-2">
                      <div>
                        <p className="font-mono">{h.number ?? "—"}</p>
                        <p className="text-xs text-zinc-500">
                          {h.group_name ?? "—"}
                          {h.pattern ? ` · ${h.pattern}` : ""} · {formatDate(h.paid_at)}
                        </p>
                      </div>
                      <span className="tabular-nums">${h.amount}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </section>
          )}

          <section className="rounded-xl border bg-white p-4 shadow-sm">
            <h2 className="text-sm font-semibold">{t("numberGroups.simulator")}</h2>
            <p className="mt-1 text-xs text-zinc-500">{t("numberGroups.simulatorHint")}</p>
            <div className="mt-3 flex flex-wrap gap-2">
              <input
                value={simPattern}
                onChange={(e) => setSimPattern(e.target.value.toUpperCase())}
                placeholder="AAAAAAA / ABABABA / AAA****"
                className="min-w-[200px] flex-1 rounded border px-3 py-2 font-mono text-sm"
              />
              <button
                type="button"
                disabled={simBusy}
                onClick={() => void runSim()}
                className="rounded-lg bg-zinc-900 px-4 py-2 text-sm text-white disabled:opacity-50"
              >
                {t("numberGroups.preview")}
              </button>
            </div>
            {sim ? (
              <div className="mt-3">
                <p className="text-xs text-zinc-500">
                  {t("numberGroups.estSize")}: {sim.estimated_size ?? "—"}
                  {sim.truncated ? ` · ${t("numberGroups.truncated")}` : ""}
                </p>
                <div className="mt-2 flex flex-wrap gap-2">
                  {sim.preview.map((n) => (
                    <span
                      key={n}
                      className="rounded bg-zinc-100 px-2 py-1 font-mono text-xs tabular-nums"
                    >
                      {n}
                    </span>
                  ))}
                </div>
              </div>
            ) : null}
          </section>
        </div>

        <section className="rounded-xl border bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between gap-3">
            <h2 className="text-sm font-semibold">
              {editingId ? t("numberGroups.edit") : t("numberGroups.create")}
            </h2>
            {editingId ? (
              <button
                type="button"
                onClick={resetForm}
                className="text-xs font-medium text-zinc-500 hover:text-zinc-900"
              >
                {t("numberGroups.cancelEdit")}
              </button>
            ) : null}
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.name")}
              </label>
              <input
                required
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.price")}
              </label>
              <input
                type="number"
                min="0"
                step="0.01"
                required
                value={form.price}
                onChange={(e) => setForm({ ...form, price: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.patterns")}
              </label>
              <input
                required
                value={form.patterns}
                onChange={(e) => setForm({ ...form, patterns: e.target.value })}
                placeholder="AAAAAAA, ABABABA"
                className="mt-1 w-full rounded-lg border px-3 py-2 font-mono text-sm"
              />
              <p className="mt-1 text-xs text-zinc-500">{t("numberGroups.patternsHint")}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.bonusPlan")}
              </label>
              <input
                value={form.bonus_plan}
                onChange={(e) => setForm({ ...form, bonus_plan: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.priority")}
              </label>
              <input
                type="number"
                value={form.priority}
                onChange={(e) => setForm({ ...form, priority: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              />
            </div>

            <div className="space-y-2 rounded-lg border p-3">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">{t("numberGroups.dynamicPricing")}</span>
                <Toggle
                  checked={form.dynamic_pricing}
                  label={t("numberGroups.dynamicPricing")}
                  onChange={(checked) => setForm({ ...form, dynamic_pricing: checked })}
                />
              </div>
              {form.dynamic_pricing ? (
                <div className="grid grid-cols-2 gap-2 text-xs">
                  <label>
                    {t("numberGroups.soldTh")}
                    <input
                      value={form.sold_threshold}
                      onChange={(e) => setForm({ ...form, sold_threshold: e.target.value })}
                      className="mt-1 w-full rounded border px-2 py-1"
                    />
                  </label>
                  <label>
                    ×
                    <input
                      value={form.sold_multiplier}
                      onChange={(e) => setForm({ ...form, sold_multiplier: e.target.value })}
                      className="mt-1 w-full rounded border px-2 py-1"
                    />
                  </label>
                  <label>
                    {t("numberGroups.fillTh")}
                    <input
                      value={form.fill_threshold}
                      onChange={(e) => setForm({ ...form, fill_threshold: e.target.value })}
                      className="mt-1 w-full rounded border px-2 py-1"
                    />
                  </label>
                  <label>
                    ×
                    <input
                      value={form.fill_multiplier}
                      onChange={(e) => setForm({ ...form, fill_multiplier: e.target.value })}
                      className="mt-1 w-full rounded border px-2 py-1"
                    />
                  </label>
                  <label className="col-span-2">
                    {t("numberGroups.maxMult")}
                    <input
                      value={form.max_multiplier}
                      onChange={(e) => setForm({ ...form, max_multiplier: e.target.value })}
                      className="mt-1 w-full rounded border px-2 py-1"
                    />
                  </label>
                </div>
              ) : null}
            </div>

            <div className="flex items-center justify-between rounded-lg border px-3 py-2">
              <span className="text-sm font-medium text-zinc-700">{t("numberGroups.active")}</span>
              <Toggle
                checked={form.is_active}
                label={t("numberGroups.active")}
                onChange={(checked) => setForm({ ...form, is_active: checked })}
              />
            </div>

            <button
              type="submit"
              disabled={saving}
              className={cn(
                "w-full rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white",
                saving && "opacity-70",
              )}
            >
              {saving
                ? t("app.saving")
                : editingId
                  ? t("numberGroups.save")
                  : t("numberGroups.createBtn")}
            </button>
          </form>
        </section>
      </div>
    </div>
  );
}
