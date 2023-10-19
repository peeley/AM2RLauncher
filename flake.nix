{
description = "farts";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  flake-utils.url = "github:numtide/flake-utils";
};

outputs = { self, nixpkgs, flake-utils}:
let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  pkgs32 = import nixpkgs { system = "i686-linux"; };
  am2r-run = pkgs32.buildFHSEnv {
    name = "am2r-run";

    targetPkgs = pkgs:
      with pkgs; [
        stdenv.cc.cc.lib
        xorg.libX11
        xorg.libXext
        xorg.libXrandr
        xorg.libXxf86vm
        curl
        libGLU
        libglvnd
        openal
        zlib
      ];

    runScript = pkgs.writeShellScript "am2r-run" ''
      exec -- "$1" "$@"
    '';
  };
in
{
  packages.x86_64-linux.default = pkgs.buildDotnetModule rec {
    pname = "am2r-launcher";
    version = "2.3.0";
    src = ./.;

    projectFile = "AM2RLauncher/AM2RLauncher.Gtk/AM2RLauncher.Gtk.csproj";

    nugetDeps = ./deps.nix;
    executables = "AM2RLauncher.Gtk";

    runtimeDeps = with pkgs; [
      glibc
      gtk3
      libappindicator
      webkitgtk
      e2fsprogs
      libnotify
      libgit2
      openssl
      glib-networking
    ];

    buildInputs = with pkgs; [ gtk3 ];

    patches = [ ./am2r-run-binary.patch ];

    dotnetFlags =
      [ ''-p:DefineConstants="NOAPPIMAGE;NOAUTOUPDATE;PATCHOPENSSL"'' ];

    postFixup = with pkgs; ''
       wrapProgram $out/bin/AM2RLauncher.Gtk \
            --prefix PATH : ${
              pkgs.lib.makeBinPath [ am2r-run xdelta file busybox openjdk patchelf ]
            }

               mkdir -p $out/share/icons
                  install -Dm644 $src/AM2RLauncher/distribution/linux/AM2RLauncher.png $out/share/icons/AM2RLauncher.png
                     install -Dm644 $src/AM2RLauncher/distribution/linux/AM2RLauncher.desktop $out/share/applications/AM2RLauncher.desktop

                        # renames binary for desktop file
                           mv $out/bin/AM2RLauncher.Gtk $out/bin/AM2RLauncher
                            '';

    meta = with pkgs.lib; {
      homepage = "https://github.com/AM2R-Community-Developers/AM2RLauncher";
      description = "A front-end for dealing with AM2R updates and mods";
      longDescription = ''
           A front-end application that simplifies installing the latest
                AM2R-Community-Updates, creating APKs for Android use, as well as Mods for
                     AM2R.
                        '';
      license = licenses.gpl3Only;
      maintainers = with maintainers; [ nsnelson ];
      mainProgram = "AM2RLauncher";
      platforms = platforms.linux;
  };
  };

    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        pkgs.dotnet-sdk
        pkgs.omnisharp-roslyn
      ];
    };
  };
}
