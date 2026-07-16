import "@fontsource/dm-serif-display/400.css";
import "@fontsource/jetbrains-mono/400.css";
import "@fontsource/jetbrains-mono/700.css";
import "@fontsource/space-grotesk/500.css";
import "@fontsource/space-grotesk/700.css";

import { render } from "preact";

import { FeedSample } from "./sample/FeedSample";
import "./styles/app.css";

const root = document.getElementById("app");

if (!root) {
  throw new Error("Missing #app mount point");
}

render(<FeedSample />, root);

