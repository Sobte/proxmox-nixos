{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.services.proxmox-ve;
in

{
  meta.maintainers = with maintainers; [
    julienmalka
    camillemndn
  ];

  imports = [
    ./ceph.nix
    ./bridges.nix
    ./cluster.nix
    ./container.nix
    # ./firewall.nix
    # ./ha-manager.nix
    ./linstor.nix
    ./manager.nix
    ./qemu-server.nix
    ./rrdcached.nix
    ./vms.nix
  ];

  options.services.proxmox-ve = {
    enable = mkEnableOption "Proxmox VE";

    package = mkPackageOption pkgs "proxmox-ve" { };

    ipAddress = lib.mkOption {
      type = lib.types.str;
      description = ''
        The IP address used to reach this Proxmox node from outside, added to "/etc/hosts" file.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open port in firewall for proxmox-admin (8006), rpcbind (111) and http(s) (80,443)
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      boot.supportedFilesystems = [
        "fuse"
        "glusterfs"
      ];

      networking.hosts = {
        "127.0.0.2" = lib.mkForce [ ];
        "::1" = lib.mkForce [ ];
        "${cfg.ipAddress}" = [ config.networking.hostName ];
      };

      # create the /etc/network/interfaces file for proxmox
      systemd.tmpfiles.rules = [
        "d /etc/network 0755 root root -"
        "f /etc/network/interfaces 0755 root root -"
      ];

      services.openssh = {
        enable = true;
        settings.AcceptEnv = if lib.versionAtLeast pkgs.lib.version "26.05pre-git" then ["LANG" "LC_*"] else "LANG LC_*";
      };
      programs.ssh.extraConfig = ''
        Host *
          SendEnv LANG LC_*
      '';

      security.pam.services."proxmox-ve-auth" = {
        logFailures = true;
        nodelay = true;
      };

      services.rpcbind.enable = true;
      services.rrdcached.enable = true;

      users.users.www-data = {
        isSystemUser = true;
        group = "www-data";
      };
      users.groups.www-data = { };

      # Unprivileged containers map their root to the 100000..165535 id
      # range via newuidmap/newgidmap. Native PVE configures this in its
      # postinst; do the same here so containers can start without extra
      # per-node configuration.
      users.users.root = {
        subUidRanges = [
          {
            startUid = 100000;
            count = 65536;
          }
        ];
        subGidRanges = [
          {
            startGid = 100000;
            count = 65536;
          }
        ];
      };

      environment.systemPackages = [
        cfg.package
        # pct/pve-container invoke lxc-start/lxc-info/lxc-attach/... as
        # bare commands resolved from PATH.
        pkgs.lxc
      ];
      environment.etc.issue.enable = false;

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [
          80
          111
          443
          8006
        ];
        allowedUDPPorts = [ 111 ];
        allowedUDPPortRanges = [
          {
            from = 5405;
            to = 5412;
          }
        ];
      };
    }
  ]);
}
