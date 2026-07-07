const navToggle = document.querySelector(".nav-toggle");
const siteNav = document.querySelector(".site-nav");

if (navToggle && siteNav) {
  navToggle.addEventListener("click", () => {
    siteNav.classList.toggle("hidden");
    siteNav.classList.toggle("flex");
    const isOpen = siteNav.classList.contains("flex");
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });

  siteNav.addEventListener("click", (event) => {
    if (event.target instanceof HTMLAnchorElement) {
      siteNav.classList.add("hidden");
      siteNav.classList.remove("flex");
      navToggle.setAttribute("aria-expanded", "false");
    }
  });
}

document.querySelectorAll("pre").forEach((pre) => {
  const code = pre.querySelector("code");
  if (!code) return;

  const button = document.createElement("button");
  button.className = "copy-button";
  button.type = "button";
  button.textContent = "Copier";
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(code.innerText);
      button.textContent = "Copie";
      setTimeout(() => {
        button.textContent = "Copier";
      }, 1200);
    } catch {
      button.textContent = "Erreur";
      setTimeout(() => {
        button.textContent = "Copier";
      }, 1200);
    }
  });
  pre.appendChild(button);
});
