"use client";

import { ApiError, apiFetch } from "@/lib/api";
import { useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

export type AdminListResponse<T> = {
  items: T[];
  page: number;
  limit: number;
  total: number;
  has_more: boolean;
};

export type SortOrder = "asc" | "desc";

type Filters = Record<string, string | number | boolean | null | undefined>;

type Options<TFilters extends Filters> = {
  queryKey: string;
  path: string;
  /** Search param name sent to API (default: "q"; users/products use "search") */
  searchParam?: string;
  defaultLimit?: number;
  defaultSort?: string;
  defaultOrder?: SortOrder;
  debounceMs?: number;
  enabled?: boolean;
  /** Sync page/q/filters/sort/limit to URL query string */
  syncUrl?: boolean;
  /** Extra static query params always sent */
  extraParams?: Record<string, string>;
  /** Initial filter values (also used when clearing) */
  initialFilters?: TFilters;
  /** Filter keys that reset page when changed */
  filterKeys?: (keyof TFilters)[];
};

function parsePositiveInt(value: string | null, fallback: number): number {
  if (!value) return fallback;
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export function useAdminList<TItem, TFilters extends Filters = Filters>(
  options: Options<TFilters>,
) {
  const {
    queryKey,
    path,
    searchParam = "q",
    defaultLimit = 50,
    defaultSort,
    defaultOrder = "desc",
    debounceMs = 250,
    enabled = true,
    syncUrl = true,
    extraParams,
    initialFilters,
  } = options;

  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const initialFromUrl = useMemo(() => {
    if (!syncUrl) {
      return {
        page: 1,
        limit: defaultLimit,
        q: "",
        sort: defaultSort ?? "",
        order: defaultOrder,
        filters: { ...(initialFilters ?? ({} as TFilters)) },
      };
    }
    const filters = { ...(initialFilters ?? ({} as TFilters)) };
    for (const key of Object.keys(filters) as (keyof TFilters)[]) {
      const raw = searchParams.get(String(key));
      if (raw !== null) {
        (filters as Filters)[String(key)] = raw;
      }
    }
    return {
      page: parsePositiveInt(searchParams.get("page"), 1),
      limit: parsePositiveInt(searchParams.get("limit"), defaultLimit),
      q: searchParams.get("q") ?? searchParams.get("search") ?? "",
      sort: searchParams.get("sort") ?? defaultSort ?? "",
      order: (searchParams.get("order") as SortOrder) || defaultOrder,
      filters,
    };
    // Only hydrate once from URL on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [page, setPage] = useState(initialFromUrl.page);
  const [limit, setLimit] = useState(initialFromUrl.limit);
  const [q, setQ] = useState(initialFromUrl.q);
  const [debouncedQ, setDebouncedQ] = useState(initialFromUrl.q);
  const [sort, setSort] = useState(initialFromUrl.sort);
  const [order, setOrder] = useState<SortOrder>(initialFromUrl.order);
  const [filters, setFilters] = useState<TFilters>(initialFromUrl.filters);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQ(q), debounceMs);
    return () => clearTimeout(timer);
  }, [q, debounceMs]);

  useEffect(() => {
    if (!syncUrl) return;
    const params = new URLSearchParams();
    if (page > 1) params.set("page", String(page));
    if (limit !== defaultLimit) params.set("limit", String(limit));
    if (debouncedQ.trim()) params.set("q", debouncedQ.trim());
    if (sort) {
      params.set("sort", sort);
      params.set("order", order);
    }
    for (const [key, value] of Object.entries(filters)) {
      if (value === undefined || value === null || value === "") continue;
      if (String(value) === String((initialFilters as Filters | undefined)?.[key] ?? "")) {
        // keep intentional defaults like status=all out of URL when matching initial
        if (String(value) === "all" || value === false) continue;
      }
      params.set(key, String(value));
    }
    const qs = params.toString();
    const next = qs ? `${pathname}?${qs}` : pathname;
    router.replace(next, { scroll: false });
  }, [
    syncUrl,
    page,
    limit,
    debouncedQ,
    sort,
    order,
    filters,
    pathname,
    router,
    defaultLimit,
    initialFilters,
  ]);

  const buildParams = useCallback(() => {
    const params = new URLSearchParams();
    params.set("page", String(page));
    params.set("limit", String(limit));
    if (debouncedQ.trim()) {
      params.set(searchParam, debouncedQ.trim());
    }
    if (sort) {
      params.set("sort", sort);
      params.set("order", order);
    }
    for (const [key, value] of Object.entries(filters)) {
      if (value === undefined || value === null || value === "") continue;
      params.set(key, String(value));
    }
    if (extraParams) {
      for (const [key, value] of Object.entries(extraParams)) {
        if (value) params.set(key, value);
      }
    }
    return params;
  }, [page, limit, debouncedQ, sort, order, filters, searchParam, extraParams]);

  const query = useQuery({
    queryKey: [queryKey, page, limit, debouncedQ, sort, order, filters, extraParams],
    enabled,
    queryFn: async (): Promise<AdminListResponse<TItem>> => {
      const params = buildParams();
      return apiFetch<AdminListResponse<TItem>>(`${path}?${params}`);
    },
  });

  const setFilter = useCallback(<K extends keyof TFilters>(key: K, value: TFilters[K]) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    setPage(1);
  }, []);

  const setFiltersPatch = useCallback((patch: Partial<TFilters>) => {
    setFilters((prev) => ({ ...prev, ...patch }));
    setPage(1);
  }, []);

  const clearFilters = useCallback(() => {
    setFilters({ ...(initialFilters ?? ({} as TFilters)) });
    setQ("");
    setDebouncedQ("");
    setSort(defaultSort ?? "");
    setOrder(defaultOrder);
    setPage(1);
  }, [initialFilters, defaultSort, defaultOrder]);

  const toggleSort = useCallback(
    (key: string) => {
      setPage(1);
      if (sort === key) {
        setOrder((prev) => (prev === "asc" ? "desc" : "asc"));
      } else {
        setSort(key);
        setOrder("desc");
      }
    },
    [sort],
  );

  const onLimitChange = useCallback((next: number) => {
    setLimit(next);
    setPage(1);
  }, []);

  const errorMessage =
    query.error instanceof ApiError
      ? query.error.message
      : query.error
        ? String(query.error)
        : null;

  const hasActiveFilters =
    Boolean(debouncedQ.trim()) ||
    Object.entries(filters).some(([key, value]) => {
      const initial = (initialFilters as Filters | undefined)?.[key];
      return String(value ?? "") !== String(initial ?? "");
    });

  return {
    items: query.data?.items ?? [],
    page: query.data?.page ?? page,
    limit: query.data?.limit ?? limit,
    total: query.data?.total ?? 0,
    hasMore: query.data?.has_more ?? false,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    isError: query.isError,
    error: errorMessage,
    refetch: query.refetch,
    q,
    setQ: (value: string) => {
      setQ(value);
      setPage(1);
    },
    filters,
    setFilter,
    setFiltersPatch,
    clearFilters,
    hasActiveFilters,
    sort: sort || null,
    order,
    toggleSort,
    setPage,
    setLimit: onLimitChange,
  };
}
