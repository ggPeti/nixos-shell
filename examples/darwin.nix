{ pkgs, lib, config, ... }: {
  services.openssh.enable = true;
  users.users = let
    user = builtins.getEnv "USER";
    keys = map (key: "${builtins.getEnv "HOME"}/.ssh/${key}") [
      "id_rsa.pub"
      "id_ecdsa.pub"
      "id_ed25519.pub"
    ];
    home = builtins.getEnv "HOME";
  in {
    ${user} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "lp" ];
      openssh.authorizedKeys.keyFiles = lib.filter builtins.pathExists keys;
      home = "/home/${user}";
      initialHashedPassword = "";
    };
  };

  nixos-shell.mounts = {
    mountHome = false;
    mountNixProfile = false;
    cache = "none"; # default is "loose"
  };

  virtualisation = {
    writableStoreUseTmpfs = false;
    writableStore = true;
    cores = 4;
    memorySize = "4096M";
    diskSize = 20 * 512;
    msize = 262144;

    # use squashed store
    shareNixStore = false;

    # virtfs mount
    shareExchangeDir = true;

    qemu = {
      options = [ "-accel hvf" ];
       # use vmnet adapter
      networkingOptions = [
        "-net nic,model=virtio,netdev=hn0"
        "-netdev vmnet-macos,id=hn0,mode=bridged,ifname=en8"
      ];
      pkgs = import <nixpkgs> {
        system = "x86_64-darwin";
        overlays = [
          (self: super: {
            qemu = super.qemu.overrideAttrs (attrs: {
              buildInputs = attrs.buildInputs
                ++ [ super.darwin.apple_sdk_11.frameworks.vmnet ];
              sandboxProfile = ''
                (allow file-read* file-write* process-exec mach-lookup)
                ; block homebrew dependencies
                (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
              '';
              preConfigure = attrs.preConfigure
                + "substituteInPlace meson.build --replace 'if exe_sign' 'if false'";
            });
          })
        ];
      };
    };
  };
}

