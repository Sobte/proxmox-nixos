{
  config,
  lib,
  pkgs,
  ...
}:

lib.mkIf config.services.proxmox-ve.enable {
  systemd.services = {
    # pve-lxc-syscalld is a separate binary from the pve-lxc-syscalld deb,
    # not packaged here. The container units only need /run/pve to exist,
    # which they create themselves via RuntimeDirectory below.

    "pve-container-debug@" = {
      # based on lxc@.service, but without an install section because
      # starting and stopping should be initiated by PVE code, not
      # systemd.
      description = "PVE LXC Container: %i";
      after = [ "lxc.service" ];
      wants = [ "lxc.service" ];
      unitConfig = {
        DefaultDependencies = false;
        Documentation = "man:lxc-start man:lxc man:pct";
      };
      serviceConfig = {
        Type = "simple";
        Delegate = true;
        KillMode = "mixed";
        TimeoutStopSec = 120;
        # The lxc hooks (lxc-pve-prestart-hook etc.) invoke bare binaries
        # (mount, umount, ip, ...) through PVE::Tools::run_command. Give them
        # the full system PATH plus iproute2 so those resolve on NixOS.
        Environment = "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:${pkgs.iproute2}/bin:${pkgs.util-linux}/bin:${pkgs.util-linux}/sbin:${pkgs.coreutils}/bin";
        ExecStart = "${pkgs.lxc}/bin/lxc-start -F -n %i -o /dev/stderr -l DEBUG";
        ExecStop = "${pkgs.pve-container}/share/lxc/pve-container-stop-wrapper %i";
        ExecStartPre = [ "+${pkgs.coreutils}/bin/mkdir -p /run/pve" ];
        # Environment=BOOTUP=serial
        # Environment=CONSOLETYPE=serial
        # Prevent container init from putting all its output into the journal
        StandardError = "file:/run/pve/ct-%i.stderr";
      };
    };

    "pve-container@" = {
      # based on lxc@.service, but without an install section because
      # starting and stopping should be initiated by PVE code, not
      # systemd.
      description = "PVE LXC Container: %i";
      after = [ "lxc.service" ];
      wants = [ "lxc.service" ];
      unitConfig = {
        DefaultDependencies = false;
        Documentation = "man:lxc-start man:lxc man:pct";
      };
      serviceConfig = {
        Type = "simple";
        Delegate = true;
        KillMode = "mixed";
        TimeoutStopSec = 120;
        # The lxc hooks (lxc-pve-prestart-hook etc.) invoke bare binaries
        # (mount, umount, ip, ...) through PVE::Tools::run_command. Give them
        # the full system PATH plus iproute2 so those resolve on NixOS.
        Environment = "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:${pkgs.iproute2}/bin:${pkgs.util-linux}/bin:${pkgs.util-linux}/sbin:${pkgs.coreutils}/bin";
        ExecStart = "${pkgs.lxc}/bin/lxc-start -F -n %i";
        ExecStop = "${pkgs.pve-container}/share/lxc/pve-container-stop-wrapper %i";
        ExecStartPre = [ "+${pkgs.coreutils}/bin/mkdir -p /run/pve" ];
        # Environment=BOOTUP=serial
        # Environment=CONSOLETYPE=serial
        # Prevent container init from putting all its output into the journal
        StandardError = "file:/run/pve/ct-%i.stderr";
      };
    };
  };
}
