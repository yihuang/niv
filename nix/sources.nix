# This file has been generated by Niv.

let

  #
  # The fetchers. fetch_<type> fetches specs of type <type>.
  #

  fetch_file = spec:
    if spec.builtin or true then
      builtins_fetchurl { inherit (spec) url sha256; }
    else
      pkgs.fetchurl { inherit (spec) url sha256; };

  fetch_tarball = spec:
    if spec.builtin or true then
      builtins_fetchTarball { inherit (spec) url sha256; }
    else
      pkgs.fetchzip { inherit (spec) url sha256; };

  fetch_builtin-tarball = spec:
    builtins.trace
      ''
        WARNING:
          The niv type "builtin-tarball" will soon be deprecated. You should
          instead use `builtin = true`.

          $ niv modify <package> -a type=tarball -a builtins=true
      '' # TODO: attribute as JSON
      builtins_fetchTarball { inherit (spec) url sha256; };

  fetch_builtin-url = spec:
    builtins.trace
      ''
        WARNING:
          The niv type "builtin-url" will soon be deprecated. You should
          instead use `builtin = true`.

          $ niv modify <package> -a type=file -a builtins=true
      '' # TODO: attribute as JSON

      (builtins_fetchurl { inherit (spec) url sha256; });

  #
  # The sources to fetch.
  #

  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  #
  # Various helpers
  #

  # The set of packages used when specs are fetched using non-builtins.
  pkgs =
    if hasNixpkgsPath
    then
      if hasThisAsNixpkgsPath
      then import (builtins_fetchTarball { inherit (sources_nixpkgs) url sha256; }) {}
      else import <nixpkgs> {}
    else
      import (builtins_fetchTarball { inherit (sources_nixpkgs) url sha256; }) {};

  sources_nixpkgs =
    if builtins.hasAttr "nixpkgs" sources
    then sources.nixpkgs
    else abort
      ''
        Please specify either <nixpkgs> (through -I or NIX_PATH=nixpkgs=...) or
        add a package called "nixpkgs" to your sources.json.
      '';

  hasNixpkgsPath = (builtins.tryEval <nixpkgs>).success;
  hasThisAsNixpkgsPath =
    (builtins.tryEval <nixpkgs>).success && <nixpkgs> == ./.;

  # The actual fetching function.
  fetch = name: spec:

    if ! builtins.hasAttr "type" spec then
      abort "ERROR: niv spec ${name} does not have a 'type' attribute"
    else if spec.type == "file" then fetch_file spec
    else if spec.type == "tarball" then fetch_tarball spec
    else if spec.type == "builtin-tarball" then fetch_builtin-tarball spec
    else if spec.type == "builtin-url" then fetch_builtin-url spec
    else
      abort "ERROR: niv spec ${name} has unknown type ${builtins.fromJSON spec.type}";

  # Ports of functions for previous nix versions

  # a Nix version of mapAttrs if the built-in doesn't exist
  mapAttrs = builtins.mapAttrs or (
    f: set: with builtins;
    listToAttrs (map (attr: { name = attr; value = f attr set.${attr}; }) (attrNames set))
  );

  # fetchTarball version that is compatible between all the versions of Nix
  builtins_fetchTarball = { url, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchTarball;
    in
      if lessThan nixVersion "1.12" then
        fetchTarball { inherit url; }
      else
        fetchTarball attrs;

  # fetchurl version that is compatible between all the versions of Nix
  builtins_fetchurl = { url, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchurl;
    in
      if lessThan nixVersion "1.12" then
        fetchurl { inherit url; }
      else
        fetchurl attrs;

in
mapAttrs (
  name: spec:
    if builtins.hasAttr "outPath" spec
    then abort
      "The values in sources.json should not have an 'outPath' attribute"
    else
      spec // { outPath = fetch name spec; }
) sources
