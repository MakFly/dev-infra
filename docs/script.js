const navToggle = document.querySelector(".nav-toggle");
const siteNav = document.querySelector(".site-nav");

if (navToggle && siteNav) {
  navToggle.addEventListener("click", () => {
    const isOpen = siteNav.classList.toggle("is-open");
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });

  siteNav.addEventListener("click", (event) => {
    if (event.target instanceof HTMLAnchorElement) {
      siteNav.classList.remove("is-open");
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
