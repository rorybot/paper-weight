export type ThemeName = "berg" | "gruvbox";

type ThemeTokens = Readonly<{
  colors: Readonly<{
    desk: string;
    surface: string;
    paper: string;
    ink: string;
    muted: string;
    accent: string;
    accentAlt: string;
    positive: string;
  }>;
  fonts: Readonly<{
    display: string;
    mono: string;
    sans: string;
  }>;
  geometry: Readonly<{
    viewport: string;
    outline: string;
    shadow: string;
    radius: string;
    minimumText: string;
  }>;
}>;

const defineTheme = (tokens: ThemeTokens): ThemeTokens =>
  Object.freeze({
    colors: Object.freeze({ ...tokens.colors }),
    fonts: Object.freeze({ ...tokens.fonts }),
    geometry: Object.freeze({ ...tokens.geometry }),
  });

export const designTokens = Object.freeze({
  berg: defineTheme({
    colors: {
      desk: "#1b1d18",
      surface: "#242620",
      paper: "#f3ecd9",
      ink: "#20211d",
      muted: "#8c8778",
      accent: "#f2bd1d",
      accentAlt: "#dc8fa5",
      positive: "#899b5d",
    },
    fonts: {
      display: '"DM Serif Display", Georgia, serif',
      mono: '"JetBrains Mono", Consolas, monospace',
      sans: '"Space Grotesk", Arial, sans-serif',
    },
    geometry: {
      viewport: "800px 480px",
      outline: "3px",
      shadow: "6px 6px 0",
      radius: "10px",
      minimumText: "13px",
    },
  }),
  gruvbox: defineTheme({
    colors: {
      desk: "#282828",
      surface: "#3c3836",
      paper: "#ebdbb2",
      ink: "#282828",
      muted: "#928374",
      accent: "#fabd2f",
      accentAlt: "#d3869b",
      positive: "#b8bb26",
    },
    fonts: {
      display: '"DM Serif Display", Georgia, serif',
      mono: '"JetBrains Mono", Consolas, monospace',
      sans: '"Space Grotesk", Arial, sans-serif',
    },
    geometry: {
      viewport: "800px 480px",
      outline: "3px",
      shadow: "6px 6px 0",
      radius: "0px",
      minimumText: "13px",
    },
  }),
} satisfies Readonly<Record<ThemeName, ThemeTokens>>);

export const themeClassName = (theme: ThemeName): string => `theme-${theme}`;

