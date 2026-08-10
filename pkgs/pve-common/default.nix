{
  lib,
  stdenv,
  fetchgit,
  fetchurl,
  bash,
  coreutils,
  diffutils,
  dpkg,
  iproute2,
  perl5,
  glibc,
  openvswitch,
  pciutils,
  proxmox-backup-client,
  systemd,
  tzdata,
  usbutils,
  mimebase32,
  mimebase64,
  replaceVars,
  pve-update-script,
}:

let
  # nixpkgs still ships Crypt-OpenSSL-RSA 0.35 which disabled PKCS#1 v1.5
  # padding entirely (CVE-2024-2467 / Marvin attack), breaking the signature
  # path used by PVE::ACME (RS256 JWS) and PVE::Ticket. 0.38+ re-enabled
  # PKCS#1 v1.5 for sign()/verify() while keeping it disabled for decrypt().
  # See https://github.com/SaumonNet/proxmox-nixos/pull/225
  perl5_ = perl5.override {
    overrides = _: {
      CryptOpenSSLRSA = perl5.pkgs.CryptOpenSSLRSA.overrideAttrs (_old: {
        version = "0.41";
        src = fetchurl {
          url = "https://cpan.metacpan.org/authors/id/T/TI/TIMLEGGE/Crypt-OpenSSL-RSA-0.41.tar.gz";
          sha256 = "08k86v1hg8ylz98q2yjcmsf8gg6k4szg6rb2bcj9r3mqjyc87yl2";
        };
        propagatedBuildInputs = (_old.propagatedBuildInputs or [ ]) ++ [
          perl5.pkgs.CryptOpenSSLBignum
        ];
        doCheck = false;
      });
    };
  };

  perlDeps = with perl5_.pkgs; [
    AnyEvent
    Carp
    Clone
    CryptOpenSSLRSA
    CryptOpenSSLBignum
    CryptOpenSSLRandom
    PathTools
    DataDumper
    TimeDate
    DevelCycle
    #DigestMD5
    DigestSHA
    Encode
    EncodeLocale
    #Exporter
    FilePath
    #FileTemp
    FilesysDf
    GetoptLong
    HTTPMessage
    IOStringy
    IO
    IOSocketIP
    JSON
    #libwwwperl
    LinuxInotify2
    LWPProtocolHttps
    ScalarListUtils
    mimebase32
    mimebase64
    NetDBus
    NetIP
    perlldap
    NetSSLeay
    NetAddrIP
    Socket
    #Storable
    StringShellQuote
    SysSyslog
    TextParsewords
    #TextTabsWrap
    TimeHiRes
    TimeLocal
    URI
    YAMLLibYAML
  ];
in

perl5.pkgs.toPerlModule (
  stdenv.mkDerivation rec {
    pname = "pve-common";
    version = "9.2.1";

    src = fetchgit {
      url = "git://git.proxmox.com/git/${pname}.git";
      rev = "f665029eac78022e81810ab2e44eace57ade13fb";
      hash = "sha256-dbx62D2ePcmSp1TiGVqQ0cdhOdJ7LwP4ZM/vAaXUAfA=";
    };

    sourceRoot = "${src.name}/src";

    patches = [
      (replaceVars ./0001-ss_fix_path.patch {
        sspath = "${iproute2}/bin/";
      })

      (replaceVars ./0003-pci-id-path.patch {
        pciutils = "${pciutils}";
      })
    ];

    propagatedBuildInputs = [
      bash
      coreutils
      diffutils
      dpkg
      iproute2
      proxmox-backup-client
      systemd
      usbutils
    ]
    ++ perlDeps;

    makeFlags = [
      "PREFIX=$(out)"
      "PERLDIR=$(out)/${perl5.libPrefix}/${perl5.version}"
    ];

    postInstall =
      let
        includeHeaders =
          "{sys,bits,}/syscall.h "
          + (
            if (stdenv.buildPlatform.system == "x86_64-linux") then
              "asm/unistd{,_64}.h"
            else
              "asm{,-generic}/{unistd,bitsperlong}.h"
          );
      in
      ''
        for h in ${includeHeaders}; do
          ${perl5}/bin/h2ph -d $out ${glibc.dev}/include/$h
          mkdir -p $out/include/$(dirname $h)
          mv $out${glibc.dev}/include/''${h%.h}.ph $out/include/$(dirname $h)
        done
        mv $out/_h2ph_pre.ph $out/include
        cp -r $out/include/* $out/${perl5.libPrefix}/${perl5.version}
        rm -r $out/{nix,include}
      '';

    postFixup = ''
      find $out/lib -type f | xargs sed -i \
        -e "/ENV{'PATH'}/d" \
        -e "s|ovs-vsctl|${openvswitch}/bin/ovs-vsctl|" \
        -e "s|/usr/share/zoneinfo|${tzdata}/share/zoneinfo|" \
        -Ee "s|(/usr)?/s?bin/||"

      substituteInPlace $out/${perl5.libPrefix}/${perl5.version}/PVE/Tools.pm \
        --replace-fail "['dpkg', '--print-architecture']" \
        "['${dpkg}/bin/dpkg', '--print-architecture']"
    '';

    passthru.updateScript = pve-update-script {
      extraArgs = [
        "--deb-name"
        "libpve-common-perl"
      ];
    };

    meta = with lib; {
      description = "Proxmox Project's Common Perl Code";
      homepage = "https://git.proxmox.com/?p=pve-common.git";
      license = licenses.agpl3Plus;
      maintainers = with maintainers; [
        camillemndn
        julienmalka
      ];
      platforms = platforms.linux;
    };
  }
)
