{
  description = "farts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    pkgs32 = import nixpkgs { system = "i686-linux"; };
    openssl' = import ./openssl.nix {
      stdenv = pkgs.stdenv;
      lib = pkgs.lib;
      fetchFromGitHub = pkgs.fetchFromGitHub;
      perl = pkgs32.perl;
      buildPackages = pkgs32.buildPackages;
    };
  in
  {
    packages.x86_64-linux.default = pkgs.buildDotnetModule rec {
      pname = "AM2RLauncher";
      version = "2.3.0";
      src = ./.;

      projectFile = [
        "AM2RLauncher/AM2RLauncher.Gtk/AM2RLauncher.Gtk.csproj"
      ];

      nugetDeps = ./deps.nix;
      executables = "AM2RLauncher.Gtk";

      runtimeDeps = with pkgs; [
        # needed for launcher
        glibc
        gtk3
        libappindicator
        webkitgtk
        fuse2fs
        libnotify
        libgit2

        # needed for 32-bit game binary
        pkgs32.glibc
        pkgs32.stdenv.cc.cc.lib
        pkgs32.zlib
        pkgs32.xorg.libXxf86vm
        pkgs32.libGL
        pkgs32.openal
        pkgs32.libpulseaudio
        pkgs32.openssl
        pkgs32.xorg.libXext
        pkgs32.xorg.libX11
        pkgs32.xorg.libXrandr
        pkgs32.libGLU
        openssl'
      ];

      buildInputs = with pkgs; [
        gtk3
      ];

      patches = [[(pkgs.substituteAll {
        src = ./patchy;
        glibc = pkgs32.glibc;
      })]];

      dotnetFlags = [
        "-p:DefineConstants=\"NOAPPIMAGE;NOAUTOUPDATE\""
      ];

      postFixup = with pkgs; ''
        wrapProgram $out/bin/AM2RLauncher.Gtk \
          --prefix PATH : ${lib.makeBinPath [
            xdelta
            appimage-run
            file
            busybox
            openjdk
          ]} \
      '';

      desktopItems = [(pkgs.makeDesktopItem {
        desktopName = "AM2R Launcher";
        name = "am2rlauncher";
        exec = "AM2Rlauncher.Gtk";
        icon = "";
        comment = meta.description;
        type = "Application";
        categories = [ "Game" ];
      })];

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
        mainProgram = "AM2RLauncher.Gtk";
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
