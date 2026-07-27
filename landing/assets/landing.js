document.getElementById("y").textContent = String(new Date().getFullYear());

const APK_HREF = "/download/anylang-latest.apk";
const LANG_KEY = "anylang_lang";
const SUPPORTED = ["en", "uz", "ru"];

/** @type {Record<string, Record<string, string>>} */
const I18N = {
  en: {
    page_title: "AnyLang — Speak any language. Do business anywhere.",
    page_desc:
      "AnyLang is global B2B messaging with live translation. Write or speak in your language — partners understand in theirs.",
    nav_product: "Product",
    nav_how: "How",
    nav_support: "Support",
    nav_download: "Download",
    nav_cta: "Download",
    hero_line: "Speak any language. Do business anywhere.",
    hero_sub:
      "Live translation for global B2B — write or speak in your language; partners read and hear in theirs.",
    cta_download: "Download Android APK",
    cta_download_short: "Get AnyLang",
    apk_meta_fallback: "Latest release · until Play Store",
    apk_updated: "updated",
    demo_chat_title: "Trade chat",
    demo_src_1: "You · Uzbek",
    demo_src_2: "Partner · English",
    demo_out_1: "Narxni yuboring, iltimos.",
    demo_in_1: "Please send the price.",
    demo_out_2: "Yetkazib berish 3 kun.",
    demo_in_2: "Delivery in 3 days.",
    demo_flip: "Live translate",
    proof_1: "Live text & voice",
    proof_2: "Global B2B chat",
    proof_3: "7-digit AnyLang ID",
    product_title: "Trade opens across languages",
    product_body:
      "Every message arrives in two layers — original and yours. Voice becomes text. Jonli mode lets you speak live. Your shop and trust score travel with you worldwide.",
    rail_1_title: "Live translation",
    rail_1_body: "Text and voice, both ways",
    rail_2_title: "AnyLang number",
    rail_2_body: "Find anyone without a phone number",
    rail_3_title: "Business open",
    rail_3_body: "Products, trust, AI matching",
    how_title: "Three steps. Unlimited trade.",
    how_1_title: "Install",
    how_1_body: "Get the latest Android APK from this site.",
    how_2_title: "Choose your language",
    how_2_body: "Everything arrives in the language you speak.",
    how_3_title: "Start trading",
    how_3_body: "Write or speak — close deals worldwide.",
    support_title: "Ask Sofiya",
    support_body:
      "AnyLang support assistant — APK, install, features. Right here on the site.",
    support_agent: "Sofiya",
    support_status: "AnyLang · support",
    support_welcome:
      "Hi! I’m Sofiya — AnyLang support. Ask about the APK, install, or the app.",
    support_placeholder: "Write a message…",
    support_error:
      "I couldn’t reply right now. Please try again in a moment.",
    support_offline:
      "Connection issue. Check your internet and try again.",
    close_title: "Ready when you are",
    close_body:
      "Until Play Store and App Store — grab the release APK here and stay updated.",
    close_soon: "Google Play & App Store — coming soon",
    footer_tag: "Speak any language. Do business anywhere.",
  },
  uz: {
    page_title:
      "AnyLang — Har qanday tilda gaplashing. Dunyoning istalgan nuqtasida biznes qiling.",
    page_desc:
      "AnyLang — global B2B: jonli tarjima bilan xabarlar. O‘z tilingizda yozing yoki gapiring — sherik o‘z tilida tushunadi.",
    nav_product: "Mahsulot",
    nav_how: "Qanday",
    nav_support: "Yordam",
    nav_download: "Yuklash",
    nav_cta: "Yuklash",
    hero_line:
      "Har qanday tilda gaplashing. Dunyoning istalgan nuqtasida biznes qiling.",
    hero_sub:
      "Global B2B uchun jonli tarjima — o‘z tilingizda yozing yoki gapiring; sherik o‘zinikida o‘qiydi va eshitadi.",
    cta_download: "Android APK yuklash",
    cta_download_short: "AnyLang yuklab olish",
    apk_meta_fallback: "Eng so‘nggi release · Play Market chiqquncha",
    apk_updated: "yangilangan",
    demo_chat_title: "Savdo chat",
    demo_src_1: "Siz · O‘zbek",
    demo_src_2: "Sherik · English",
    demo_out_1: "Narxni yuboring, iltimos.",
    demo_in_1: "Please send the price.",
    demo_out_2: "Yetkazib berish 3 kun.",
    demo_in_2: "Delivery in 3 days.",
    demo_flip: "Jonli tarjima",
    proof_1: "Jonli matn va ovoz",
    proof_2: "Global B2B chat",
    proof_3: "7 xonali AnyLang ID",
    product_title: "Tillar oralig‘ida savdo ochiladi",
    product_body:
      "Har xabar ikki qatlamda — asl matn va sizning tilingiz. Ovoz matnga aylanadi. Jonli rejimda gaplashing. Do‘kon va ishonchingiz dunyo bo‘ylab siz bilan.",
    rail_1_title: "Jonli tarjima",
    rail_1_body: "Matn va ovoz — ikki tomonga",
    rail_2_title: "AnyLang raqami",
    rail_2_body: "Telefon raqamisiz topiling",
    rail_3_title: "Biznes ochiq",
    rail_3_body: "Mahsulotlar, ishonch, AI matching",
    how_title: "Uch qadam. Cheksiz biznes.",
    how_1_title: "O‘rnating",
    how_1_body: "Saytdan eng so‘nggi Android APK.",
    how_2_title: "Tilni tanlang",
    how_2_body: "Barcha xabarlar ona tilingizga keladi.",
    how_3_title: "Savdo boshlang",
    how_3_body: "Yozing yoki gapiring — dunyo bilan bitim.",
    support_title: "Sofiyadan so‘rang",
    support_body:
      "AnyLang yordamchisi — APK, o‘rnatish, imkoniyatlar. Shu yerda.",
    support_agent: "Sofiya",
    support_status: "AnyLang · qo‘llab-quvvatlash",
    support_welcome:
      "Salom! Men Sofiya — AnyLang yordamchisiman. APK, o‘rnatish yoki ilova haqida so‘rang.",
    support_placeholder: "Xabar yozing…",
    support_error:
      "Hozircha javob bera olmadim. Keyinroq urinib ko‘ring.",
    support_offline:
      "Ulanishda muammo. Internetni tekshirib, qayta yozing.",
    close_title: "Tayyor bo‘lsangiz",
    close_body:
      "Play Market va App Store chiqquncha release APK shu yerdan. Yangilang.",
    close_soon: "Google Play va App Store — tez orada",
    footer_tag:
      "Har qanday tilda gaplashing. Dunyoning istalgan nuqtasida biznes qiling.",
  },
  ru: {
    page_title: "AnyLang — Говорите на любом языке. Ведите бизнес где угодно.",
    page_desc:
      "AnyLang — глобальный B2B-мессенджер с живым переводом. Пишите или говорите на своём языке — партнёр понимает на своём.",
    nav_product: "Продукт",
    nav_how: "Как",
    nav_support: "Поддержка",
    nav_download: "Скачать",
    nav_cta: "Скачать",
    hero_line: "Говорите на любом языке. Ведите бизнес где угодно.",
    hero_sub:
      "Живой перевод для глобального B2B — пишите или говорите на своём языке; партнёр читает и слышит на своём.",
    cta_download: "Скачать Android APK",
    cta_download_short: "Скачать AnyLang",
    apk_meta_fallback: "Последний релиз · пока нет Play Store",
    apk_updated: "обновлено",
    demo_chat_title: "Сделка",
    demo_src_1: "Вы · Узбекский",
    demo_src_2: "Партнёр · English",
    demo_out_1: "Narxni yuboring, iltimos.",
    demo_in_1: "Please send the price.",
    demo_out_2: "Yetkazib berish 3 kun.",
    demo_in_2: "Delivery in 3 days.",
    demo_flip: "Живой перевод",
    proof_1: "Текст и голос",
    proof_2: "Глобальный B2B-чат",
    proof_3: "7-значный ID AnyLang",
    product_title: "Торговля без языкового барьера",
    product_body:
      "Каждое сообщение в двух слоях — оригинал и ваш язык. Голос становится текстом. Режим Jonli — живой разговор. Магазин и доверие едут с вами по миру.",
    rail_1_title: "Живой перевод",
    rail_1_body: "Текст и голос в обе стороны",
    rail_2_title: "Номер AnyLang",
    rail_2_body: "Находите без номера телефона",
    rail_3_title: "Бизнес открыт",
    rail_3_body: "Товары, доверие, AI matching",
    how_title: "Три шага. Безграничная торговля.",
    how_1_title: "Установите",
    how_1_body: "Скачайте свежий Android APK с сайта.",
    how_2_title: "Выберите язык",
    how_2_body: "Все сообщения приходят на вашем языке.",
    how_3_title: "Начните сделки",
    how_3_body: "Пишите или говорите — заключайте сделки по миру.",
    support_title: "Спросите Софию",
    support_body:
      "Помощник AnyLang — APK, установка, функции. Прямо на сайте.",
    support_agent: "София",
    support_status: "AnyLang · поддержка",
    support_welcome:
      "Привет! Я София — поддержка AnyLang. Спросите про APK, установку или приложение.",
    support_placeholder: "Напишите сообщение…",
    support_error: "Сейчас не удалось ответить. Попробуйте чуть позже.",
    support_offline:
      "Проблема со связью. Проверьте интернет и напишите снова.",
    close_title: "Когда будете готовы",
    close_body:
      "Пока нет Play Store и App Store — берите релизный APK здесь и обновляйтесь.",
    close_soon: "Google Play и App Store — скоро",
    footer_tag: "Говорите на любом языке. Ведите бизнес где угодно.",
  },
};

let currentLang = "en";
/** @type {Record<string, unknown> | null} */
let lastApkMeta = null;

function t(key) {
  return (I18N[currentLang] && I18N[currentLang][key]) || I18N.en[key] || key;
}

function resolveLang() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = (params.get("lang") || "").toLowerCase();
  if (SUPPORTED.includes(fromQuery)) return fromQuery;
  try {
    const saved = (localStorage.getItem(LANG_KEY) || "").toLowerCase();
    if (SUPPORTED.includes(saved)) return saved;
  } catch (_) {}
  return "en";
}

function setLang(code) {
  const lang = SUPPORTED.includes(code) ? code : "en";
  currentLang = lang;
  try {
    localStorage.setItem(LANG_KEY, lang);
  } catch (_) {}

  document.documentElement.lang = lang === "uz" ? "uz" : lang;

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.getAttribute("data-i18n");
    if (!key) return;
    el.textContent = t(key);
  });

  document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
    const key = el.getAttribute("data-i18n-placeholder");
    if (!key) return;
    el.setAttribute("placeholder", t(key));
  });

  document.title = t("page_title");
  const desc = document.querySelector('meta[name="description"]');
  if (desc) desc.setAttribute("content", t("page_desc"));
  const ogTitle = document.querySelector('meta[property="og:title"]');
  if (ogTitle) ogTitle.setAttribute("content", t("page_title"));
  const ogDesc = document.querySelector('meta[property="og:description"]');
  if (ogDesc) ogDesc.setAttribute("content", t("page_desc"));

  document.querySelectorAll(".lang-btn").forEach((btn) => {
    const active = btn.getAttribute("data-lang") === lang;
    btn.classList.toggle("is-active", active);
    btn.setAttribute("aria-pressed", active ? "true" : "false");
  });

  if (lastApkMeta) applyApkMeta(lastApkMeta);
  else {
    const metaEl = document.getElementById("apk-meta");
    if (metaEl && !metaEl.dataset.fromMeta) {
      metaEl.textContent = t("apk_meta_fallback");
    }
  }
}

function localeTag() {
  if (currentLang === "uz") return "uz-UZ";
  if (currentLang === "ru") return "ru-RU";
  return "en-US";
}

function applyApkMeta(data) {
  lastApkMeta = data;
  const metaEl = document.getElementById("apk-meta");
  const ver = data.version_full || data.version || "";
  const mb = data.size_mb != null ? `${data.size_mb} MB` : "";
  const when = data.updated_at
    ? new Date(data.updated_at).toLocaleString(localeTag(), {
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : "";
  if (metaEl) {
    metaEl.dataset.fromMeta = "1";
    metaEl.textContent = [
      ver ? `v${ver}` : null,
      mb,
      when ? `${t("apk_updated")}: ${when}` : null,
    ]
      .filter(Boolean)
      .join(" · ");
  }

  const href = data.download_url || APK_HREF;
  const bust = data.version_full || data.build || Date.now();
  const finalHref = href.includes("?") ? `${href}&v=${bust}` : `${href}?v=${bust}`;

  document.querySelectorAll("a.apk-link, #apk-download").forEach((a) => {
    a.setAttribute("href", finalHref);
    a.setAttribute("download", "AnyLang.apk");
  });
}

(async function loadApkMeta() {
  const metaEl = document.getElementById("apk-meta");
  try {
    const res = await fetch("/download/latest.json", { cache: "no-store" });
    if (!res.ok) throw new Error("meta " + res.status);
    applyApkMeta(await res.json());
  } catch (_) {
    if (metaEl) {
      metaEl.textContent = t("apk_meta_fallback");
    }
  }
})();

document.querySelectorAll(".lang-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    const code = btn.getAttribute("data-lang");
    if (code) setLang(code);
  });
});

setLang(resolveLang());

/* —— Landing support chat (Sofiya) —— */
(function initSupportChat() {
  const thread = document.getElementById("support-thread");
  const form = document.getElementById("support-form");
  const input = document.getElementById("support-input");
  const sendBtn = document.getElementById("support-send");
  if (!thread || !form || !input || !sendBtn) return;

  /** @type {{role: string, content: string}[]} */
  const history = [];
  let busy = false;

  function scrollBottom() {
    thread.scrollTop = thread.scrollHeight;
  }

  function addBubble(role, text) {
    const el = document.createElement("div");
    el.className = `msg ${role === "user" ? "out" : "in"}`;
    const dst = document.createElement("span");
    dst.className = "msg-dst";
    dst.textContent = text;
    el.appendChild(dst);
    thread.appendChild(el);
    scrollBottom();
    return el;
  }

  function setTyping(on) {
    const id = "support-typing";
    const existing = document.getElementById(id);
    if (!on) {
      if (existing) existing.remove();
      return;
    }
    if (existing) return;
    const el = document.createElement("div");
    el.className = "msg in typing";
    el.id = id;
    el.innerHTML = '<span class="msg-dst"><i></i><i></i><i></i></span>';
    thread.appendChild(el);
    scrollBottom();
  }

  function setBusy(v) {
    busy = v;
    input.disabled = v;
    sendBtn.disabled = v;
    sendBtn.classList.toggle("is-busy", v);
  }

  async function sendMessage(raw) {
    const message = (raw || "").trim();
    if (!message || busy) return;

    addBubble("user", message);
    history.push({ role: "user", content: message });
    input.value = "";
    setBusy(true);
    setTyping(true);

    try {
      const res = await fetch("/api/v1/support/public", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          message,
          history: history.slice(0, -1).slice(-20),
          locale: currentLang,
        }),
      });
      const data = await res.json().catch(() => ({}));
      setTyping(false);
      if (!res.ok) {
        const err =
          (data && (data.message || data.detail || data.error)) ||
          t("support_error");
        const text = typeof err === "string" ? err : t("support_error");
        addBubble("assistant", text);
        return;
      }
      const reply = (data.reply || "").trim() || "…";
      addBubble("assistant", reply);
      history.push({ role: "assistant", content: reply });
    } catch (_) {
      setTyping(false);
      addBubble("assistant", t("support_offline"));
    } finally {
      setBusy(false);
      input.focus();
    }
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    sendMessage(input.value);
  });
})();
