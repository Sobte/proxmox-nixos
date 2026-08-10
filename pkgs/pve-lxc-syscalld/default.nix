{
  lib,
  fetchgit,
  rustPlatform,
  systemdLibs,
  pve-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "pve-lxc-syscalld";
  version = "2.0.2";

  src = fetchgit {
    url = "git://git.proxmox.com/git/${pname}.git";
    rev = "410afbcbd5d629533ccb407072517dbe9525f5b2";
    hash = "sha256-qg69gt90tYJJwrjWT47LfW6JfwUXyUT0kqykKXPPBqg=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  prePatch = ''
    rm .cargo/config.toml
    cp ${./Cargo.lock} Cargo.lock
  '';

  buildInputs = [ systemdLibs ];

  passthru.updateScript = pve-update-script {
    extraArgs = [
      "--deb-name"
      "pve-lxc-syscalld"
      "--use-git-log"
    ];
  };

  meta = with lib; {
    description = "Proxmox LXC seccomp-proxy syscall handler daemon";
    homepage = "https://git.proxmox.com/?p=pve-lxc-syscalld.git";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [
      camillemndn
      julienmalka
    ];
    mainProgram = "pve-lxc-syscalld";
    platforms = platforms.linux;
  };
}
