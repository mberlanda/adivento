/* Adivento DS — React theme layer
   Mirrors adivento.js: data-theme on <html> + localStorage, transition freeze.
   Pair with assets/tokens.css + application.css + components.css (import once). */
import { createContext, useContext, useEffect, useState, useCallback } from "react";

const THEME_KEY = "adv-theme";
const ThemeCtx = createContext({ theme: "light", setTheme: () => {}, toggle: () => {} });

export function ThemeProvider({ defaultTheme = "light", children }) {
  const [theme, setThemeState] = useState(() => {
    if (typeof localStorage !== "undefined") {
      const saved = localStorage.getItem(THEME_KEY);
      if (saved) return saved;
    }
    return defaultTheme;
  });

  const apply = useCallback((name) => {
    const root = document.documentElement;
    root.classList.add("adv-theming");
    root.setAttribute("data-theme", name);
    try { localStorage.setItem(THEME_KEY, name); } catch (e) {}
    requestAnimationFrame(() => requestAnimationFrame(() => root.classList.remove("adv-theming")));
  }, []);

  useEffect(() => { apply(theme); }, [theme, apply]);

  const setTheme = useCallback((name) => setThemeState(name), []);
  const toggle = useCallback(() => setThemeState((t) => (t === "dark" ? "light" : "dark")), []);

  return <ThemeCtx.Provider value={{ theme, setTheme, toggle }}>{children}</ThemeCtx.Provider>;
}

export const useTheme = () => useContext(ThemeCtx);

export function ThemeToggle({ className = "adv-btn adv-btn--ghost adv-btn--sm" }) {
  const { theme, toggle } = useTheme();
  return (
    <button className={className} onClick={toggle} aria-pressed={theme === "dark"} aria-label="Toggle theme">
      ◑ {theme === "dark" ? "Dark" : "Light"}
    </button>
  );
}
