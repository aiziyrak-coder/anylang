"use client";

import { Toggle } from "@/components/ui/toggle";
import { Alert } from "@/components/admin/alert";
import { PageHeader } from "@/components/admin/page-header";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch } from "@/lib/api";
import { t } from "@/lib/i18n";
import type { NumberGroup } from "@/lib/types";
import { cn } from "@/lib/utils";
import { FormEvent, useEffect, useState } from "react";

type GroupFormState = {
  name: string;
  price: string;
  patterns: string;
  bonus_plan: string;
  priority: string;
  is_active: boolean;
};

const emptyForm = (): GroupFormState => ({
  name: "",
  price: "0",
  patterns: "",
  bonus_plan: "",
  priority: "0",
  is_active: true,
});

function formFromGroup(group: NumberGroup): GroupFormState {
  return {
    name: group.name,
    price: group.price,
    patterns: group.patterns.join(", "),
    bonus_plan: group.bonus_plan ?? "",
    priority: String(group.priority),
    is_active: group.is_active,
  };
}

export default function NumberGroupsPage() {
  const [groups, setGroups] = useState<NumberGroup[]>([]);
  const [form, setForm] = useState<GroupFormState>(emptyForm);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function loadGroups() {

    setLoading(true);
    setError(null);

    try {
      const data = await apiFetch<NumberGroup[]>("/api/v1/admin/number-groups");
      setGroups(data);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadGroups();
  }, []);

  function resetForm() {
    setForm(emptyForm());
    setEditingId(null);
    setSuccess(null);
  }

  function startEdit(group: NumberGroup) {
    setEditingId(group.id);
    setForm(formFromGroup(group));
    setSuccess(null);
    setError(null);
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
        setGroups((current) =>
          current.map((group) => (group.id === editingId ? updated : group)),
        );
        setSuccess(t("numberGroups.updated", { name: updated.name }));
      } else {
        const created = await apiFetch<NumberGroup>("/api/v1/admin/number-groups", {
          method: "POST",
          body: JSON.stringify(payload),
        });
        setGroups((current) => [created, ...current]);
        setSuccess(t("numberGroups.created", { name: created.name }));
        resetForm();
      }
    } catch (err) {
      if (err instanceof ApiError) setError(err.message);
      else if (err instanceof Error) setError(err.message);
      else setError(t("app.error"));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader title={t("numberGroups.title")} subtitle={t("numberGroups.subtitle")} />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <section className="overflow-hidden rounded-xl border bg-white shadow-sm">
          <div className="border-b px-4 py-3">
            <h2 className="text-sm font-semibold">{t("numberGroups.existing")}</h2>
          </div>

          {loading ? (
            <p className="px-4 py-8 text-sm text-zinc-500">{t("app.loading")}</p>
          ) : groups.length === 0 ? (
            <p className="px-4 py-8 text-sm text-zinc-500">{t("app.noData")}</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y text-sm">
                <thead className="bg-zinc-50">
                  <tr>
                    <th className="px-4 py-3 text-left font-medium text-zinc-600">
                      {t("numberGroups.colName")}
                    </th>
                    <th className="px-4 py-3 text-left font-medium text-zinc-600">
                      {t("numberGroups.colPrice")}
                    </th>
                    <th className="px-4 py-3 text-left font-medium text-zinc-600">
                      {t("numberGroups.colPatterns")}
                    </th>
                    <th className="px-4 py-3 text-left font-medium text-zinc-600">
                      {t("numberGroups.colPriority")}
                    </th>
                    <th className="px-4 py-3 text-left font-medium text-zinc-600">
                      {t("numberGroups.colActive")}
                    </th>
                    <th className="px-4 py-3" />
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {groups.map((group) => (
                    <tr key={group.id}>
                      <td className="px-4 py-3 font-medium">{group.name}</td>
                      <td className="px-4 py-3">
                        {group.currency} {group.price}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs">{group.patterns.join(", ")}</td>
                      <td className="px-4 py-3">{group.priority}</td>
                      <td className="px-4 py-3">
                        <StatusBadge status={group.is_active ? "active" : "inactive"} />
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          type="button"
                          onClick={() => startEdit(group)}
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

          {error ? <Alert variant="error" className="mb-4">{error}</Alert> : null}
          {success ? <Alert variant="success" className="mb-4">{success}</Alert> : null}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="name" className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.name")}
              </label>
              <input
                id="name"
                required
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm outline-none focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
              />
            </div>

            <div>
              <label htmlFor="price" className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.price")}
              </label>
              <input
                id="price"
                type="number"
                min="0"
                step="0.01"
                required
                value={form.price}
                onChange={(e) => setForm({ ...form, price: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm outline-none focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
              />
            </div>

            <div>
              <label htmlFor="patterns" className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.patterns")}
              </label>
              <input
                id="patterns"
                required
                value={form.patterns}
                onChange={(e) => setForm({ ...form, patterns: e.target.value })}
                placeholder="AAAA, AABB, ABAB"
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm outline-none focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
              />
              <p className="mt-1 text-xs text-zinc-500">{t("numberGroups.patternsHint")}</p>
            </div>

            <div>
              <label htmlFor="bonus_plan" className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.bonusPlan")}
              </label>
              <input
                id="bonus_plan"
                value={form.bonus_plan}
                onChange={(e) => setForm({ ...form, bonus_plan: e.target.value })}
                placeholder={t("numberGroups.bonusPlanHint")}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm outline-none focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
              />
            </div>

            <div>
              <label htmlFor="priority" className="block text-sm font-medium text-zinc-700">
                {t("numberGroups.priority")}
              </label>
              <input
                id="priority"
                type="number"
                value={form.priority}
                onChange={(e) => setForm({ ...form, priority: e.target.value })}
                className="mt-1 w-full rounded-lg border px-3 py-2 text-sm outline-none focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
              />
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
                "w-full rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-zinc-800",
                saving && "cursor-not-allowed opacity-70",
              )}
            >
              {saving ? t("app.saving") : editingId ? t("numberGroups.save") : t("numberGroups.createBtn")}
            </button>
          </form>
        </section>
      </div>
    </div>
  );
}
