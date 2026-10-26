function pagina() {
  document.addEventListener("click", (e) => {
    const c = e.target.closest(".chave");
    if (c && !c.disabled) {
      const on = c.getAttribute("aria-checked") !== "true";
      c.setAttribute("aria-checked", String(on));
      const l = c.closest(".linha");
      anotar($(".rot span", l).textContent, on ? "não" : "sim", on ? "sim" : "não");
      const p = $(".padrao", l);
      if (p) p.hidden = String(on) === (c.dataset.padraoValor === "sim" ? "true" : "false");
      return;
    }
    const s = e.target.closest(".seg button");
    if (s) {
      const g = s.parentElement;
      const de = $("[aria-pressed='true']", g).textContent;
      for (const x of $$("button", g)) x.setAttribute("aria-pressed", String(x === s));
      anotar(g.getAttribute("aria-label"), de, s.textContent);
      return;
    }
    const v = e.target.closest(".padrao");
    if (v) {
      const l = v.closest(".linha");
      const c2 = $(".chave", l);
      if (c2) c2.setAttribute("aria-checked", String(c2.dataset.padraoValor === "sim"));
      v.hidden = true;
      anotar($(".rot span", l).textContent + " · padrão", "", "padrão");
    }
  });
  for (const r of $$("input[type=range]")) {
    r.addEventListener("input", () => {
      r.style.setProperty("--p", ((r.value - r.min) / (r.max - r.min) * 100) + "%");
      r.nextElementSibling.textContent = r.value;
    });
    r.addEventListener("change", () => anotar(r.getAttribute("aria-label"), r.defaultValue, r.value));
  }
  for (const s of $$("select.campo, input.campo")) s.addEventListener("change", () => anotar(s.getAttribute("aria-label"), s.dataset.antes || "", s.value));
  for (const a of $$(".faixa-estado a[href='#ponte']")) a.addEventListener("click", (e) => { e.preventDefault(); if (document.body.dataset.estado === "sem-ponte") semPonte(); });
}
