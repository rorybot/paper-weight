import type { JSX } from "preact";
import { useEffect, useMemo, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type { PhotoSnapshotV1 } from "../../protocol/photo";
import {
  keepLabel,
  skipLabel,
  statusLine,
  type PhotoUiCommand,
} from "./model";
import { pbmBase64ToDataUrl } from "./pbm";
import "./photo.css";

export type PhotoScreenProps = Readonly<{
  snapshot: PhotoSnapshotV1;
  /** BERG is the mockup target for 4g. */
  theme?: ThemeName;
  /**
   * Shell commands: `skip-photo` / `keep-photo-on-show`.
   * Presentational: parent updates `snapshot` (host H1). Tests assert labels.
   */
  command?: PhotoUiCommand | null;
  onCommand?: (command: PhotoUiCommand) => void;
}>;

export const PhotoScreen = ({
  snapshot,
  theme = "berg",
  command = null,
  onCommand,
}: PhotoScreenProps): JSX.Element => {
  // Re-emit command to parent once (wave-3 / harness). Screen stays pure on snapshot.
  const [lastCmd, setLastCmd] = useState<PhotoUiCommand | null>(null);
  useEffect(() => {
    if (!command || command === lastCmd) return;
    setLastCmd(command);
    onCommand?.(command);
  }, [command, lastCmd, onCommand]);

  const artSrc = useMemo(
    () => pbmBase64ToDataUrl(snapshot.art_pbm_base64),
    [snapshot.art_pbm_base64],
  );

  const meta = statusLine(snapshot);
  const keep = keepLabel(snapshot.kept);

  return (
    <main
      class={`${themeClassName(theme)} ph-screen`}
      data-theme={theme}
      data-screen="photo"
      data-stale={String(snapshot.stale)}
      data-empty={String(snapshot.empty)}
      data-kept={String(snapshot.kept)}
      data-index={String(snapshot.index)}
      data-total={String(snapshot.total)}
      data-photo-id={snapshot.id ?? ""}
      style={{ width: "800px", height: "480px" }}
    >
      <header class="ph-topbar">
        <span>[cthing]</span>
        <nav class="ph-topbar__presets" aria-label="Presets">
          <span>1:np</span>
          <span>2:pl</span>
          <span>3:wx</span>
          <span>4:fd</span>
        </nav>
        <span class="ph-topbar__quote">reprints for the desk</span>
      </header>

      <section class="ph-main" aria-label="Photo frame">
        <article
          class="ph-frame"
          data-tone="paper"
          data-kept={String(snapshot.kept)}
        >
          <div class="ph-frame__slot">
            {artSrc ? (
              <img
                class="ph-frame__art"
                src={artSrc}
                alt={snapshot.caption || "photo"}
                width={200}
                height={150}
                data-art="true"
                draggable={false}
              />
            ) : (
              <p class="ph-frame__empty" data-art="false">
                {snapshot.empty
                  ? "drop photos into the library"
                  : "dither pending · path only"}
              </p>
            )}
          </div>

          <p class="ph-frame__caption">{snapshot.caption || "—"}</p>

          <p class="ph-frame__meta" data-status="true">
            {meta}
            {snapshot.kept ? (
              <span class="ph-frame__pin" data-kept="true">
                keep
              </span>
            ) : null}
          </p>
        </article>
      </section>

      <footer class="ph-footer">
        <span>{skipLabel()}</span>
        <span data-active={String(snapshot.kept)}>{keep}</span>
        <span>{snapshot.source}</span>
      </footer>
    </main>
  );
};
