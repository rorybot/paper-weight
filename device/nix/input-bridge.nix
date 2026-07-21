{ lib, pkgs, ... }:

let
  inputBridge = pkgs.rustPlatform.buildRustPackage {
    pname = "paper-weight-input-bridge";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ../../src/input-bridge;
      fileset = lib.fileset.unions [
        ../../src/input-bridge/Cargo.lock
        ../../src/input-bridge/Cargo.toml
        ../../src/input-bridge/src
        ../../src/input-bridge/tests
      ];
    };

    cargoLock.lockFile = ../../src/input-bridge/Cargo.lock;
  };

  inputBridgeConfig = ./input-bridge.conf;
in
{
  environment.etc."paper-weight/input-bridge.conf".source = inputBridgeConfig;
  environment.systemPackages = [ inputBridge ];
  system.build.paperWeightInputBridge = inputBridge;

  users.groups.paper-weight = { };
  users.users.paper-weight = {
    isSystemUser = true;
    group = "paper-weight";
    extraGroups = [ "input" ];
  };

  systemd.services.input-bridge = {
    description = "Paper Weight Car Thing input bridge";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    before = [ "weston-tty1.service" ];

    serviceConfig = {
      Type = "simple";
      User = "paper-weight";
      Group = "paper-weight";
      SupplementaryGroups = [ "input" ];
      ExecStart = "${inputBridge}/bin/input_bridge --config ${inputBridgeConfig}";
      Restart = "always";
      RestartSec = "1s";
      NoNewPrivileges = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
    };
  };

  # #111: libinput classifies the rotary encoder (relative wheel axis) as a
  # pointer device, which gives the Weston seat pointer capability — turning
  # the dial "moves" the pointer and Chromium draws a cursor over the kiosk
  # (weston.ini cursor-size=0 only affects the shell's own sprite, not the one
  # a client sets). The bridge reads event0/event1 raw via evdev, so libinput
  # consumers never need these nodes; ignoring them removes pointer capability
  # from the seat entirely, so no cursor can appear and the dial stops
  # double-delivering as scroll into Chromium.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event0", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event1", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

  # tty1 belongs to the kiosk compositor. The upstream getty definition can be
  # re-enabled during a switch, which conflicts with and stops Weston.
  systemd.services."autovt@tty1".wantedBy = lib.mkForce [ ];
  systemd.services.weston-tty1.conflicts = [ "getty@tty1.service" ];
}
