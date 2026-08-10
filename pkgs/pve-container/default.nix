{
  lib,
  stdenv,
  fetchgit,
  perl5,
  dtach,
  iproute2,
  lxc,
  openssh,
  termproxy,
  tzdata,
  vncterm,
  pve-common,
  pve-cluster,
  pve-firewall,
  pve-guest-common,
  pve-storage,
  pve-update-script,
}:

let
  perlDeps = [
    pve-common
    pve-cluster
    pve-firewall
    pve-guest-common
    pve-storage
  ];
  perlEnv = perl5.withPackages (_: perlDeps);
in

perl5.pkgs.toPerlModule (
  stdenv.mkDerivation rec {
    pname = "pve-container";
    version = "6.1.13";

    src = fetchgit {
      url = "git://git.proxmox.com/git/${pname}.git";
      rev = "c8132559faedb76a56498d411bf3e024c1ff07e7";
      hash = "sha256-hYKInUR414O6tMjfboiH9iGelZA/zmjzwf94k8rvBus=";
    };

    sourceRoot = "${src.name}/src";

    postPatch = ''
      sed -i Makefile \
        -e "s/pct.1 pct.conf.5 pct.bash-completion pct.zsh-completion //" \
        -e "s,/usr/share/lxc,$NIX_BUILD_TOP/lxc," \
        -e "/pve-doc-generator/d" \
        -e "/PVE_GENERATING_DOCS/d" \
        -e "/SERVICEDIR/d" \
        -e "/BASHCOMPLDIR/d" \
        -e "/ZSHCOMPLDIR/d" \
        -e "/MAN1DIR/d" \
        -e "/MAN5DIR/d"
    '';

    buildInputs = [ perlEnv ];
    propagatedBuildInputs = perlDeps;
    dontPatchShebangs = true;

    postConfigure = ''
      cp -r ${lxc}/share/lxc $NIX_BUILD_TOP/
      chmod -R +w $NIX_BUILD_TOP/lxc
    '';

    makeFlags = [
      "DESTDIR=$(out)"
      "PREFIX=$(out)"
      "SBINDIR=$(out)/.bin"
      "PERLDIR=$(out)/${perl5.libPrefix}/${perl5.version}"
    ];

    postFixup = ''
      # The lxc hooks (lxc-pve-prestart-hook etc.) and the net/stop wrapper
      # scripts are perl scripts invoked by lxc directly. On NixOS /usr/bin/perl
      # does not exist, so rewrite their shebangs to the perl env carrying the
      # full PVE perl dependency closure.
      for f in $out/share/lxc/hooks/* $out/share/lxc/lxcnetaddbr $out/share/lxc/pve-container-stop-wrapper; do
        sed -i "1s|^#\!/usr/bin/perl|#\!${perlEnv}/bin/perl|" "$f"
        # The hook's own modules (PVE::LXC) live in this store path, which the
        # perlEnv wrapper does not know about. Point @INC at them explicitly.
        sed -i "2i use lib '$out/${perl5.libPrefix}/${perl5.version}';" "$f"
      done
      # PVE::LXC reads common.seccomp next to pve-userns.seccomp when merging
      # seccomp rules (src/PVE/LXC.pm:622) and includes common.conf/userns.conf
      # when generating container configs (src/PVE/LXC.pm:740-745). Those files
      # ship with lxc, not pve-container. Copy them in so pct works.
      cp ${lxc}/share/lxc/config/common.seccomp $out/share/lxc/config/
      cp ${lxc}/share/lxc/config/common.conf $out/share/lxc/config/
      cp ${lxc}/share/lxc/config/userns.conf $out/share/lxc/config/
      cp ${lxc}/share/lxc/config/nesting.conf $out/share/lxc/config/
      # lxc patches its own config paths to /run/current-system/sw/share (only
      # valid when installed via systemPackages). Point them at our copy.
      substituteInPlace $out/share/lxc/config/common.conf \
        --replace-fail "/run/current-system/sw/share" "$out/share"
      find $out -type f | xargs sed -i \
        -e "s|/usr/bin/dtach|${dtach}/bin/dtach|" \
        -e "s|/usr/bin/ssh|${openssh}/bin/ssh|" \
        -e "s|/bin/true|true|" \
        -e "s|/usr/bin/vncterm|${vncterm}/bin/vncterm|" \
        -e "s|/usr/bin/termproxy|${termproxy}/bin/termproxy|" \
        -e "s|/usr/bin/lxc|${lxc}/bin/lxc|" \
        -e "s|/sbin/ip|${iproute2}/bin/ip|" \
        -e "s|/usr/share/lxc|$out/share/lxc|" \
        -e "s|/usr/share/zoneinfo|${tzdata}/share/zoneinfo|"
    '';

    passthru.updateScript = pve-update-script { };

    meta = with lib; {
      description = "Proxmox VE container manager & runtime";
      homepage = "https://git.proxmox.com/?p=pve-container.git";
      license = licenses.agpl3Plus;
      maintainers = with maintainers; [
        camillemndn
        julienmalka
      ];
      platforms = platforms.linux;
    };
  }
)
