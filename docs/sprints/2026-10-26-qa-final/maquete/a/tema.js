const PALETAS = {
  latte: ["#EFF1F5", "#E6E9EF", "#DCE0E8", "#4C4F69", "#8839EF"],
  frappe: ["#303446", "#292C3C", "#232634", "#C6D0F5", "#CA9EE6"],
  macchiato: ["#24273A", "#1E2030", "#181926", "#CAD3F5", "#C6A0F6"],
  mocha: ["#1E1E2E", "#181825", "#11111B", "#CDD6F4", "#CBA6F7"],
  dracula: ["#282A36", "#21222C", "#191A21", "#F8F8F2", "#BD93F9"],
  alucard: ["#F0F0F6", "#E8E9F1", "#DEE0EA", "#4A4F67", "#853AF2"],
};

function pintarPrevia(previa, flavor) {
  const [b, m, c, t, a] = PALETAS[flavor];
  previa.style.setProperty("--p-base", b);
  previa.style.setProperty("--p-mantle", m);
  previa.style.setProperty("--p-crust", c);
  previa.style.setProperty("--p-text", t);
  previa.style.setProperty("--p-acc", a);
}
function porNoAr(cartao) {
  for (const p of $$(".pack")) {
    const noAr = p === cartao;
    p.classList.toggle("no-ar", noAr);
    const fila = $(".pack-corpo > .fila", p);
    const nome = $("h2", p).textContent;
    fila.innerHTML = noAr
      ? '<span class="estado-no-ar" role="img" aria-label="No ar"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg></span>'
      : `<button type="button" class="bt principal" data-root data-titulo="Vestir o ${nome}">Vestir</button>`;
    const b = $("button", fila);
    if (b) b.addEventListener("click", () => vestir(p, b));
  }
}
function vestir(cartao, botao) {
  if (document.body.dataset.estado === "sem-ponte") { semPonte(); return; }
  const flavor = $(".variantes [aria-pressed='true']", cartao).dataset.flavor;
  abrirTrabalho(`Vestir o ${$("h2", cartao).textContent} ${$(`[data-flavor="${flavor}"]`, cartao).textContent}`, { erro: document.body.dataset.estado === "erro", restauravel: true });
  porNoAr(cartao);
}

function pagina() {
  porNoAr($(".pack.no-ar"));
  for (const v of $$(".variantes button")) {
    v.addEventListener("click", () => {
      const cartao = v.closest(".pack");
      for (const x of $$("button", v.parentElement)) x.setAttribute("aria-pressed", String(x === v));
      pintarPrevia($(".previa", cartao), v.dataset.flavor);
      if (cartao.classList.contains("no-ar")) vestir(cartao);
    });
  }
  for (const p of $$(".pack .previa")) p.addEventListener("click", () => { const c = p.closest(".pack"); if (!c.classList.contains("no-ar")) vestir(c); });
  for (const b of $$(".cores[data-chave='ACCENT'] button")) {
    b.addEventListener("click", () => {
      const de = $(".cores [aria-pressed='true']").dataset.valor;
      for (const x of $$(".cores[data-chave='ACCENT'] button")) x.setAttribute("aria-pressed", String(x === b));
      document.documentElement.style.setProperty("--accent", `var(--${b.dataset.valor})`);
      for (const p of $$(".pack.no-ar .previa")) p.style.setProperty("--p-acc", `var(--${b.dataset.valor})`);
      anotar("Cor de destaque", de, b.dataset.valor);
    });
  }
  for (const b of $$(".seg[data-chave='MODO'] button")) {
    b.addEventListener("click", () => {
      const de = $(".seg[data-chave='MODO'] [aria-pressed='true']").textContent;
      for (const x of $$("button", b.parentElement)) x.setAttribute("aria-pressed", String(x === b));
      anotar("Claro ou escuro", de, b.textContent);
    });
  }
}
