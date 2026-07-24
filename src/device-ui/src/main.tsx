import "@fontsource/dm-serif-display/400.css";
import "@fontsource/jetbrains-mono/400.css";
import "@fontsource/jetbrains-mono/700.css";
import "@fontsource/space-grotesk/500.css";
import "@fontsource/space-grotesk/700.css";

import { render } from "preact";

import {
  fixtureChannelStoreState,
  MANAGED_CHANNEL_LIST,
  type ChannelStoreState,
} from "./shell/channelStore";
import {
  createChannelFeed,
  createGatewayClient,
  parseGatewayUrl,
} from "./shell/gateway";
import { ShellApp } from "./shell/ShellApp";
import "./styles/app.css";

const root = document.getElementById("app");

if (!root) {
  throw new Error("Missing #app mount point");
}

// P3 shell harness. ?bridge=0 disables P2 EventSource for pure keyboard dev.
const params = new URLSearchParams(window.location.search);
const bridgeUrl =
  params.get("bridge") === "0" ? null : "http://127.0.0.1:9137/v1/events";
const devKeyboardEnabled = params.get("keyboard") !== "0";

// W3-D: ?gateway=ws://host:port/path feeds live envelopes into the channel
// store and sends intents back; absent/invalid → fixture mode, unchanged.
const gatewayUrl = parseGatewayUrl(params.get("gateway"));
const gateway =
  gatewayUrl === null
    ? null
    : createGatewayClient({
        url: gatewayUrl,
        refreshOnOpen: MANAGED_CHANNEL_LIST,
      });

const renderShell = (channelState: ChannelStoreState) => {
  render(
    <ShellApp
      bridgeUrl={bridgeUrl}
      channelState={channelState}
      devKeyboardEnabled={devKeyboardEnabled}
      onIntent={gateway === null ? undefined : gateway.sendIntent}
    />,
    root,
  );
};

if (gateway === null) {
  renderShell(fixtureChannelStoreState);
} else {
  const feed = createChannelFeed(fixtureChannelStoreState, renderShell);
  gateway.subscribe(feed.push);
  renderShell(feed.current());
}
