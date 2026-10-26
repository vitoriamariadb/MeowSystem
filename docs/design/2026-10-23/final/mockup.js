(function () {
  "use strict";
  var raiz = document.documentElement;
  var corpo = document.body;

  var P = {
    tema: '<circle cx="13.5" cy="6.5" r="1.5"/><circle cx="17.5" cy="10.5" r="1.5"/><circle cx="8.5" cy="7.5" r="1.5"/><circle cx="6.5" cy="12.5" r="1.5"/><path d="M12 2a10 10 0 0 0 0 20c1.1 0 2-.9 2-2 0-.5-.2-1-.5-1.3-.3-.4-.5-.8-.5-1.3 0-1.1.9-2 2-2h2.3A5.7 5.7 0 0 0 22 9.7C22 5.4 17.5 2 12 2Z"/>',
    criar: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
    ajustes: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
    cuidar: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
    busca: '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
    senha: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    rede: '<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>',
    subir: '<path d="M12 21V9M7 14l5-5 5 5M5 3h14"/>',
    mais: '<path d="M12 5v14M5 12h14"/>',
    copiar: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/>',
    certo: '<path d="M20 6 9 17l-5-5"/>',
    tocar: '<path d="M7 4v16l13-8Z"/>',
    sol: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    lua: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/>',
    painel: '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M3 8h18M8 17h8"/>',
    janelas: '<rect x="3" y="4" width="11" height="8" rx="1.5"/><rect x="10" y="12" width="11" height="8" rx="1.5"/>',
    imagem: '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="9" cy="9" r="2"/><path d="m21 15-5-5L5 21"/>',
    gato: '<path d="M5 9 4 3l5 3a8 8 0 0 1 6 0l5-3-1 6"/><path d="M5 9a7 7 0 1 0 14 0"/><path d="M9.5 13h.01M14.5 13h.01M11 16h2"/>',
    grade: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    terminal: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 9 3 3-3 3M13 15h4"/>',
    relogio: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    alerta: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
    fechar: '<path d="M18 6 6 18M6 6l12 12"/>',
    enviar: '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    desfazer: '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
    som: '<path d="M11 5 6 9H2v6h4l5 4Z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14"/>',
    pasta: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
    computador: '<rect x="2" y="4" width="20" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
    girar: '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
    lixo: '<path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/>',
    ondas: '<path d="M2 12h2l3-7 4 14 4-10 3 6h4"/>',
    seta: '<path d="M5 12h14M13 6l6 6-6 6"/>'
  };
  function ic(n, cls) { return '<svg class="i ' + (cls || "") + '" viewBox="0 0 24 24" aria-hidden="true">' + (P[n] || "") + "</svg>"; }
  window.ic = ic;
  document.querySelectorAll("[data-ic]").forEach(function (el) { el.insertAdjacentHTML("afterbegin", ic(el.dataset.ic)); });

  var MEOW = window.MEOW_ICONES || {};

  var est = { tema: "mocha", destaque: "" };
  try { var g = JSON.parse(localStorage.getItem("meow-final") || "{}"); if (g.tema) est.tema = g.tema; if (g.destaque) est.destaque = g.destaque; } catch (e) { }
  var forcado = new URLSearchParams(location.search).get("tema");
  if (forcado) est.tema = forcado;
  function guardar() { try { localStorage.setItem("meow-final", JSON.stringify(est)); } catch (e) { } }
  function familia(t) { return (t === "dracula" || t === "alucard") ? "dracula" : "meow"; }
  function vestir() {
    raiz.dataset.tema = est.tema;
    if (est.destaque) raiz.dataset.destaque = est.destaque; else delete raiz.dataset.destaque;
    raiz.dataset.familia = familia(est.tema);
    document.querySelectorAll("[data-escolhe-tema]").forEach(function (b) {
      var sim = b.dataset.escolheTema === est.tema;
      b.setAttribute("aria-pressed", String(sim));
    });
    document.querySelectorAll("[data-pack-cartao]").forEach(function (c) {
      var noAr = c.dataset.packCartao === familia(est.tema);
      c.classList.toggle("no-ar", noAr);
      var pv = c.querySelector(".previa");
      if (pv) {
        if (!pv.dataset.packPadrao) pv.dataset.packPadrao = pv.dataset.pack;
        if (noAr) pv.removeAttribute("data-pack"); else pv.dataset.pack = pv.dataset.packPadrao;
        previa(pv);
      }
    });
    document.querySelectorAll("[data-destaque]").forEach(function (b) {
      if (b.tagName === "BUTTON") b.setAttribute("aria-pressed", String((est.destaque || "mauve") === b.dataset.destaque));
    });
    document.querySelectorAll("[data-nome-tema]").forEach(function (el) { el.textContent = NOMES[est.tema]; });
    document.querySelectorAll(".previa:not([data-pack])").forEach(previa);
  }
  var NOMES = { mocha: "MeowSystem · Mocha", macchiato: "MeowSystem · Macchiato", frappe: "MeowSystem · Frappé", latte: "MeowSystem · Latte", dracula: "Dracula", alucard: "Dracula · Alucard" };

  var PORTAS = [
    ["tema", "index.html", "Tema", "tema"],
    ["criar", "criar-cores.html", "Criar tema", "criar"],
    ["ajustes", "ajustes-painel.html", "Ajustes", "ajustes"],
    ["cuidar", "cuidar.html", "Cuidar", "cuidar"]
  ];
  var topo = document.getElementById("topo");
  if (topo) {
    topo.className = "topo";
    topo.innerHTML =
      '<a class="marca" href="index.html"><svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9.6 22.4 8.2 7.4l11.6 6.2a16 16 0 0 1 8.4 0l11.6-6.2-1.4 15"/><path d="M9.6 22.4a14.4 14.4 0 1 0 28.8 0"/><path d="M18 25h.01M30 25h.01M21.5 31c1.4 1.2 3.6 1.2 5 0"/></svg>MeowSystem</a>' +
      '<nav aria-label="Portas"><ul class="portas">' + PORTAS.map(function (p) {
        return '<li><a href="' + p[1] + '"' + (corpo.dataset.porta === p[0] ? ' aria-current="page"' : "") + ">" + ic(p[3]) + "<span>" + p[2] + "</span></a></li>";
      }).join("") + "</ul></nav>" +
      '<div class="busca" role="search">' + ic("busca") + '<input id="busca" type="search" placeholder="Procurar um ajuste" aria-label="Procurar um ajuste" autocomplete="off"><kbd>/</kbd><div class="achados" id="achados" role="listbox"></div></div>' +
      '<div class="aplicar" id="aplicar" data-n="0"><span class="conta" id="conta">Nada por aplicar</span>' +
      '<button class="bt leve pequeno desfazer" id="desfazer" type="button">' + ic("desfazer") + "Desfazer</button>" +
      '<button class="bt principal pequeno" id="bt-aplicar" type="button" disabled>Aplicar</button></div>';
  }
  var rodape = document.getElementById("rodape");
  if (rodape) {
    rodape.className = "rodape";
    rodape.innerHTML = '<span>MeowSystem · GPL-3.0 · feito pela Vitória, com arte de muita gente</span>' +
      '<nav><a href="estados.html">Estados da tela</a><a href="index.html#creditos">Créditos</a><a href="../LEIA-ME.md">O que veio de onde</a></nav>';
  }

  var SUBS = [
    ["painel", "ajustes-painel.html", "Painel e dock", "painel"],
    ["janelas", "ajustes-janelas.html", "Janelas e tela", "janelas"],
    ["papel", "ajustes-papel.html", "Papel de parede", "imagem"],
    ["gato", "ajustes-gato.html", "Gato", "gato"],
    ["dia", "ajustes-dia-e-noite.html", "Dia e noite", "lua"],
    ["terminal", "ajustes-terminal.html", "Terminal", "terminal"],
    ["programas", "ajustes-programas.html", "Programas", "grade"]
  ];
  var trilho = document.getElementById("trilho");
  if (trilho) {
    trilho.innerHTML = '<ul class="trilho">' + SUBS.map(function (s) {
      return '<li><a href="' + s[1] + '"' + (corpo.dataset.sub === s[0] ? ' aria-current="page"' : "") + ">" + ic(s[3]) + s[2] + "</a></li>";
    }).join("") + "</ul>";
  }
  var PASSOS = [["cores", "criar-cores.html", "Cores"], ["icones", "criar-icones.html", "Ícones"], ["papel", "criar-papel.html", "Papel de parede"], ["sons", "criar-sons.html", "Sons"], ["publicar", "criar-publicar.html", "Mandar"]];
  var passos = document.getElementById("passos");
  if (passos) {
    var aqui = PASSOS.findIndex(function (p) { return p[0] === corpo.dataset.passo; });
    passos.className = "passos";
    passos.innerHTML = PASSOS.map(function (p, i) {
      var feito = i < aqui;
      return '<li><a href="' + p[1] + '"' + (i === aqui ? ' aria-current="step"' : "") + (feito ? ' class="feito"' : "") + "><b>" + (feito ? ic("certo") : i + 1) + "</b>" + p[2] + "</a></li>";
    }).join("");
  }

  var DRAC_DOCK = ["org.gnome.Nautilus", "firefox", "org.telegram.desktop", "discord", "spotify", "md.obsidian.Obsidian", "vscode", "photogimp", "whatsapp-linux-app"];
  var MEOW_DOCK = ["files", "firefox", "telegram", "discord", "spotify", "terminal"];
  var PASTAS = [["folder-documents", "Documentos"], ["folder-download", "Downloads"], ["folder-music", "Músicas"], ["folder-pictures", "Imagens"], ["folder-videos", "Vídeos"], ["user-desktop", "Área de trabalho"], ["folder", "Projetos"], ["user-home", "Pessoal"]];
  var TIRA = ["red", "peach", "yellow", "green", "teal", "sky", "blue", "mauve", "pink"];
  function previa(el) {
    var fam = el.dataset.pack ? (el.dataset.pack === "dracula" ? "dracula" : "meow") : familia(est.tema);
    var sem = (el.dataset.sem || "").split(" ");
    var gato = el.dataset.gato || "coquinha";
    var parede = el.dataset.parede || (fam === "dracula" ? "assets/papeis/eclipse.svg" : "");
    var marca = (el.dataset.marca || "").split(" ");
    function m(k) { return marca.indexOf(k) >= 0 ? " mudou-aqui" : ""; }
    var dock = fam === "dracula"
      ? DRAC_DOCK.map(function (a) { return '<span class="app"><img src="assets/dracula/' + a + '.svg" alt=""></span>'; }).join("")
      : MEOW_DOCK.map(function (a) { return '<span class="app">' + (MEOW[a] || "") + "</span>"; }).join("");
    var pastas = PASTAS.map(function (p) {
      return "<figure>" + (fam === "dracula" ? '<img src="assets/dracula/' + p[0] + '.svg" alt="">' : '<svg class="i" viewBox="0 0 24 24">' + P.pasta + "</svg>") + "<figcaption>" + p[1] + "</figcaption></figure>";
    }).join("");
    var h = "";
    if (parede) h += '<img class="parede" src="' + parede + '" alt="">';
    h += '<div class="p-barra' + m("painel") + '"><span class="ws"><i></i><i></i><i></i><i></i></span>' +
      (sem.indexOf("musica") < 0 ? '<span class="musica"><i></i><b>Space Song</b><span>· Beach House</span></span>' : '<span>qui 23 out · 14:32</span>') +
      '<span class="bandeja"><i></i><i></i><i></i>' + (sem.indexOf("musica") < 0 ? "<span>14:32</span>" : "") + "</span></div>";
    if (sem.indexOf("arq") < 0) h += '<div class="p-jan p-arq' + m("arq") + '"><header>Pessoal<i></i></header><div class="corpo"><nav><span>Pessoal</span><span>Recentes</span><span>Downloads</span><span>Projetos</span><span>Lixeira</span></nav><div class="pastas">' + pastas + "</div></div></div>";
    if (sem.indexOf("term") < 0) {
      var ff = el.dataset.ff ? '<div class="gato-ff"><img src="packs/meowsystem/mascote/' + el.dataset.ff + '.svg" alt=""><div>vitoria@meow<br>SO Pop!_OS 24.04<br>Tema ' + (fam === "dracula" ? "Dracula" : "MeowSystem") + "</div></div>" : "";
      h += '<div class="p-jan p-term' + m("term") + '"><header>Terminal<i></i></header><div class="corpo"><div class="pr"><b>meow</b><b>~/Desenvolvimento</b><b>dev</b></div><div><span class="ok">ok</span> doctor: 63 etapas, nada a consertar</div><div>&gt; <span class="cursor"></span></div>' + ff +
        '<div class="tira">' + TIRA.map(function (c) { return '<i style="background:var(--c-' + c + ')"></i>'; }).join("") + "</div></div></div>";
    }
    if (el.dataset.aviso) h += '<div class="p-aviso"><img src="packs/meowsystem/mascote/' + gato + '.svg" alt=""><div><b>' + el.dataset.aviso.split("|")[0] + "</b><span>" + (el.dataset.aviso.split("|")[1] || "") + "</span></div></div>";
    if (sem.indexOf("dock") < 0) h += '<div class="p-dock' + m("dock") + '"><img class="gato" src="packs/meowsystem/mascote/' + gato + '.svg" alt="Gato do dock"><span class="sep"></span>' + dock + "</div>";
    el.innerHTML = h;
    el.setAttribute("role", "img");
    if (!el.getAttribute("aria-label")) el.setAttribute("aria-label", "Prévia da área de trabalho");
  }
  document.querySelectorAll(".previa").forEach(previa);
  window.previa = previa;

  var caixa = document.getElementById("aplicar");
  var n = 0;
  function contar(d) {
    n = Math.max(0, d === 0 ? 0 : n + d);
    if (!caixa) return;
    caixa.dataset.n = String(n);
    document.getElementById("conta").textContent = n === 0 ? "Nada por aplicar" : n + (n > 1 ? " mudanças" : " mudança");
    document.getElementById("bt-aplicar").disabled = n === 0;
  }
  window.contar = contar;
  function marcar(el) {
    var l = el.closest(".linha, [data-conta]");
    if (!l) { contar(1); return; }
    if (!l.classList.contains("mudou")) { l.classList.add("mudou"); contar(1); }
  }
  if (caixa) {
    var inicio = parseInt(corpo.dataset.pendentes || "0", 10);
    if (inicio) contar(inicio);
    document.getElementById("desfazer").addEventListener("click", function () {
      document.querySelectorAll(".mudou").forEach(function (l) { if (!l.hasAttribute("data-fixo")) l.classList.remove("mudou"); });
      contar(0);
    });
    document.getElementById("bt-aplicar").addEventListener("click", function () {
      var b = this;
      b.dataset.estado = "carregando"; b.textContent = "Aplicando";
      setTimeout(function () {
        b.dataset.estado = "feito"; b.textContent = "Aplicado";
        document.querySelectorAll(".mudou").forEach(function (l) { l.classList.remove("mudou"); });
        setTimeout(function () { delete b.dataset.estado; b.textContent = "Aplicar"; contar(0); }, 1200);
      }, 900);
    });
  }

  function pinta(r) {
    var p = (r.value - r.min) / (r.max - r.min) * 100;
    r.style.setProperty("--p", p + "%");
  }
  document.querySelectorAll('input[type="range"]').forEach(pinta);
  document.addEventListener("input", function (ev) {
    var r = ev.target;
    if (r.type === "range") {
      pinta(r);
      var f = r.closest(".faixa");
      var out = f && f.querySelector("output");
      if (out) out.textContent = (r.dataset.mostra ? r.dataset.mostra.split(",")[r.value] : String(r.value).replace(".", ",")) + (r.dataset.un ? " " + r.dataset.un : "");
      if (f) f.classList.remove("de-fabrica");
      if (r.dataset.prev) {
        var alvo = document.querySelector(r.dataset.alvo || ".palco .previa");
        if (alvo) alvo.style.setProperty(r.dataset.prev, r.dataset.pct ? (r.value * 100) + "%" : (r.value * parseFloat(r.dataset.fator || "0.1")) + "cqi");
      }
      marcar(r);
    }
  });
  document.addEventListener("click", function (ev) {
    var t = ev.target;
    var ch = t.closest(".chave");
    if (ch && !ch.disabled) { ch.setAttribute("aria-checked", String(ch.getAttribute("aria-checked") !== "true")); marcar(ch); return; }
    var sb = t.closest(".seg button");
    if (sb) {
      sb.parentElement.querySelectorAll("button").forEach(function (x) { x.setAttribute("aria-pressed", String(x === sb)); });
      if (sb.dataset.escolheTema) return;
      marcar(sb); return;
    }
    var cb = t.closest(".cores button[data-destaque]");
    if (cb) { est.destaque = cb.dataset.destaque === "mauve" ? "" : cb.dataset.destaque; guardar(); vestir(); contar(1); return; }
    var cc = t.closest(".cores button");
    if (cc) { cc.parentElement.querySelectorAll("button").forEach(function (x) { x.setAttribute("aria-pressed", String(x === cc)); }); marcar(cc); return; }
    var et = t.closest("[data-escolhe-tema]");
    if (et) { est.tema = et.dataset.escolheTema; guardar(); vestir(); contar(1); return; }
    var esc = t.closest("[data-escolhe]");
    if (esc) {
      var grupo = esc.closest("[data-grupo]") || esc.parentElement;
      grupo.querySelectorAll("[data-escolhe]").forEach(function (x) { x.setAttribute("aria-pressed", String(x === esc)); });
      if (esc.dataset.gatoPrev) { var pv = document.querySelector(".palco .previa"); if (pv) { pv.dataset.gato = esc.dataset.gatoPrev; previa(pv); } }
      if (esc.dataset.paredePrev) { var pp = document.querySelector(".palco .previa"); if (pp) { pp.dataset.parede = esc.dataset.paredePrev; previa(pp); } }
      marcar(esc); return;
    }
    var pd = t.closest(".padrao");
    if (pd) { var l = pd.closest(".linha"); if (l) { l.classList.remove("mudou"); pd.remove(); contar(-1); } return; }
    var cp = t.closest("[data-copiar]");
    if (cp) {
      var txt = document.querySelector(cp.dataset.copiar).textContent;
      try { navigator.clipboard.writeText(txt); } catch (e) { }
      var antes = cp.innerHTML; cp.dataset.estado = "feito"; cp.innerHTML = ic("certo") + "Copiado";
      setTimeout(function () { delete cp.dataset.estado; cp.innerHTML = antes; }, 1400);
      return;
    }
    var sn = t.closest("[data-sino]");
    if (sn) { sino(sn.dataset.sino); return; }
    var so = t.closest("[data-som]");
    if (so) { try { new Audio(so.dataset.som).play(); } catch (e) { } return; }
  });

  var balao = document.createElement("div");
  balao.className = "porque"; balao.setAttribute("role", "tooltip"); balao.id = "porque";
  corpo.appendChild(balao);
  var qAberto = null;
  document.querySelectorAll(".q").forEach(function (q) {
    q.type = "button"; q.textContent = "?";
    q.setAttribute("aria-label", "Por quê?"); q.setAttribute("aria-expanded", "false"); q.setAttribute("aria-describedby", "porque");
  });
  document.addEventListener("click", function (ev) {
    var q = ev.target.closest(".q");
    if (qAberto && qAberto !== q) { qAberto.setAttribute("aria-expanded", "false"); balao.classList.remove("aberto"); qAberto = null; }
    if (!q) return;
    if (qAberto === q) { q.setAttribute("aria-expanded", "false"); balao.classList.remove("aberto"); qAberto = null; return; }
    balao.textContent = q.dataset.porque || "";
    var r = q.getBoundingClientRect();
    balao.style.left = Math.max(16, Math.min(window.innerWidth - 336, r.left - 8)) + "px";
    balao.style.top = (r.bottom + 8) + "px";
    balao.classList.add("aberto"); q.setAttribute("aria-expanded", "true"); qAberto = q;
  });
  document.addEventListener("keydown", function (ev) { if (ev.key === "Escape" && qAberto) { qAberto.setAttribute("aria-expanded", "false"); balao.classList.remove("aberto"); qAberto = null; } });
  window.addEventListener("scroll", function () { if (qAberto) { balao.classList.remove("aberto"); qAberto.setAttribute("aria-expanded", "false"); qAberto = null; } }, { passive: true });

  corpo.insertAdjacentHTML("beforeend",
    '<dialog id="senha" aria-labelledby="senha-t"><form method="dialog" class="dentro">' +
    '<h2 id="senha-t">' + ic("senha") + '<span></span></h2><p class="calmo" id="senha-d"></p>' +
    '<label class="fila"><span class="sr">Senha</span><input class="campo" type="password" placeholder="Sua senha" style="flex:1" autocomplete="current-password"></label>' +
    '<div class="acoes"><button class="bt leve" value="nao">Agora não</button><button class="bt principal" value="sim">Continuar</button></div></form></dialog>' +
    '<section class="saida" id="saida" aria-live="polite"><header><b id="saida-t"></b><button class="bt leve pequeno" type="button" id="saida-x">' + ic("fechar") + '<span class="sr">Fechar</span></button></header><ol id="saida-l"></ol>' +
    '<details><summary>O que ele escreveu</summary><pre id="saida-p"></pre></details></section>');
  var dlg = document.getElementById("senha");
  var depois = null;
  document.addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-acao]");
    if (!b) return;
    if (b.dataset.senha !== undefined) {
      dlg.querySelector("#senha-t span").textContent = b.dataset.acao;
      dlg.querySelector("#senha-d").textContent = b.dataset.senha || "Mexe em arquivo do sistema.";
      var ok = dlg.querySelector('button[value="sim"]'), perigoso = b.classList.contains("perigo");
      ok.className = perigoso ? "bt perigo" : "bt principal";
      ok.textContent = perigoso ? b.textContent.trim() : "Continuar";
      depois = b; dlg.showModal(); return;
    }
    rodar(b);
  });
  dlg.addEventListener("close", function () { if (dlg.returnValue === "sim" && depois) rodar(depois); depois = null; });
  document.getElementById("saida-x").addEventListener("click", function () { document.getElementById("saida").classList.remove("aberta"); });
  function rodar(b) {
    var s = document.getElementById("saida"), l = document.getElementById("saida-l");
    var pss = (b.dataset.passos || "Conferindo|Pronto").split("|");
    document.getElementById("saida-t").textContent = b.dataset.acao;
    document.getElementById("saida-p").textContent = "$ meow " + (b.dataset.cmd || "doctor --consertar") + "\n" + pss.map(function (p) { return "  ok  " + p.toLowerCase(); }).join("\n");
    l.innerHTML = ""; s.classList.add("aberta");
    b.dataset.estado = "carregando";
    pss.forEach(function (p, i) {
      setTimeout(function () {
        var ant = l.querySelector(".vai"); if (ant) ant.classList.remove("vai");
        var li = document.createElement("li"); li.textContent = p; if (i < pss.length - 1) li.className = "vai"; l.appendChild(li);
        if (i === pss.length - 1) { b.dataset.estado = "feito"; setTimeout(function () { delete b.dataset.estado; }, 1600); }
      }, 450 * (i + 1));
    });
  }

  var INDICE = [
    ["Trocar de tema", "Tema", "index.html"], ["Cor de destaque", "Tema", "index.html"], ["Claro ou escuro", "Tema", "index.html"],
    ["Distância da borda", "Ajustes › Painel e dock", "ajustes-painel.html"], ["Cantos arredondados", "Ajustes › Painel e dock", "ajustes-painel.html"],
    ["Vidro do painel", "Ajustes › Painel e dock", "ajustes-painel.html"], ["Música tocando no painel", "Ajustes › Painel e dock", "ajustes-painel.html"],
    ["Segundos no relógio", "Ajustes › Painel e dock", "ajustes-painel.html"], ["Janelas lado a lado", "Ajustes › Janelas e tela", "ajustes-janelas.html"],
    ["Tamanho da tela", "Ajustes › Janelas e tela", "ajustes-janelas.html"], ["Ponteiro do mouse", "Ajustes › Janelas e tela", "ajustes-janelas.html"],
    ["Nomes das áreas de trabalho", "Ajustes › Janelas e tela", "ajustes-janelas.html"], ["Próxima imagem", "Ajustes › Papel de parede", "ajustes-papel.html"],
    ["Troca de imagem a cada", "Ajustes › Papel de parede", "ajustes-papel.html"], ["Como a imagem ocupa a tela", "Ajustes › Papel de parede", "ajustes-papel.html"],
    ["Gato do dock", "Ajustes › Gato", "ajustes-gato.html"], ["Gato de dia e de noite", "Ajustes › Gato", "ajustes-gato.html"],
    ["Gato no terminal", "Ajustes › Gato", "ajustes-gato.html"], ["Horário da noite", "Ajustes › Dia e noite", "ajustes-dia-e-noite.html"],
    ["Modo de leitura", "Ajustes › Dia e noite", "ajustes-dia-e-noite.html"], ["Tela quente à noite", "Ajustes › Dia e noite", "ajustes-dia-e-noite.html"],
    ["Cores do terminal", "Ajustes › Terminal", "ajustes-terminal.html"], ["Linha colorida do terminal", "Ajustes › Terminal", "ajustes-terminal.html"],
    ["Programas que recebem o tema", "Ajustes › Programas", "ajustes-programas.html"], ["Esconder do lançador", "Ajustes › Programas", "ajustes-programas.html"],
    ["Jogos no lançador", "Ajustes › Programas", "ajustes-programas.html"], ["Conferir e consertar", "Cuidar", "cuidar.html"],
    ["Atualizar a máquina", "Cuidar", "cuidar.html"], ["Levar para outro computador", "Cuidar", "cuidar.html"], ["Desinstalar", "Cuidar", "cuidar.html"],
    ["Sino do volume", "Criar tema › Sons", "criar-sons.html"], ["Ícones dos apps", "Criar tema › Ícones", "criar-icones.html"],
    ["Mandar meu tema", "Criar tema › Mandar", "criar-publicar.html"]
  ];
  var busca = document.getElementById("busca"), achados = document.getElementById("achados");
  function procurar() {
    var q = busca.value.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    var r = INDICE.filter(function (x) { return !q || x[0].toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").indexOf(q) >= 0 || x[1].toLowerCase().indexOf(q) >= 0; }).slice(0, 7);
    achados.innerHTML = r.length ? r.map(function (x) { return '<a href="' + x[2] + '" role="option">' + x[0] + "<small>" + x[1] + "</small></a>"; }).join("")
      : '<p class="nada">Nada com esse nome. Tente "dock", "gato" ou "noite".</p>';
    busca.parentElement.classList.add("aberta");
  }
  if (busca) {
    busca.addEventListener("input", procurar);
    busca.addEventListener("focus", procurar);
    busca.addEventListener("blur", function () { setTimeout(function () { busca.parentElement.classList.remove("aberta"); }, 150); });
    document.addEventListener("keydown", function (ev) {
      if (ev.key === "/" && document.activeElement.tagName !== "INPUT") { ev.preventDefault(); busca.focus(); }
      if (ev.key === "Escape" && document.activeElement === busca) busca.blur();
    });
    if (corpo.dataset.buscaAberta) { busca.value = corpo.dataset.buscaAberta; setTimeout(procurar, 0); }
  }

  function sino(spec) {
    var v = spec.split(",").map(parseFloat);
    try {
      var A = new (window.AudioContext || window.webkitAudioContext)();
      [[v[0], v[2]], [v[1], v[3]]].forEach(function (par) {
        var o = A.createOscillator(), g = A.createGain();
        o.frequency.value = par[0]; o.type = "sine";
        g.gain.setValueAtTime(par[1] * 0.4, A.currentTime);
        g.gain.exponentialRampToValueAtTime(0.0001, A.currentTime + 4 / v[4] * 10);
        o.connect(g).connect(A.destination); o.start(); o.stop(A.currentTime + 1.2);
      });
    } catch (e) { }
  }

  function lum(hex) {
    var x = parseInt(hex.slice(1), 16), c = [(x >> 16) & 255, (x >> 8) & 255, x & 255].map(function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }
  function razao(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  var cp = document.getElementById("criar-previa");
  function medir() {
    var cores = {};
    document.querySelectorAll("input[data-cor]").forEach(function (i) { cores[i.dataset.cor] = i.value; });
    document.querySelectorAll("[data-contraste]").forEach(function (el) {
      var r = razao(cores[el.dataset.contraste], cores.base);
      var bom = r >= 4.5;
      el.className = "selo " + (bom ? "ok" : "erro");
      el.textContent = (bom ? "Lê bem · " : "Pouco contraste · ") + r.toFixed(1).replace(".", ",") + ":1";
    });
    var ruins = document.querySelectorAll("[data-contraste].erro").length;
    var av = document.getElementById("aviso-contraste");
    if (av) av.hidden = ruins === 0;
  }
  if (cp) {
    document.addEventListener("input", function (ev) {
      var i = ev.target;
      if (!i.dataset || !i.dataset.cor) return;
      var k = i.dataset.cor;
      var mapa = { base: ["--c-base"], paineis: ["--c-mantle", "--c-crust"], text: ["--c-text", "--c-subtext0"], accent: ["--c-mauve"], ok: ["--c-green"], erro: ["--c-red"] };
      (mapa[k] || []).forEach(function (v) { cp.style.setProperty(v, i.value); });
      if (k === "base") { cp.style.setProperty("--c-surface1", "color-mix(in oklab, " + i.value + " 78%, white)"); }
      var poco = i.closest(".poco"); if (poco) poco.style.setProperty("--cor", i.value);
      var hx = document.querySelector('[data-hex="' + k + '"]'); if (hx) hx.textContent = i.value.toUpperCase();
      medir();
    });
    document.addEventListener("click", function (ev) {
      var b = ev.target.closest("[data-comeca]");
      if (!b) return;
      var cores = JSON.parse(b.dataset.comeca);
      Object.keys(cores).forEach(function (k) {
        var i = document.querySelector('input[data-cor="' + k + '"]');
        if (i) { i.value = cores[k]; i.dispatchEvent(new Event("input", { bubbles: true })); }
      });
      cp.dataset.pack = b.dataset.base; previa(cp);
      b.parentElement.querySelectorAll("[data-comeca]").forEach(function (x) { x.setAttribute("aria-pressed", String(x === b)); });
    });
    medir();
  }

  vestir();
})();
