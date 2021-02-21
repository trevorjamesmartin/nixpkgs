{ lib
, stdenv
, fetchurl
, jre
, autoPatchelfHook
, zlib
, writeScript
, common-updater-scripts
, git
, nixfmt
, nix
, coreutils
, gnused
, nixosTests
}:

stdenv.mkDerivation rec {
  pname = "sbt";
  version = "1.4.7";

  src = fetchurl {
    url =
      "https://github.com/sbt/sbt/releases/download/v${version}/sbt-${version}.tgz";
    sha256 = "sha256-wqdZ/kCjwhoWtaiNAM1m869vByHk6mG2OULfuDotVP0=";
  };

  patchPhase = ''
    echo -java-home ${jre.home} >>conf/sbtopts
  '';

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [ zlib ];

  installPhase = ''
    mkdir -p $out/share/sbt $out/bin
    cp -ra . $out/share/sbt
    ln -sT ../share/sbt/bin/sbt $out/bin/sbt
    ln -sT ../share/sbt/bin/sbtn-x86_64-${
      if (stdenv.isDarwin) then "apple-darwin" else "pc-linux"
    } $out/bin/sbtn
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    ($out/bin/sbt --offline --version 2>&1 || true) | grep 'getting org.scala-sbt sbt ${version}  (this may take some time)'
  '';

  meta = with lib; {
    homepage = "https://www.scala-sbt.org/";
    license = licenses.bsd3;
    description = "A build tool for Scala, Java and more";
    maintainers = with maintainers; [ nequissimus ];
    platforms = platforms.unix;
  };

  passthru.updateScript = writeScript "update.sh" ''
    #!${stdenv.shell}
    set -o errexit
    PATH=${
      lib.makeBinPath [
        common-updater-scripts
        git
        nixfmt
        nix
        coreutils
        gnused
      ]
    }

    oldVersion="$(nix-instantiate --eval -E "with import ./. {}; lib.getVersion sbt" | tr -d '"')"
    latestTag="$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --sort='version:refname' --tags git@github.com:sbt/sbt.git '*.*.*' | tail --lines=1 | cut --delimiter='/' --fields=3 | sed 's|^v||g')"

    if [ ! "$oldVersion" = "$latestTag" ]; then
      update-source-version sbt "$latestTag" --version-key=version --print-changes
      nixpkgs="$(git rev-parse --show-toplevel)"
      default_nix="$nixpkgs/pkgs/development/tools/build-managers/sbt/default.nix"
      nixfmt "$default_nix"
    else
      echo "sbt is already up-to-date"
    fi
  '';
}
