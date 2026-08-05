"use client";

import {
  getLocale,
  initLocaleFromStorage,
  setLocale,
  subscribeLocale,
  type Locale,
} from "@/lib/i18n";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

type LocaleCtx = {
  locale: Locale;
  setLocale: (l: Locale) => void;
};

const Ctx = createContext<LocaleCtx>({ locale: "uz", setLocale: () => undefined });

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLoc] = useState<Locale>("uz");

  useEffect(() => {
    setLoc(initLocaleFromStorage());
    return subscribeLocale(() => setLoc(getLocale()));
  }, []);

  const change = useCallback((l: Locale) => {
    setLocale(l);
    setLoc(l);
  }, []);

  const value = useMemo(() => ({ locale, setLocale: change }), [locale, change]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useLocale() {
  return useContext(Ctx);
}

/** Force re-render when locale changes (for t() consumers). */
export function useI18nTick(): Locale {
  const { locale } = useLocale();
  return locale;
}
