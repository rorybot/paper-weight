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

  # tty1 belongs to the kiosk compositor. The upstream getty definition can be
  # re-enabled during a switch, which conflicts with and stops Weston.
  systemd.services."autovt@tty1".wantedBy = lib.mkForce [ ];
  systemd.services.weston-tty1.conflicts = [ "getty@tty1.service" ];
}
