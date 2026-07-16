import "@fontsource/dm-serif-display/400.css";
import "@fontsource/jetbrains-mono/400.css";
import "@fontsource/jetbrains-mono/700.css";
import "@fontsource/space-grotesk/500.css";
import "@fontsource/space-grotesk/700.css";

import { render } from "preact";

import { ShellApp } from "./shell/ShellApp";
import "./styles/app.css";

const root = document.getElementById("app");

if (!root) {
  throw new Error("Missing #app mount point");
}

// P3 shell harness (P4 FeedSample still renders on preset 4 / feed).
// ?bridge=0 disables P2 EventSource for pure keyboard dev.
const params = new URLSearchParams(window.location.search);
const bridgeUrl =
  params.get("bridge") === "0" ? null : "http://127.0.0.1:9137/v1/events";

render(<ShellApp bridgeUrl={bridgeUrl} />, root);
