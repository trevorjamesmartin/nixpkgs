{ pkgs }:
rec {
  /* Prepare a derivation for local builds.
    *
    * This function adds an additional output for a derivation,
    * containing the build output.
    * The build output can be used later to allow incremental builds
    * by passing the `buildOut` output to the `mkIncrementalBuild` function.
    *
    * To build a project incrementaly follow these steps:
    * - run prepareIncrementalBuild on the desired derivation
    *   e.G `buildOutput = (pkgs.buildIncremental.prepareIncrementalBuild pkgs.virtualbox).buildOut;`
    * - change something you want in the sources of the package( e.G using source override)
    *   changedVBox = pkgs.virtuabox.overrideAttrs (old: {
    *      src = path/to/vbox/sources;
    *   }
    * - use `mkIncrementalBuild changedVBox buildOutput`
    * - enjoy shorter build times
  */
  prepareIncrementalBuild = drv: drv.overrideAttrs (old: {
    outputs = (old.outputs or [ "out" ]) ++ [ "buildOut" ];
    installPhase = pkgs.lib.optionalString (!(builtins.hasAttr "outputs" old)) ''
      mkdir -p $out
    '' + (old.installPhase or "") + ''
      mkdir -p $buildOut
      cp -r ./* $buildOut/
    '';
  });

  /* Build a derivation incrementally based on the output generated by
    * the `prepareIncrementalBuild function.
    *
    * Usage:
    * let
    *   buildOutput = (prepareIncrementalBuild drv).buildOut
    * in mkIncrementalBuild drv buildOutput
  */
  mkIncrementalBuild = drv: previousBuildArtifacts: drv.overrideAttrs (old: {
    prePatch = ''
      for file in $(diff -r  ./ ${previousBuildArtifacts} --brief | grep  "Files" |sed 's/^Only in \([^:]*\): /\1\//' | sed 's/^Files \(.*\) and .* differ/\1/')
      do
        touch $file
      done
      ${pkgs.rsync}/bin/rsync -cutU --chown=$USER:$USER --chmod=+w -r ${previousBuildArtifacts}/* .
    '' + (old.prePatch or "");
  });
}
