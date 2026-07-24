document.getElementById("y").textContent = String(new Date().getFullYear());

(async function loadApkMeta() {
  const metaEl = document.getElementById("apk-meta");
  const link = document.getElementById("apk-download");
  if (!metaEl) return;

  try {
    const res = await fetch("/download/latest.json", { cache: "no-store" });
    if (!res.ok) throw new Error("meta " + res.status);
    const data = await res.json();
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
    metaEl.textContent = [ver ? `v${ver}` : null, mb, when ? `yangilangan: ${when}` : null]
      .filter(Boolean)
      .join(" · ");
    if (link && data.download_url) {
      link.href = data.download_url;
    }
  } catch (_) {
    metaEl.textContent =
      "Eng so‘nggi Android release · Play Market chiqquncha shu yerdan yangilang";
  }
})();
