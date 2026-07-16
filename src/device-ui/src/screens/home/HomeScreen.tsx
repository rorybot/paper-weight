import type { JSX } from "preact";

import { themeClassName, type ThemeName } from "../../design";
import { barGlyphs, formatMs, uvRatio, type HomeGlanceV1 } from "./model";
import "./home.css";

export type HomeScreenProps = Readonly<{
  glance: HomeGlanceV1;
  theme?: ThemeName;
}>;

/**
 * D1 home screen — button-hold target, read-only glance dashboard.
 * The frozen P3 router gives "home" no wheel-turn/wheel-press commands
 * (same as etymology), so there is no cursor/selection state here.
 */
export const HomeScreen = ({
  glance,
  theme = "gruvbox",
}: HomeScreenProps): JSX.Element => {
  const { nowPlaying, weather, feed, etymology, photo } = glance;

  return (
    <main
      class={`${themeClassName(theme)} hm-screen`}
      data-theme={theme}
      data-screen="home"
      style={{ width: "800px", height: "480px" }}
    >
      <header class="hm-topbar">
        <span>[cthing] · home</span>
        <nav class="hm-topbar__presets" aria-label="Presets">
          <span>1:np</span>
          <span>2:wx</span>
          <span>3:fd</span>
          <span>4:et</span>
        </nav>
        <span class="hm-topbar__clock">{glance.clockLabel}</span>
      </header>

      <div class="hm-grid">
        <div class="hm-tile" data-tile="now-playing" style={{ "--tile-accent": "var(--pw-accent)" }}>
          <div class="hm-tile__rule" />
          <p class="hm-tile__title">
            <span class="hm-bracket">[</span>
            <span class="hm-badge">1</span>
            <span class="hm-bracket">]</span> now playing
          </p>
          {nowPlaying ? (
            <>
              <div class="hm-hero">
                <p class="hm-hero-line">
                  {nowPlaying.title} — {nowPlaying.artist}
                </p>
                <p class="hm-bar">
                  <span class="hm-bar__fill">
                    {barGlyphs(nowPlaying.progressMs / nowPlaying.durationMs)}
                  </span>{" "}
                  {formatMs(nowPlaying.progressMs)}/{formatMs(nowPlaying.durationMs)}
                </p>
              </div>
              <p class="hm-foot">
                vol {nowPlaying.volumeLevel} {barGlyphs(nowPlaying.volumeLevel / 100)}
              </p>
            </>
          ) : (
            <div class="hm-hero">
              <p class="hm-hero-sub">nothing playing</p>
            </div>
          )}
        </div>

        <div class="hm-tile" data-tile="weather" style={{ "--tile-accent": "var(--pw-positive)" }}>
          <div class="hm-tile__rule" />
          <p class="hm-tile__title">
            <span class="hm-bracket">[</span>
            <span class="hm-badge">2</span>
            <span class="hm-bracket">]</span> weather
          </p>
          {weather ? (
            <>
              <div class="hm-hero">
                <p class="hm-hero-num">
                  {Math.round(weather.tempF)}
                  <small>&deg;f</small>
                </p>
                <p class="hm-hero-sub">
                  {weather.condition} &middot; {weather.walkNote}
                </p>
              </div>
              <p class="hm-foot">
                uv <span class="hm-bar__fill">{barGlyphs(uvRatio(weather.uvIndex), 5)}</span>{" "}
                {weather.uvGrade}
              </p>
            </>
          ) : (
            <div class="hm-hero">
              <p class="hm-hero-sub">no data</p>
            </div>
          )}
        </div>

        <div class="hm-tile" data-tile="feed" style={{ "--tile-accent": "var(--pw-accent-alt)" }}>
          <div class="hm-tile__rule" />
          <p class="hm-tile__title">
            <span class="hm-bracket">[</span>
            <span class="hm-badge">3</span>
            <span class="hm-bracket">]</span> feed
          </p>
          {feed ? (
            <>
              <div class="hm-hero">
                <p class="hm-hero-line">&ldquo;{feed.quote}&rdquo;</p>
                <p class="hm-hero-sub">{feed.handle}</p>
              </div>
              <p class="hm-foot">
                <span style={{ color: "var(--pw-accent)", fontWeight: 700 }}>
                  +{feed.newCount}
                </span>{" "}
                new since last look
              </p>
            </>
          ) : (
            <div class="hm-hero">
              <p class="hm-hero-sub">no data</p>
            </div>
          )}
        </div>

        <div class="hm-tile" data-tile="etymology" style={{ "--tile-accent": "var(--pw-positive)" }}>
          <div class="hm-tile__rule" />
          <p class="hm-tile__title">
            <span class="hm-bracket">[</span>
            <span class="hm-badge">4</span>
            <span class="hm-bracket">]</span> etymology
          </p>
          {etymology ? (
            <>
              <div class="hm-hero">
                <p class="hm-hero-line">{etymology.chain}</p>
                <div class="hm-dots">
                  {Array.from({ length: etymology.maxDepth }, (_, i) => (
                    <span
                      key={i}
                      class={i < etymology.depth ? "hm-dot--on" : undefined}
                    />
                  ))}
                  <span class="hm-dots__label">
                    depth {etymology.depth}/{etymology.maxDepth}
                  </span>
                </div>
              </div>
              <p class="hm-foot">word of the day</p>
            </>
          ) : (
            <div class="hm-hero">
              <p class="hm-hero-sub">no data</p>
            </div>
          )}
        </div>

        <div
          class="hm-tile hm-tile--wide"
          data-tile="photo"
          style={{ "--tile-accent": "color-mix(in srgb, var(--pw-paper) 55%, transparent)" }}
        >
          <div class="hm-tile__rule" />
          <p class="hm-tile__title">
            <span class="hm-bracket">[</span>
            <span class="hm-badge hm-badge--dim">&middot;</span>
            <span class="hm-bracket">]</span> photo
          </p>
          {photo ? (
            <>
              <div class="hm-hero">
                <p class="hm-hero-num">
                  {photo.index}
                  <small>/{photo.total}</small>
                </p>
              </div>
              <p class="hm-foot">
                reprint <span class="hm-bar__fill">{barGlyphs(photo.reprintRatio)}</span>{" "}
                {photo.reprintLabel} &middot; not on presets
              </p>
            </>
          ) : (
            <div class="hm-hero">
              <p class="hm-hero-sub">no data</p>
            </div>
          )}
        </div>
      </div>

      <footer class="hm-footer">
        <span>
          <b>1&ndash;4</b> switch screen
        </span>
        <span>
          already home &middot; <b>hold</b> is a no-op here
        </span>
        <span>konami &rarr; settings</span>
      </footer>
    </main>
  );
};
