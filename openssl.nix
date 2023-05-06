{ stdenv, lib, fetchFromGitHub, perl, buildPackages }:

stdenv.mkDerivation rec {
  pname = "openssl";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "openssl";
    repo = pname;
    rev = "27007233db5d6f8b91ed474c4e09dd7014871cc6";
    sha256 = "sha256-cPmAp/vppNi9aXbjn9M3TXNWWIhKiMyZ3WQz7e8f9Ag=";
  };

  # patches = [
  #   ./nix-ssl-cert-file.patch
  #   ./use-etc-ssl-certs.patch
  # ];

  postPatch = ''
    patchShebangs Configure
    patchShebangs test/*
    for a in test/t* ; do
      substituteInPlace "$a" \
        --replace /bin/rm rm
    done
  '';

  outputs = [ "bin" "dev" "out" "man" ];
  setOutputFlags = false;
  separateDebugInfo =
    !(stdenv.hostPlatform.useLLVM or false) &&
    stdenv.cc.isGNU;

  nativeBuildInputs = [ perl ];
  buildInputs = [ perl ];

  configurePlatforms = [];
  configureScript = "./Configure linux-generic${toString stdenv.hostPlatform.parsed.cpu.bits}";

  # OpenSSL doesn't like the `--enable-static` / `--disable-shared` flags.
  dontAddStaticConfigureFlags = true;
  configureFlags = [
    "shared" # "shared" builds both shared and static libraries
    "--libdir=lib"
    (if !stdenv.hostPlatform.isStatic then
      "--openssldir=etc/ssl"
     else
       # Move OPENSSLDIR to the 'etc' output for static builds. Prepend '/.'
       # to the path to make it appear absolute before variable expansion,
       # else the 'prefix' would be prepended to it.
       "--openssldir=/.$(etc)/etc/ssl"
    )
  ] ++ lib.optional stdenv.hostPlatform.isStatic "no-ct"
  ;

  makeFlags = [
    "MANDIR=$(man)/share/man"
    # This avoids conflicts between man pages of openssl subcommands (for
    # example 'ts' and 'err') man pages and their equivalent top-level
    # command in other packages (respectively man-pages and moreutils).
    # This is done in ubuntu and archlinux, and possiibly many other distros.
    "MANSUFFIX=ssl"
  ];

  enableParallelBuilding = true;

  postInstall =
    lib.optionalString (!stdenv.hostPlatform.isStatic) ''
      # If we're building dynamic libraries, then don't install static
      # libraries.
      if [ -n "$(echo $out/lib/*.so $out/lib/*.dylib $out/lib/*.dll)" ]; then
          rm "$out/lib/"*.a
      fi
      substituteInPlace $out/bin/c_rehash --replace ${buildPackages.perl}/bin/perl "/usr/bin/env perl"
    '' + ''
      mkdir -p $bin
      mv $out/bin $bin/bin

      mkdir $dev
      mv $out/include $dev/

      # remove dependency on Perl at runtime
      rm -r $out/etc/ssl/misc

      rmdir $out/etc/ssl/{certs,private}
    '';

    postFixup = ''
      # Check to make sure the main output and the static runtime dependencies
      # don't depend on perl
      if grep -r '${buildPackages.perl}' $out $etc; then
        echo "Found an erroneous dependency on perl ^^^" >&2
        exit 1
      fi
    '';

  meta = with lib; {
    homepage = "https://www.openssl.org/";
    description = "A cryptographic library that implements the SSL and TLS protocols";
    license = licenses.openssl;
    platforms = platforms.all;
  };
}
