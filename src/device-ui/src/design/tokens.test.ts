import { describe, expect, it } from "vitest";

import { designTokens, themeClassName } from "./tokens";

describe("design tokens", () => {
  it("locks the Car Thing viewport and minimum text size", () => {
    expect(designTokens.berg.geometry.viewport).toBe("800px 480px");
    expect(designTokens.berg.geometry.minimumText).toBe("13px");
  });

  it("keeps the gruvbox fallback available without mutating BERG", () => {
    expect(themeClassName("gruvbox")).toBe("theme-gruvbox");
    expect(designTokens.gruvbox.colors.desk).toBe("#282828");
    expect(designTokens.berg.colors.desk).toBe("#1b1d18");
    expect(Object.isFrozen(designTokens.gruvbox.colors)).toBe(true);
  });
});

