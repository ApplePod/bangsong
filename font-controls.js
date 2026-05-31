(function () {
  const KEY = "writingDiagFontSizeMode";
  const body = document.body;

  const applyMode = (mode) => {
    body.classList.remove("font-size-large");
    if (mode === "large") body.classList.add("font-size-large");
  };

  const saved = localStorage.getItem(KEY) || "large";
  applyMode(saved);

  const wrap = document.createElement("div");
  wrap.className = "font-control";

  const smallBtn = document.createElement("button");
  smallBtn.className = "small";
  smallBtn.type = "button";
  smallBtn.textContent = "가";
  smallBtn.setAttribute("aria-label", "기본 글자 크기");

  const largeBtn = document.createElement("button");
  largeBtn.className = "large";
  largeBtn.type = "button";
  largeBtn.textContent = "가";
  largeBtn.setAttribute("aria-label", "큰 글자 크기");

  const syncActive = (mode) => {
    smallBtn.classList.toggle("active", mode !== "large");
    largeBtn.classList.toggle("active", mode === "large");
  };

  const setMode = (mode) => {
    localStorage.setItem(KEY, mode);
    applyMode(mode);
    syncActive(mode);
  };

  smallBtn.addEventListener("click", () => setMode("default"));
  largeBtn.addEventListener("click", () => setMode("large"));

  syncActive(saved);
  wrap.appendChild(smallBtn);
  wrap.appendChild(largeBtn);
  document.body.appendChild(wrap);
})();
