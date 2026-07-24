document.getElementById("y").textContent = String(new Date().getFullYear());

const APK_HREF = "/download/anylang-latest.apk";

function applyApkMeta(data) {
  const metaEl = document.getElementById("apk-meta");
  const ver = data.version_full || data.version || "";
  const mb = data.size_mb != null ? `${data.size_mb} MB` : "";
  const when = data.updated_at
    ? new Date(data.updated_at).toLocaleString("uz-UZ", {
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : "";
  if (metaEl) {
    metaEl.textContent = [ver ? `v${ver}` : null, mb, when ? `yangilangan: ${when}` : null]
      .filter(Boolean)
      .join(" · ");
  }

  const href = data.download_url || APK_HREF;
  // cache-bust so browser always pulls the newest binary when meta changes
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
      metaEl.textContent =
        "Eng so‘nggi Android release · Play Market chiqquncha shu yerdan yangilang";
    }
  }
})();

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
          locale: (navigator.language || "uz").slice(0, 16),
        }),
      });
      const data = await res.json().catch(() => ({}));
      setTyping(false);
      if (!res.ok) {
        const err =
          (data && (data.message || data.detail || data.error)) ||
          "Hozircha javob bera olmadim. Keyinroq urinib ko‘ring.";
        const text = typeof err === "string" ? err : "Xatolik yuz berdi";
        addBubble("assistant", text);
        return;
      }
      const reply = (data.reply || "").trim() || "…";
      addBubble("assistant", reply);
      history.push({ role: "assistant", content: reply });
    } catch (_) {
      setTyping(false);
      addBubble(
        "assistant",
        "Ulanishda muammo. Internetni tekshirib, qayta yozing."
      );
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
