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
  in
  {
    defaultPackage.x86_64-linux = pkgs.buildDotnetModule rec {
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
        openssl
        fuse2fs
        libnotify
        libpulseaudio
        libgit2
        openal
        xorg.libX11

        # needed for 32-bit game binary
        pkgs32.glibc
      ];

      buildInputs = with pkgs; [
        gtk3
        which
        xdelta
      ];

      dotnetFlags = [
        "-p:DefineConstants=\"NOAPPIMAGE\;NOAUTOUPDATE\""
      ];

      fixupPhase = ''
        mkdir -p $out/lib/AM2RLauncher

        cp $(which xdelta3) $out/lib/AM2RLauncher/xdelta3
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
  };
}
