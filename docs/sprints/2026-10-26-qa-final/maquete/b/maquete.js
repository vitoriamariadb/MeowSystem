(() => {
  const raiz = document.documentElement;
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const q = new URLSearchParams(location.search);

  const mudar = (d, rotulo, de = "antes", para = "agora") => {
    if (typeof anotar !== "function") return;
    if (d < 0) {
      if (MUDANCAS.length) { MUDANCAS.shift(); gravar(); pintarMudancas(); }
      return;
    }
    anotar(rotulo, de, para);
  };
  const rotuloDe = (el) => {
    const l = el.closest(".linha, li, .poco");
    const r = l && $(".rot, .som-nome, label, b", l);
    return (r ? r.firstChild.textContent : $("h2", el.closest(".bloco"))?.textContent || "Ajuste").trim();
  };
  const legenda = (x) => (x ? (x.getAttribute("aria-label") || x.title || x.textContent).trim() : "");
  document.addEventListener("DOMContentLoaded", () => {
    $$("[data-controle='creditos']").forEach((b) => (b.onclick = () => { $("#menu").open = false; $("#creditos").showModal(); }));
  });

  const pressiona = (grupo, alvo) => {
    $$(":scope > button, :scope > figure", grupo).forEach((b) => b.setAttribute("aria-pressed", String(b === alvo)));
  };

  const estadoBotoes = () => {
    $$("[data-bt-estado]").forEach((b) => {
      const lista = b.dataset.btEstado.split(" ");
      if (lista.includes(raiz.dataset.estado)) b.dataset.estado = raiz.dataset.estado;
      else delete b.dataset.estado;
    });
  };
  const ctl = $("#m-estado");
  const poeEstado = (v) => {
    raiz.dataset.estado = v;
    if (ctl) ctl.value = v;
    estadoBotoes();
  };
  ctl?.addEventListener("change", () => poeEstado(ctl.value));

  const abas = $$("#abas a[data-aba]");
  const irAba = (k) => {
    if (!abas.some((a) => a.dataset.aba === k)) return;
    raiz.dataset.aba = k;
    abas.forEach((a) => (a.dataset.aba === k ? a.setAttribute("aria-current", "page") : a.removeAttribute("aria-current")));
    $$("[data-aba-corpo]").forEach((s) => (s.hidden = s.dataset.abaCorpo !== k));
    $(".previa .alvo-spotify")?.classList.toggle("mudou-aqui", k === "icones");
  };
  abas.forEach((a) => a.addEventListener("click", (ev) => {
    ev.preventDefault();
    irAba(a.dataset.aba);
    history.replaceState(null, "", `${location.search}#${a.dataset.aba}`);
    scrollTo({ top: 0 });
  }));

  const poeSabor = (b) => {
    raiz.dataset.sabor = b.dataset.sabor;
    raiz.dataset.pack = b.dataset.pack;
    $$(".comeca button").forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
    trocaPackDesenho();
  };
  $$(".comeca button").forEach((b) => b.addEventListener("click", () => { const de = legenda($(".comeca button[aria-pressed=true]")); poeSabor(b); mudar(1, "Começa de", de, legenda(b)); }));

  $("#nome-tema")?.addEventListener("input", (ev) => {
    $$("[data-nome-tema]").forEach((x) => (x.textContent = ev.target.value || "Meu tema"));
  });
  $$(".poco input[type=color]").forEach((i) => i.addEventListener("change", () => {
    const de = $("code", i.closest(".poco")).textContent;
    i.parentElement.style.setProperty("--cor", i.value);
    $("code", i.closest(".poco")).textContent = i.value.toUpperCase();
    mudar(1, rotuloDe(i), de, i.value.toUpperCase());
  }));

  const formata = (v, f) => {
    const n = Number(v);
    if (f === "hz") return `${n} Hz`;
    if (f === "pct") return `${n} %`;
    if (f === "dec") return n.toFixed(2).replace(".", ",");
    return String(n);
  };
  $$("input[type=range]").forEach((r) => {
    const pinta = () => {
      const p = ((r.value - r.min) / (r.max - r.min)) * 100;
      r.style.setProperty("--p", `${p}%`);
      const o = document.getElementById(r.dataset.saida);
      if (o) o.textContent = formata(r.value, r.dataset.formato);
    };
    r.addEventListener("input", pinta);
    r.addEventListener("change", () => mudar(1, rotuloDe(r), formata(r.defaultValue, r.dataset.formato), formata(r.value, r.dataset.formato)));
  });

  $$(".cores").forEach((g) => $$("button", g).forEach((b) => b.addEventListener("click", () => { const de = legenda($("button[aria-pressed=true]", g)); pressiona(g, b); mudar(1, rotuloDe(g), de, legenda(b)); })));
  $$(".seg").forEach((g) => $$("button", g).forEach((b) => b.addEventListener("click", () => pressiona(g, b))));
  $$(".chave").forEach((c) => c.addEventListener("click", () => {
    const liga = c.getAttribute("aria-checked") !== "true";
    c.setAttribute("aria-checked", String(liga));
    mudar(1, rotuloDe(c), liga ? "Não" : "Sim", liga ? "Sim" : "Não");
  }));

  $$(".galeria").forEach((g) => {
    $$("figure", g).forEach((f) => $("img", f).addEventListener("click", () => {
      const de = legenda($("figure[aria-pressed=true] figcaption", g));
      pressiona(g, f);
      const alvo = g.classList.contains("so-dracula") ? "#parede-dracula" : "#parede-meowsystem";
      $(alvo).src = f.dataset.parede;
      mudar(1, "Papel de parede", de, legenda($("figcaption", f)));
    }));
    $$("button.estrela, button.levar", g).forEach((b) => b.addEventListener("click", () => {
      b.setAttribute("aria-pressed", String(b.getAttribute("aria-pressed") !== "true"));
    }));
  });
  $$("[data-encaixe]").forEach((b) => b.addEventListener("click", () => {
    $$(".previa .parede").forEach((p) => {
      p.classList.remove("caber", "esticar");
      if (b.dataset.encaixe) p.classList.add(b.dataset.encaixe);
    });
  }));

  $$("[data-sub]").forEach((b) => b.addEventListener("click", () => {
    $$("[data-sub-corpo]").forEach((s) => (s.hidden = s.dataset.subCorpo !== b.dataset.sub));
  }));
  $("#procura-icone")?.addEventListener("input", (ev) => {
    const t = ev.target.value.trim().toLowerCase();
    $$(".grade-apps .app, .grade-glifos button").forEach((x) => {
      x.hidden = t !== "" && !x.textContent.toLowerCase().includes(t);
    });
  });

  const desenho = $("#desenho");
  const pack = () => raiz.dataset.pack;
  const lupa = (src) => {
    $("#d-lupa").src = src;
    $$("[data-d-dock]").forEach((i) => (i.src = src));
  };
  const trocaPackDesenho = () => {
    if (!desenho) return;
    const app = desenho.dataset.app;
    const src = `svg/${pack()}/apps/${app}.svg`;
    $("#d-icone").src = src;
    $("[data-do-pack-img]").src = src;
    $("[data-do-pack]").dataset.src = src;
    $$(".oficina-cartao").forEach((c) => c.setAttribute("aria-pressed", String(c.hasAttribute("data-do-pack"))));
    lupa(src);
  };
  const abreApp = (app, nome) => {
    if (!desenho) return;
    $$(".grade-apps .app").forEach((b) => b.setAttribute("aria-expanded", String(b.dataset.app === app)));
    desenho.dataset.app = app;
    $("#d-nome").textContent = nome;
    $("#d-salvo").hidden = true;
    trocaPackDesenho();
    $("#grade-bloco").hidden = true;
    desenho.hidden = false;
  };
  $$(".grade-apps .app[data-app]").forEach((b) => b.addEventListener("click", () => abreApp(b.dataset.app, b.dataset.nome)));
  $$("[data-abre-app]").forEach((b) => b.addEventListener("click", () => { poeEstado("normal"); abreApp(b.dataset.abreApp, "Spotify"); }));
  $("[data-volta]")?.addEventListener("click", () => {
    desenho.hidden = true;
    $("#grade-bloco").hidden = false;
    $$(".grade-apps .app").forEach((b) => b.setAttribute("aria-expanded", "false"));
  });
  $$("[data-fonte]").forEach((b) => b.addEventListener("click", () => {
    $$("[data-fonte-corpo]").forEach((s) => (s.hidden = s.dataset.fonteCorpo !== b.dataset.fonte));
  }));
  $$(".oficina-cartao").forEach((c) => c.addEventListener("click", () => {
    if (!c.dataset.src) return;
    $$(".oficina-cartao").forEach((x) => x.setAttribute("aria-pressed", String(x === c)));
    lupa(c.dataset.src);
  }));
  $$(".grade-glifos.acervo button").forEach((b) => b.addEventListener("click", () => {
    $$(".grade-glifos.acervo button").forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
    lupa(b.dataset.src);
  }));
  $("#d-usar")?.addEventListener("click", () => {
    if (raiz.dataset.estado === "erro" || raiz.dataset.estado === "carregando") return;
    const src = $("#d-lupa").getAttribute("src");
    const app = desenho.dataset.app;
    const salvo = $("[data-salvo]");
    salvo.disabled = false;
    salvo.dataset.src = src;
    const lugar = $("[data-salvo-img]", salvo);
    const img = document.createElement("img");
    img.src = src;
    img.alt = "";
    img.setAttribute("data-salvo-img", "");
    lugar.replaceWith(img);
    $$(`.grade-apps.so-${pack()} .app[data-app="${app}"]`).forEach((b) => {
      $("img", b).src = src;
      $(".marca-origem", b).dataset.origem = "escolha";
    });
    if (app === "spotify") $$(`.previa .alvo-spotify img.so-${pack()}`).forEach((i) => (i.src = src));
    $("#d-salvo").hidden = false;
    mudar(1, `Ícone · ${$("#d-nome")?.textContent || app}`, "Do pack", legenda($(".oficina-cartao[aria-pressed=true]")) || "Escolha");
  });
  $("#d-desfazer")?.addEventListener("click", () => { trocaPackDesenho(); mudar(-1); });

  let tocando = null;
  $$("button.p[data-som]").forEach((b) => b.addEventListener("click", () => {
    if (tocando) tocando.pause();
    $$("button.p[data-tocando]").forEach((x) => x.removeAttribute("data-tocando"));
    if (!b.dataset.som) return;
    tocando = new Audio(b.dataset.som);
    b.setAttribute("data-tocando", "");
    tocando.addEventListener("ended", () => b.removeAttribute("data-tocando"));
    tocando.play().catch(() => b.removeAttribute("data-tocando"));
  }));
  $$("[data-trocar]").forEach((b) => b.addEventListener("click", () => {
    const p = $("[data-origem]", b.closest("li"));
    const de = p.textContent;
    p.textContent = "Trocado";
    p.dataset.estado = "";
    mudar(1, rotuloDe(b), de, "Trocado");
  }));

  const valor = (box, s) => Number($(s, box).value);
  const desenhaEnvelope = (box) => {
    const d = valor(box, "[data-sino-d]");
    const pts = [];
    for (let i = 0; i <= 60; i++) {
      const t = (0.085 * i) / 60;
      const a = Math.exp(-t * d) * Math.min(1, i / 2) * Math.min(1, (60 - i) / 2);
      pts.push(`${(4 + (i * 292) / 60).toFixed(1)} ${(60 - a * 52).toFixed(1)}`);
    }
    $("[data-envelope]", box).setAttribute("d", `M${pts.join(" L")}`);
  };
  let ctx = null;
  $$("[data-sino]").forEach((box) => {
    $$("input[type=range]", box).forEach((r) => r.addEventListener("input", () => desenhaEnvelope(box)));
    $("[data-tocar-sino]", box).addEventListener("click", () => {
      ctx = ctx || new AudioContext();
      const taxa = ctx.sampleRate;
      const dur = 0.085;
      const n = Math.floor(taxa * dur);
      const buf = ctx.createBuffer(1, n, taxa);
      const dados = buf.getChannelData(0);
      const f = valor(box, "[data-sino-f]");
      const h = valor(box, "[data-sino-h]");
      const pf = valor(box, "[data-sino-pf]");
      const ph = valor(box, "[data-sino-ph]");
      const d = valor(box, "[data-sino-d]");
      const borda = taxa * 0.002;
      for (let i = 0; i < n; i++) {
        const t = i / taxa;
        const env = Math.exp(-t * d);
        const jan = Math.min(1, i / borda) * Math.min(1, (n - i) / borda);
        const s = pf * Math.sin(2 * Math.PI * f * t) + ph * Math.sin(2 * Math.PI * h * t);
        dados[i] = Math.max(-1, Math.min(1, s * env * jan * 0.18));
      }
      const fonte = ctx.createBufferSource();
      fonte.buffer = buf;
      fonte.connect(ctx.destination);
      fonte.start();
    });
  });

  const mini = $("#mini-applets");
  const desenhaMini = () => {
    if (!mini) return;
    mini.replaceChildren(...$$("#asa-direita .applet-na-barra.nosso img").map((i) => i.cloneNode()));
  };
  const naBarra = (card) => {
    const img = $(".icone img", card);
    const s = document.createElement("span");
    s.className = "applet-na-barra nosso mudou-aqui";
    s.title = card.dataset.nome;
    s.append(img.cloneNode());
    $$("#asa-direita .mudou-aqui").forEach((x) => x.classList.remove("mudou-aqui"));
    $("#asa-direita").append(s);
    const p = $("[data-pilula]", card);
    p.textContent = "Na barra";
    p.dataset.estado = "ok";
    $("[data-por]", card)?.remove();
    desenhaMini();
    mudar(1, card.dataset.nome, "Fora da barra", "Na barra");
  };
  $$("[data-por]").forEach((b) => b.addEventListener("click", () => naBarra(b.closest("article"))));
  $("[data-trocar-qs]")?.addEventListener("click", () => {
    $("#na-barra-qs")?.remove();
    naBarra($('article[data-applet="quick-settings"]'));
    $("#pendencia").hidden = true;
  });
  $("[data-manter]")?.addEventListener("click", () => ($("#pendencia").hidden = true));
  $$("[data-instalar]").forEach((b) => b.addEventListener("click", () => {
    if (raiz.dataset.estado !== "normal") return;
    b.dataset.estado = "carregando";
    setTimeout(() => {
      delete b.dataset.estado;
      const card = b.closest("article");
      const p = $("[data-pilula]", card);
      p.textContent = "Instalada, fora da barra";
      const por = document.createElement("button");
      por.className = "bt pequeno";
      por.type = "button";
      por.innerHTML = '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="M3 9h18"/></svg>Pôr no painel';
      por.setAttribute("data-por", "");
      por.addEventListener("click", () => naBarra(card));
      b.replaceWith(por);
    }, 1200);
  }));

  $$("[data-abre]").forEach((b) => b.addEventListener("click", () => {
    const d = document.getElementById(b.dataset.abre);
    if (!d) return;
    if (d.id === "adicionar") d.dataset.passo = "url";
    b.closest("details")?.removeAttribute("open");
    d.showModal();
  }));
  $$("dialog [data-fecha]").forEach((b) => b.addEventListener("click", () => b.closest("dialog").close()));
  const dlg = $("#adicionar");
  $$("[data-passo-ir]", dlg || document.createElement("div")).forEach((b) => b.addEventListener("click", () => {
    let ir = b.dataset.passoIr;
    const url = $("#repo-url").value.trim();
    if (ir === "ficha" && !url.startsWith("https://")) ir = "erro-url";
    dlg.dataset.passo = ir;
    if (ir === "compilando") setTimeout(() => {
      if (dlg.dataset.passo === "compilando") dlg.dataset.passo = raiz.dataset.estado === "erro" ? "erro" : "pronto";
    }, 1600);
  }));

  const passo = q.get("passo");
  if (passo && dlg) {
    dlg.dataset.passo = passo;
    dlg.showModal();
  }
  const sabor = q.get("sabor");
  if (sabor) {
    const b = $(`.comeca button[data-sabor="${sabor}"]`);
    if (b) poeSabor(b);
  }
  poeEstado(q.get("estado") || "normal");
  irAba(location.hash.slice(1) || raiz.dataset.aba);
  const sub = q.get("sub");
  if (sub) $(`[data-sub="${sub}"]`)?.click();
  const app = q.get("app");
  if (app) {
    const b = $(`.grade-apps.so-${pack()} .app[data-app="${app}"]`);
    if (b) abreApp(app, b.dataset.nome);
  }
  const fonte = q.get("fonte");
  if (fonte) $(`[data-fonte="${fonte}"]`)?.click();
  if (q.get("creditos")) $("#creditos")?.showModal();
})();
