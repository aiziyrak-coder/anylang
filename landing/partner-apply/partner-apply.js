(function () {
  const API = "/api/v1/partner-applications";
  const STORE_KEY = "anylang_partner_apply_v1";

  const i18n = {
    uz: {
      title: "Biznes anketa",
      subtitle:
        "Hamkorlar uchun — login yarating, biznes va mahsulotlarni to‘ldiring, yuboring. Admin tasdiqlagach akkount ochiladi.",
      auto_translate_note:
        "Bitta tilda to‘ldiring — AnyLang mahsulot va biznes matnlarini barcha tillarga avtomatik tarjima qiladi.",
      step1: "1. Kirish",
      step2: "2. Biznes",
      step3: "3. Mahsulotlar",
      step4: "4. Yuborish",
      s1_title: "Kirish ma’lumotlari",
      s1_hint: "Shu email va parol bilan keyin ilovaga kirasiz. Email tasdiqlash shart emas.",
      s2_title: "Biznes haqida",
      s2_hint: "Kompaniya ma’lumotlari, logo, zavod rasmlari va video.",
      s3_title: "Mahsulotlar",
      s3_hint: "Nechta mahsulotingiz bo‘lsa — hammasini qo‘shing. Narx, rasm va video.",
      s4_title: "Tekshirish va yuborish",
      s4_hint: "Ma’lumotlar to‘g‘riligini ko‘rib chiqing. Yuborgach admin tasdiqlaydi.",
      contact_name: "Ism / aloqa shaxsi",
      phone: "Telefon",
      email: "Email (kirish uchun)",
      email_check: "Email holati",
      password: "Parol",
      password2: "Parolni takrorlang",
      pass_hint: "Kamida 8 belgi, harf va raqam bo‘lishi shart.",
      company: "Kompaniya nomi",
      country: "Davlat kodi",
      role: "Biznes turi",
      website: "Veb-sayt",
      founded: "Tashkil topgan yil",
      moq: "Minimal buyurtma (MOQ)",
      capacity: "Ishlab chiqarish quvvati",
      lead: "Yetkazish muddati",
      bio: "Qisqa bio",
      description: "To‘liq tavsif",
      export: "Eksport davlatlari",
      export_hint: "Keraklilarini bosing (bir nechtasini tanlash mumkin)",
      certs: "Sertifikatlar",
      certs_hint: "Mavjud sertifikatlarni belgilang",
      logo_hint: "Kompaniya logotipi (JPG/PNG, eng ko‘pi 5 MB)",
      factory_img_hint: "Zavod / ombor rasmlari (bir nechta)",
      factory_vid_hint: "Zavod videosi (MP4/MOV, eng ko‘pi 25 MB)",
      pick_image: "Rasm tanlash",
      pick_images: "Rasmlar",
      pick_video: "Video tanlash",
      add_product: "+ Mahsulot qo‘shish",
      product: "Mahsulot",
      remove: "O‘chirish",
      p_name: "Nomi",
      p_price: "Narx",
      p_currency: "Valyuta",
      p_category: "Kategoriya",
      p_short: "Qisqa tavsif",
      p_desc: "Tavsif",
      p_moq: "Minimal buyurtma",
      p_ship: "Yetkazib berish",
      p_images: "Mahsulot rasmlari",
      p_video: "Mahsulot videosi",
      next: "Keyingi",
      back: "Orqaga",
      submit: "Anketani yuborish",
      submitting: "Yuborilmoqda…",
      uploading: "Yuklanmoqda…",
      ok_title: "Anketa yuborildi",
      ok_text:
        "Admin tekshirib tasdiqlagach, kiritgan email/parolingiz bilan AnyLang ilovasiga kira olasiz.",
      home: "Bosh sahifa",
      email_ok: "Email bo‘sh — ishlatish mumkin",
      email_bad: "Email band yoki noto‘g‘ri",
      err_pass: "Parollar mos emas",
      err_pass_weak: "Parolda harf va raqam bo‘lishi kerak (kamida 8 belgi)",
      err_email: "Emailni to‘g‘ri kiriting",
      err_contact: "Ismni kiriting",
      err_company: "Kompaniya nomini kiriting",
      err_country: "Davlat kodini kiriting (masalan UZ)",
      err_products: "Kamida bitta mahsulot qo‘shing",
      err_pname: "Har bir mahsulotga nom va narx kiriting",
      review_account: "Akkount",
      review_business: "Biznes",
      review_products: "Mahsulotlar",
      role_manufacturer: "Ishlab chiqaruvchi",
      role_distributor: "Distribyutor",
      role_retail: "Chakana savdo",
      role_service: "Xizmat ko‘rsatish",
      cat_clothing: "Kiyim va aksessuarlar",
      cat_pottery: "Sopol / kulolchilik",
      cat_woodwork: "Yog‘och buyumlar",
      cat_jewelry: "Zargarlik",
      cat_other: "Boshqa",
      ph_website: "https://",
      ph_founded: "masalan 2015",
      ph_moq: "masalan 100 dona",
      ph_capacity: "masalan oyiga 10 000 dona",
      ph_lead: "7–14 kun",
      review_logo: "logo",
      review_factory_imgs: "zavod rasmlari",
      review_video: "video",
      review_imgs: "rasm",
      review_export: "Eksport",
      review_certs: "Sertifikatlar",
    },
    ru: {
      title: "Бизнес-анкета",
      subtitle:
        "Для партнёров — создайте логин, заполните бизнес и товары, отправьте. После одобрения админа аккаунт откроется.",
      auto_translate_note:
        "Заполните на одном языке — AnyLang автоматически переведёт тексты бизнеса и товаров на все языки.",
      step1: "1. Вход",
      step2: "2. Бизнес",
      step3: "3. Товары",
      step4: "4. Отправка",
      s1_title: "Данные для входа",
      s1_hint: "Этим email и паролем вы войдёте в приложение. Подтверждение почты не нужно.",
      s2_title: "О бизнесе",
      s2_hint: "Данные компании, логотип, фото и видео производства.",
      s3_title: "Товары",
      s3_hint: "Добавьте все товары: цена, фото и видео.",
      s4_title: "Проверка и отправка",
      s4_hint: "Проверьте данные. После отправки админ проверит анкету.",
      contact_name: "Имя / контакт",
      phone: "Телефон",
      email: "Email (для входа)",
      email_check: "Статус email",
      password: "Пароль",
      password2: "Повторите пароль",
      pass_hint: "Минимум 8 символов, буква и цифра.",
      company: "Название компании",
      country: "Код страны",
      role: "Тип бизнеса",
      website: "Сайт",
      founded: "Год основания",
      moq: "Минимальный заказ (MOQ)",
      capacity: "Производственная мощность",
      lead: "Срок поставки",
      bio: "Краткое описание",
      description: "Полное описание",
      export: "Страны экспорта",
      export_hint: "Нажмите нужные (можно выбрать несколько)",
      certs: "Сертификаты",
      certs_hint: "Отметьте имеющиеся сертификаты",
      logo_hint: "Логотип компании (JPG/PNG, до 5 МБ)",
      factory_img_hint: "Фото завода / склада (несколько)",
      factory_vid_hint: "Видео завода (MP4/MOV, до 25 МБ)",
      pick_image: "Выбрать фото",
      pick_images: "Фото",
      pick_video: "Выбрать видео",
      add_product: "+ Добавить товар",
      product: "Товар",
      remove: "Удалить",
      p_name: "Название",
      p_price: "Цена",
      p_currency: "Валюта",
      p_category: "Категория",
      p_short: "Краткое описание",
      p_desc: "Описание",
      p_moq: "Минимальный заказ",
      p_ship: "Доставка",
      p_images: "Фото товара",
      p_video: "Видео товара",
      next: "Далее",
      back: "Назад",
      submit: "Отправить анкету",
      submitting: "Отправка…",
      uploading: "Загрузка…",
      ok_title: "Анкета отправлена",
      ok_text:
        "После проверки админом вы сможете войти в приложение с указанным email и паролем.",
      home: "На главную",
      email_ok: "Email свободен — можно использовать",
      email_bad: "Email занят или некорректен",
      err_pass: "Пароли не совпадают",
      err_pass_weak: "Нужны буква и цифра (мин. 8)",
      err_email: "Введите корректный email",
      err_contact: "Введите имя",
      err_company: "Введите название компании",
      err_country: "Введите код страны (например UZ)",
      err_products: "Добавьте хотя бы один товар",
      err_pname: "У каждого товара нужны название и цена",
      review_account: "Аккаунт",
      review_business: "Бизнес",
      review_products: "Товары",
      role_manufacturer: "Производитель",
      role_distributor: "Дистрибьютор",
      role_retail: "Розничная торговля",
      role_service: "Услуги",
      cat_clothing: "Одежда и аксессуары",
      cat_pottery: "Керамика",
      cat_woodwork: "Изделия из дерева",
      cat_jewelry: "Ювелирные изделия",
      cat_other: "Другое",
      ph_website: "https://",
      ph_founded: "например 2015",
      ph_moq: "например 100 шт",
      ph_capacity: "например 10 000 шт в месяц",
      ph_lead: "7–14 дней",
      review_logo: "логотип",
      review_factory_imgs: "фото завода",
      review_video: "видео",
      review_imgs: "фото",
      review_export: "Экспорт",
      review_certs: "Сертификаты",
    },
    en: {
      title: "Business application",
      subtitle:
        "For partners — create a login, add your business and products, submit. Your account opens after admin approval.",
      auto_translate_note:
        "Fill in one language — AnyLang automatically translates your business and product texts into all languages.",
      step1: "1. Sign in",
      step2: "2. Business",
      step3: "3. Products",
      step4: "4. Submit",
      s1_title: "Sign-in details",
      s1_hint: "You will use this email and password in the app. No email verification needed.",
      s2_title: "About the business",
      s2_hint: "Company info, logo, factory photos and video.",
      s3_title: "Products",
      s3_hint: "Add all products with price, images and video.",
      s4_title: "Review & submit",
      s4_hint: "Check everything. After submit, admin will review.",
      contact_name: "Contact name",
      phone: "Phone",
      email: "Email (for login)",
      email_check: "Email status",
      password: "Password",
      password2: "Confirm password",
      pass_hint: "At least 8 characters, one letter and one digit.",
      company: "Company name",
      country: "Country code",
      role: "Business type",
      website: "Website",
      founded: "Founded year",
      moq: "Minimum order (MOQ)",
      capacity: "Production capacity",
      lead: "Lead time",
      bio: "Short bio",
      description: "Full description",
      export: "Export countries",
      export_hint: "Tap to select (you can choose several)",
      certs: "Certificates",
      certs_hint: "Select the certificates you have",
      logo_hint: "Company logo (JPG/PNG, max 5 MB)",
      factory_img_hint: "Factory / warehouse photos (multiple)",
      factory_vid_hint: "Factory video (MP4/MOV, max 25 MB)",
      pick_image: "Pick image",
      pick_images: "Images",
      pick_video: "Pick video",
      add_product: "+ Add product",
      product: "Product",
      remove: "Remove",
      p_name: "Name",
      p_price: "Price",
      p_currency: "Currency",
      p_category: "Category",
      p_short: "Short description",
      p_desc: "Description",
      p_moq: "Minimum order",
      p_ship: "Shipping",
      p_images: "Product images",
      p_video: "Product video",
      next: "Next",
      back: "Back",
      submit: "Submit application",
      submitting: "Submitting…",
      uploading: "Uploading…",
      ok_title: "Application submitted",
      ok_text:
        "After admin approval you can sign in to AnyLang with the email and password you entered.",
      home: "Home",
      email_ok: "Email available",
      email_bad: "Email taken or invalid",
      err_pass: "Passwords do not match",
      err_pass_weak: "Need a letter and a digit (min 8)",
      err_email: "Enter a valid email",
      err_contact: "Enter contact name",
      err_company: "Enter company name",
      err_country: "Enter country code (e.g. UZ)",
      err_products: "Add at least one product",
      err_pname: "Each product needs a name and price",
      review_account: "Account",
      review_business: "Business",
      review_products: "Products",
      role_manufacturer: "Manufacturer",
      role_distributor: "Distributor",
      role_retail: "Retail",
      role_service: "Service",
      cat_clothing: "Clothing & accessories",
      cat_pottery: "Pottery",
      cat_woodwork: "Woodwork",
      cat_jewelry: "Jewelry",
      cat_other: "Other",
      ph_website: "https://",
      ph_founded: "e.g. 2015",
      ph_moq: "e.g. 100 pcs",
      ph_capacity: "e.g. 10,000 pcs / month",
      ph_lead: "7–14 days",
      review_logo: "logo",
      review_factory_imgs: "factory photos",
      review_video: "video",
      review_imgs: "photos",
      review_export: "Export",
      review_certs: "Certificates",
    },
  };

  const CATEGORY_KEYS = [
    ["clothing_accessories", "cat_clothing"],
    ["pottery", "cat_pottery"],
    ["woodwork", "cat_woodwork"],
    ["jewelry", "cat_jewelry"],
    ["other", "cat_other"],
  ];
  const CURRENCIES = ["USD", "EUR", "RUB", "UZS"];
  const ROLE_KEYS = {
    manufacturer: "role_manufacturer",
    distributor: "role_distributor",
    retail: "role_retail",
    service: "role_service",
  };
  const CERT_OPTIONS = [
    "ISO 9001",
    "ISO 14001",
    "CE",
    "FDA",
    "RoHS",
    "GMP",
    "BSCI",
  ];
  // Backend /api/v1/countries bilan mos — [code, flag, uz, ru, en]
  const COUNTRY_OPTIONS = [
    ["UZ", "🇺🇿", "Oʻzbekiston", "Узбекистан", "Uzbekistan"],
    ["KZ", "🇰🇿", "Qozogʻiston", "Казахстан", "Kazakhstan"],
    ["KG", "🇰🇬", "Qirgʻiziston", "Кыргызстан", "Kyrgyzstan"],
    ["TJ", "🇹🇯", "Tojikiston", "Таджикистан", "Tajikistan"],
    ["TM", "🇹🇲", "Turkmaniston", "Туркменистан", "Turkmenistan"],
    ["RU", "🇷🇺", "Rossiya", "Россия", "Russia"],
    ["TR", "🇹🇷", "Turkiya", "Турция", "Turkey"],
    ["AZ", "🇦🇿", "Ozarbayjon", "Азербайджан", "Azerbaijan"],
    ["CN", "🇨🇳", "Xitoy", "Китай", "China"],
    ["AE", "🇦🇪", "BAA", "ОАЭ", "UAE"],
    ["SA", "🇸🇦", "Saudiya Arabistoni", "Саудовская Аравия", "Saudi Arabia"],
    ["DE", "🇩🇪", "Germaniya", "Германия", "Germany"],
    ["FR", "🇫🇷", "Fransiya", "Франция", "France"],
    ["IT", "🇮🇹", "Italiya", "Италия", "Italy"],
    ["ES", "🇪🇸", "Ispaniya", "Испания", "Spain"],
    ["GB", "🇬🇧", "Buyuk Britaniya", "Великобритания", "United Kingdom"],
    ["US", "🇺🇸", "AQSH", "США", "United States"],
    ["IN", "🇮🇳", "Hindiston", "Индия", "India"],
    ["JP", "🇯🇵", "Yaponiya", "Япония", "Japan"],
    ["KR", "🇰🇷", "Janubiy Koreya", "Южная Корея", "South Korea"],
    ["PL", "🇵🇱", "Polsha", "Польша", "Poland"],
    ["UA", "🇺🇦", "Ukraina", "Украина", "Ukraine"],
    ["BY", "🇧🇾", "Belarus", "Беларусь", "Belarus"],
    ["NL", "🇳🇱", "Niderlandiya", "Нидерланды", "Netherlands"],
    ["CA", "🇨🇦", "Kanada", "Канада", "Canada"],
    ["AU", "🇦🇺", "Avstraliya", "Австралия", "Australia"],
    ["MY", "🇲🇾", "Malayziya", "Малайзия", "Malaysia"],
    ["ID", "🇮🇩", "Indoneziya", "Индонезия", "Indonesia"],
    ["SE", "🇸🇪", "Shvetsiya", "Швеция", "Sweden"],
    ["CH", "🇨🇭", "Shveysariya", "Швейцария", "Switzerland"],
  ];

  let lang = localStorage.getItem("anylang_partner_lang") || "uz";
  if (!i18n[lang]) lang = "uz";
  let step = 0;
  let state = normalizeState(loadState()) || blankState();

  function t() {
    return i18n[lang] || i18n.uz;
  }

  function countryName(row) {
    if (lang === "ru") return row[3];
    if (lang === "en") return row[4];
    return row[2];
  }

  function categories() {
    const c = t();
    return CATEGORY_KEYS.map(([value, key]) => [value, c[key] || value]);
  }

  function roleLabel(value) {
    const c = t();
    const key = ROLE_KEYS[value];
    return (key && c[key]) || value;
  }

  function blankState() {
    return {
      contact_name: "",
      phone: "",
      email: "",
      password: "",
      password2: "",
      company_name: "",
      country: "UZ",
      business_role: "manufacturer",
      website: "",
      founded_year: "",
      moq: "",
      production_capacity: "",
      lead_time: "",
      bio: "",
      description: "",
      export_countries: [],
      certificates: [],
      logo_url: "",
      factory_image_urls: [],
      factory_video_url: "",
      products: [blankProduct()],
    };
  }

  function asList(value) {
    if (Array.isArray(value)) {
      return value.map((x) => String(x).trim()).filter(Boolean);
    }
    if (typeof value === "string" && value.trim()) {
      return value
        .split(",")
        .map((x) => x.trim())
        .filter(Boolean);
    }
    return [];
  }

  function normalizeState(raw) {
    if (!raw || typeof raw !== "object") return null;
    const next = { ...blankState(), ...raw };
    next.export_countries = asList(raw.export_countries).map((c) =>
      c.toUpperCase().slice(0, 2)
    );
    next.certificates = asList(raw.certificates);
    next.factory_image_urls = Array.isArray(raw.factory_image_urls)
      ? raw.factory_image_urls
      : [];
    next.products =
      Array.isArray(raw.products) && raw.products.length
        ? raw.products
        : [blankProduct()];
    return next;
  }

  function toggleInList(list, value) {
    const arr = Array.isArray(list) ? list.slice() : [];
    const i = arr.indexOf(value);
    if (i >= 0) arr.splice(i, 1);
    else arr.push(value);
    return arr;
  }

  function renderChipGroup(containerId, items, selected, onToggle) {
    const box = document.getElementById(containerId);
    if (!box) return;
    box.innerHTML = "";
    items.forEach((item) => {
      const value = item.value;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "chip" + (selected.includes(value) ? " is-on" : "");
      btn.setAttribute("aria-pressed", selected.includes(value) ? "true" : "false");
      btn.innerHTML = item.html || escapeHtml(item.label);
      btn.addEventListener("click", () => onToggle(value));
      box.appendChild(btn);
    });
  }

  function renderExportChips() {
    renderChipGroup(
      "export_countries_wrap",
      COUNTRY_OPTIONS.map((row) => ({
        value: row[0],
        html: `<span class="flag">${row[1]}</span>${escapeHtml(countryName(row))}`,
      })),
      state.export_countries || [],
      (code) => {
        state.export_countries = toggleInList(state.export_countries, code);
        saveState();
        renderExportChips();
      }
    );
  }

  function renderCertChips() {
    renderChipGroup(
      "certificates_wrap",
      CERT_OPTIONS.map((name) => ({ value: name, label: name })),
      state.certificates || [],
      (name) => {
        state.certificates = toggleInList(state.certificates, name);
        saveState();
        renderCertChips();
      }
    );
  }

  function blankProduct() {
    return {
      name: "",
      short_description: "",
      description: "",
      price: "",
      currency: "USD",
      category: "other",
      moq: "",
      shipping_info: "",
      image_urls: [],
      video_url: "",
    };
  }

  function loadState() {
    try {
      const raw = localStorage.getItem(STORE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  function saveState() {
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify(state));
    } catch (_) {}
  }

  function showStatus(msg, kind) {
    const el = document.getElementById("status");
    el.textContent = msg || "";
    el.className = "status" + (kind ? " is-" + kind : "");
  }

  function applyI18n() {
    const c = t();
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      if (c[key]) el.textContent = c[key];
    });
    document.querySelectorAll("[data-i18n-opt]").forEach((el) => {
      const key = el.getAttribute("data-i18n-opt");
      if (c[key]) el.textContent = c[key];
    });
    document.querySelectorAll("[data-ph]").forEach((el) => {
      const key = el.getAttribute("data-ph");
      if (c[key]) el.setAttribute("placeholder", c[key]);
    });
    const labels = [c.step1, c.step2, c.step3, c.step4];
    document.querySelectorAll("[data-step-label]").forEach((el) => {
      const i = Number(el.getAttribute("data-step-label"));
      el.textContent = labels[i] || el.textContent;
      el.classList.toggle("is-active", i === step);
      el.classList.toggle("is-done", i < step);
    });
    document.title = c.title + " — AnyLang";
    document.documentElement.lang = lang;
    document.querySelectorAll(".lang-btn").forEach((btn) => {
      btn.classList.toggle("is-active", btn.dataset.lang === lang);
    });
    const footHome = document.querySelector(".foot a[href='/']");
    if (footHome) footHome.textContent = c.home;
  }

  async function uploadFile(file) {
    showStatus(t().uploading, "info");
    const fd = new FormData();
    fd.append("file", file);
    const res = await fetch(API + "/upload", { method: "POST", body: fd });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || "Upload failed");
    showStatus("", null);
    return data.url;
  }

  function renderThumbs(containerId, urls, onRemove, isVideo) {
    const box = document.getElementById(containerId);
    box.innerHTML = "";
    (urls || []).forEach((url, idx) => {
      const d = document.createElement("div");
      d.className = "thumb";
      if (isVideo) {
        d.innerHTML = `<video src="${url}" muted></video>`;
      } else {
        d.innerHTML = `<img src="${url}" alt="" />`;
      }
      const btn = document.createElement("button");
      btn.type = "button";
      btn.textContent = "×";
      btn.addEventListener("click", () => onRemove(idx));
      d.appendChild(btn);
      box.appendChild(d);
    });
  }

  function bindBusinessUploads() {
    document.getElementById("logo_file").onchange = async (e) => {
      const f = e.target.files && e.target.files[0];
      if (!f) return;
      try {
        state.logo_url = await uploadFile(f);
        saveState();
        renderThumbs("logo_thumbs", state.logo_url ? [state.logo_url] : [], () => {
          state.logo_url = "";
          saveState();
          renderThumbs("logo_thumbs", [], () => {});
        });
      } catch (err) {
        showStatus(err.message, "error");
      }
      e.target.value = "";
    };
    document.getElementById("factory_images").onchange = async (e) => {
      const files = Array.from(e.target.files || []);
      for (const f of files) {
        try {
          const url = await uploadFile(f);
          state.factory_image_urls.push(url);
        } catch (err) {
          showStatus(err.message, "error");
        }
      }
      saveState();
      bindBusinessUploadsRefresh();
      e.target.value = "";
    };
    document.getElementById("factory_video").onchange = async (e) => {
      const f = e.target.files && e.target.files[0];
      if (!f) return;
      try {
        state.factory_video_url = await uploadFile(f);
        saveState();
        renderThumbs(
          "factory_video_thumbs",
          state.factory_video_url ? [state.factory_video_url] : [],
          () => {
            state.factory_video_url = "";
            saveState();
            renderThumbs("factory_video_thumbs", [], () => {}, true);
          },
          true
        );
      } catch (err) {
        showStatus(err.message, "error");
      }
      e.target.value = "";
    };
  }

  function bindBusinessUploadsRefresh() {
    renderThumbs("logo_thumbs", state.logo_url ? [state.logo_url] : [], () => {
      state.logo_url = "";
      saveState();
      bindBusinessUploadsRefresh();
    });
    renderThumbs("factory_thumbs", state.factory_image_urls, (idx) => {
      state.factory_image_urls.splice(idx, 1);
      saveState();
      bindBusinessUploadsRefresh();
    });
    renderThumbs(
      "factory_video_thumbs",
      state.factory_video_url ? [state.factory_video_url] : [],
      () => {
        state.factory_video_url = "";
        saveState();
        bindBusinessUploadsRefresh();
      },
      true
    );
  }

  function readStep0() {
    state.contact_name = document.getElementById("contact_name").value.trim();
    state.phone = document.getElementById("phone").value.trim();
    state.email = document.getElementById("email").value.trim().toLowerCase();
    state.password = document.getElementById("password").value;
    state.password2 = document.getElementById("password2").value;
  }

  function readStep1() {
    state.company_name = document.getElementById("company_name").value.trim();
    state.country = document.getElementById("country").value.trim().toUpperCase();
    state.business_role = document.getElementById("business_role").value;
    state.website = document.getElementById("website").value.trim();
    state.founded_year = document.getElementById("founded_year").value.trim();
    state.moq = document.getElementById("moq").value.trim();
    state.production_capacity = document.getElementById("production_capacity").value.trim();
    state.lead_time = document.getElementById("lead_time").value.trim();
    state.bio = document.getElementById("bio").value.trim();
    state.description = document.getElementById("description").value.trim();
  }

  function fillStep0() {
    document.getElementById("contact_name").value = state.contact_name || "";
    document.getElementById("phone").value = state.phone || "";
    document.getElementById("email").value = state.email || "";
    document.getElementById("password").value = state.password || "";
    document.getElementById("password2").value = state.password2 || "";
  }

  function fillStep1() {
    document.getElementById("company_name").value = state.company_name || "";
    document.getElementById("country").value = state.country || "UZ";
    document.getElementById("business_role").value = state.business_role || "manufacturer";
    document.getElementById("website").value = state.website || "";
    document.getElementById("founded_year").value = state.founded_year || "";
    document.getElementById("moq").value = state.moq || "";
    document.getElementById("production_capacity").value = state.production_capacity || "";
    document.getElementById("lead_time").value = state.lead_time || "";
    document.getElementById("bio").value = state.bio || "";
    document.getElementById("description").value = state.description || "";
    renderExportChips();
    renderCertChips();
    bindBusinessUploadsRefresh();
  }

  function readProductsFromDom() {
    const cards = document.querySelectorAll(".product-card");
    const next = [];
    cards.forEach((card, idx) => {
      const prev = state.products[idx] || blankProduct();
      next.push({
        name: card.querySelector("[data-f=name]").value.trim(),
        short_description: card.querySelector("[data-f=short]").value.trim(),
        description: card.querySelector("[data-f=desc]").value.trim(),
        price: card.querySelector("[data-f=price]").value.trim(),
        currency: card.querySelector("[data-f=currency]").value,
        category: card.querySelector("[data-f=category]").value,
        moq: card.querySelector("[data-f=moq]").value.trim(),
        shipping_info: card.querySelector("[data-f=ship]").value.trim(),
        image_urls: prev.image_urls || [],
        video_url: prev.video_url || "",
      });
    });
    state.products = next.length ? next : [blankProduct()];
  }

  function renderProducts() {
    const c = t();
    const root = document.getElementById("products");
    root.innerHTML = "";
    state.products.forEach((p, idx) => {
      const card = document.createElement("div");
      card.className = "product-card";
      card.dataset.idx = String(idx);
      const catOpts = categories()
        .map(
          ([v, label]) =>
            `<option value="${v}" ${p.category === v ? "selected" : ""}>${label}</option>`
        )
        .join("");
      const curOpts = CURRENCIES.map(
        (v) => `<option value="${v}" ${p.currency === v ? "selected" : ""}>${v}</option>`
      ).join("");
      card.innerHTML = `
        <div class="head">
          <strong>${c.product} #${idx + 1}</strong>
          <button type="button" class="btn-link" data-remove>${c.remove}</button>
        </div>
        <div class="grid two">
          <label class="field"><span>${c.p_name}</span><input data-f="name" value="${escapeAttr(p.name)}" /></label>
          <label class="field"><span>${c.p_price}</span><input data-f="price" type="number" min="0" step="0.01" value="${escapeAttr(p.price)}" /></label>
          <label class="field"><span>${c.p_currency}</span><select data-f="currency">${curOpts}</select></label>
          <label class="field"><span>${c.p_category}</span><select data-f="category">${catOpts}</select></label>
          <label class="field"><span>${c.p_moq}</span><input data-f="moq" value="${escapeAttr(p.moq)}" /></label>
          <label class="field"><span>${c.p_ship}</span><input data-f="ship" value="${escapeAttr(p.shipping_info)}" /></label>
        </div>
        <div class="grid" style="margin-top:.75rem">
          <label class="field"><span>${c.p_short}</span><input data-f="short" value="${escapeAttr(p.short_description)}" /></label>
          <label class="field"><span>${c.p_desc}</span><textarea data-f="desc">${escapeHtml(p.description)}</textarea></label>
        </div>
        <div class="upload-box" style="margin-top:.75rem">
          <p>${c.p_images}</p>
          <label class="btn-file"><input type="file" accept="image/*" multiple data-img /><span>${c.pick_images}</span></label>
          <div class="thumbs" data-img-thumbs></div>
        </div>
        <div class="upload-box" style="margin-top:.55rem">
          <p>${c.p_video}</p>
          <label class="btn-file"><input type="file" accept="video/*" data-vid /><span>${c.pick_video}</span></label>
          <div class="thumbs" data-vid-thumbs></div>
        </div>
      `;
      card.querySelector("[data-remove]").onclick = () => {
        readProductsFromDom();
        state.products.splice(idx, 1);
        if (!state.products.length) state.products.push(blankProduct());
        saveState();
        renderProducts();
      };
      card.querySelector("[data-img]").onchange = async (e) => {
        readProductsFromDom();
        const files = Array.from(e.target.files || []);
        for (const f of files) {
          try {
            const url = await uploadFile(f);
            state.products[idx].image_urls.push(url);
          } catch (err) {
            showStatus(err.message, "error");
          }
        }
        saveState();
        renderProducts();
      };
      card.querySelector("[data-vid]").onchange = async (e) => {
        readProductsFromDom();
        const f = e.target.files && e.target.files[0];
        if (!f) return;
        try {
          state.products[idx].video_url = await uploadFile(f);
          saveState();
          renderProducts();
        } catch (err) {
          showStatus(err.message, "error");
        }
      };
      root.appendChild(card);
      const imgBox = card.querySelector("[data-img-thumbs]");
      (p.image_urls || []).forEach((url, i) => {
        const d = document.createElement("div");
        d.className = "thumb";
        d.innerHTML = `<img src="${url}" alt="" />`;
        const btn = document.createElement("button");
        btn.type = "button";
        btn.textContent = "×";
        btn.onclick = () => {
          readProductsFromDom();
          state.products[idx].image_urls.splice(i, 1);
          saveState();
          renderProducts();
        };
        d.appendChild(btn);
        imgBox.appendChild(d);
      });
      const vidBox = card.querySelector("[data-vid-thumbs]");
      if (p.video_url) {
        const d = document.createElement("div");
        d.className = "thumb";
        d.innerHTML = `<video src="${p.video_url}" muted></video>`;
        const btn = document.createElement("button");
        btn.type = "button";
        btn.textContent = "×";
        btn.onclick = () => {
          readProductsFromDom();
          state.products[idx].video_url = "";
          saveState();
          renderProducts();
        };
        d.appendChild(btn);
        vidBox.appendChild(d);
      }
    });
  }

  function escapeAttr(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;");
  }
  function escapeHtml(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;");
  }

  function renderReview() {
    const c = t();
    const box = document.getElementById("review");
    box.innerHTML = `
      <div class="review-block">
        <h3>${c.review_account}</h3>
        <ul>
          <li>${escapeHtml(state.contact_name)} · ${escapeHtml(state.email)}</li>
          <li>${escapeHtml(state.phone || "—")}</li>
        </ul>
      </div>
      <div class="review-block">
        <h3>${c.review_business}</h3>
        <ul>
          <li>${escapeHtml(state.company_name)} (${escapeHtml(state.country)})</li>
          <li>${escapeHtml(roleLabel(state.business_role))} · ${c.review_logo}: ${state.logo_url ? "✓" : "—"}</li>
          <li>${c.review_export}: ${escapeHtml((state.export_countries || []).join(", ") || "—")}</li>
          <li>${c.review_certs}: ${escapeHtml((state.certificates || []).join(", ") || "—")}</li>
          <li>${c.review_factory_imgs}: ${(state.factory_image_urls || []).length} · ${c.review_video}: ${state.factory_video_url ? "✓" : "—"}</li>
        </ul>
      </div>
      <div class="review-block">
        <h3>${c.review_products} (${state.products.length})</h3>
        <ul>
          ${state.products
            .map(
              (p) =>
                `<li>${escapeHtml(p.name)} — ${escapeHtml(p.price)} ${escapeHtml(p.currency)} · ${c.review_imgs}: ${(p.image_urls || []).length}</li>`
            )
            .join("")}
        </ul>
      </div>
    `;
  }

  function validateStep(n) {
    const c = t();
    if (n === 0) {
      readStep0();
      if (state.contact_name.length < 2) return c.err_contact;
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(state.email)) return c.err_email;
      if (state.password !== state.password2) return c.err_pass;
      if (!/[A-Za-z]/.test(state.password) || !/\d/.test(state.password) || state.password.length < 8)
        return c.err_pass_weak;
    }
    if (n === 1) {
      readStep1();
      if (state.company_name.length < 2) return c.err_company;
      if (!/^[A-Z]{2}$/.test(state.country)) return c.err_country;
    }
    if (n === 2) {
      readProductsFromDom();
      if (!state.products.length) return c.err_products;
      for (const p of state.products) {
        if (!p.name || p.price === "" || Number(p.price) < 0) return c.err_pname;
      }
    }
    return null;
  }

  function showStep(n) {
    step = n;
    document.querySelectorAll("[data-panel]").forEach((el) => {
      el.classList.toggle("is-active", Number(el.dataset.panel) === step);
    });
    applyI18n();
    if (step === 0) fillStep0();
    if (step === 1) fillStep1();
    if (step === 2) renderProducts();
    if (step === 3) {
      readProductsFromDom();
      saveState();
      renderReview();
    }
    showStatus("", null);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function checkEmail() {
    const email = document.getElementById("email").value.trim().toLowerCase();
    const status = document.getElementById("email_status");
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      status.value = "";
      return;
    }
    try {
      const res = await fetch(API + "/check-email?email=" + encodeURIComponent(email));
      const data = await res.json();
      status.value = data.available ? t().email_ok : data.message || t().email_bad;
    } catch {
      status.value = "";
    }
  }

  async function submitAll() {
    const err = validateStep(0) || validateStep(1) || validateStep(2);
    if (err) {
      showStatus(err, "error");
      return;
    }
    const btn = document.getElementById("submit_btn");
    btn.disabled = true;
    btn.textContent = t().submitting;
    const payload = {
      email: state.email,
      password: state.password,
      contact_name: state.contact_name,
      phone: state.phone || null,
      source_lang: lang === "ru" ? "ru" : lang === "en" ? "en" : "uz",
      company_name: state.company_name,
      country: state.country,
      business_role: state.business_role,
      website: state.website || null,
      bio: state.bio || null,
      description: state.description || null,
      founded_year: state.founded_year ? Number(state.founded_year) : null,
      moq: state.moq || null,
      production_capacity: state.production_capacity || null,
      lead_time: state.lead_time || null,
      certificates: asList(state.certificates),
      export_countries: asList(state.export_countries).map((x) =>
        x.toUpperCase().slice(0, 2)
      ),
      payment_methods: [],
      incoterms: [],
      logo_url: state.logo_url || null,
      factory_image_urls: state.factory_image_urls || [],
      factory_video_url: state.factory_video_url || null,
      products: state.products.map((p) => ({
        name: p.name,
        short_description: p.short_description || "",
        description: p.description || "",
        price: Number(p.price) || 0,
        currency: p.currency || "USD",
        category: p.category || "other",
        moq: p.moq || null,
        shipping_info: p.shipping_info || null,
        image_urls: p.image_urls || [],
        video_url: p.video_url || null,
      })),
    };
    try {
      const res = await fetch(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.message || "Submit failed");
      localStorage.removeItem(STORE_KEY);
      document.getElementById("form-root").style.display = "none";
      document.getElementById("steps").style.display = "none";
      document.getElementById("success").style.display = "block";
      showStatus("", null);
      applyI18n();
    } catch (e) {
      showStatus(e.message || "Error", "error");
    } finally {
      btn.disabled = false;
      btn.textContent = t().submit;
    }
  }

  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      lang = btn.dataset.lang;
      localStorage.setItem("anylang_partner_lang", lang);
      applyI18n();
      if (step === 1) {
        renderExportChips();
        renderCertChips();
      }
      if (step === 2) {
        readProductsFromDom();
        renderProducts();
      }
      if (step === 3) renderReview();
    });
  });

  document.querySelectorAll("[data-next]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const err = validateStep(step);
      if (err) {
        showStatus(err, "error");
        return;
      }
      if (step === 0) {
        await checkEmail();
        const st = document.getElementById("email_status").value;
        if (st && st !== t().email_ok && !st.includes("bo‘sh") && !st.includes("свобод") && !st.toLowerCase().includes("available")) {
          // soft check — only block if API said unavailable
          const res = await fetch(API + "/check-email?email=" + encodeURIComponent(state.email));
          const data = await res.json().catch(() => ({}));
          if (data.available === false) {
            showStatus(data.message || t().email_bad, "error");
            return;
          }
        }
      }
      if (step === 0) readStep0();
      if (step === 1) readStep1();
      if (step === 2) readProductsFromDom();
      saveState();
      showStep(Math.min(3, step + 1));
    });
  });

  document.querySelectorAll("[data-prev]").forEach((btn) => {
    btn.addEventListener("click", () => {
      if (step === 1) readStep1();
      if (step === 2) readProductsFromDom();
      if (step === 3) readProductsFromDom();
      saveState();
      showStep(Math.max(0, step - 1));
    });
  });

  document.getElementById("add_product").addEventListener("click", () => {
    readProductsFromDom();
    state.products.push(blankProduct());
    saveState();
    renderProducts();
  });

  document.getElementById("submit_btn").addEventListener("click", () => void submitAll());

  let emailTimer;
  document.getElementById("email").addEventListener("input", () => {
    clearTimeout(emailTimer);
    emailTimer = setTimeout(() => void checkEmail(), 500);
  });

  bindBusinessUploads();
  applyI18n();
  showStep(0);
})();
