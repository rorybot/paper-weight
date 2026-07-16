import type { ComponentChildren, JSX } from "preact";

export type CardTone = "paper" | "dark";

export type CardProps = Readonly<{
  children: ComponentChildren;
  className?: string;
  eyebrow?: string;
  footer?: ComponentChildren;
  selected?: boolean;
  tone?: CardTone;
}>;

export const joinClassNames = (
  ...classNames: ReadonlyArray<string | false | null | undefined>
): string => classNames.filter(Boolean).join(" ");

export const Card = ({
  children,
  className,
  eyebrow,
  footer,
  selected = false,
  tone = "paper",
}: CardProps): JSX.Element => (
  <article
    class={joinClassNames(
      "berg-card relative min-h-[13px]",
      `berg-card--${tone}`,
      selected && "berg-card--selected",
      className,
    )}
    data-selected={String(selected)}
    data-tone={tone}
  >
    {eyebrow ? <p class="berg-card__eyebrow">{eyebrow}</p> : null}
    <div class="berg-card__body">{children}</div>
    {footer ? <footer class="berg-card__footer">{footer}</footer> : null}
  </article>
);

