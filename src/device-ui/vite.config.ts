import preact from "@preact/preset-vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  // GitHub Pages project site: set GITHUB_PAGES=true in the deploy workflow.
  base: process.env.GITHUB_PAGES === "true" ? "/paper-weight/" : "/",
  plugins: [preact(), tailwindcss()],
  build: {
    target: "chrome100",
  },
});

