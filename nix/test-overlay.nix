{
  self,
  plenary-nvim,
  telescope-nvim,
  toggleterm,
}: final: prev:
with final.lib;
with final.lib.strings;
with final.stdenv; let
  lints = mkDerivation {
    name = "haskell-tools-lints";

    src = self;

    phases = [
      "unpackPhase"
      "buildPhase"
      "checkPhase"
    ];

    doCheck = true;

    buildInputs = with final; [
      lua51Packages.luacheck
      sumneko-lua-language-server
    ];

    buildPhase = ''
      mkdir -p $out
      cp -r lua $out/lua
      cp -r tests $out/tests
      cp .luacheckrc $out
      cp .luarc.json $out
    '';

    checkPhase = ''
      export HOME=$(realpath .)
      cd $out
      luacheck lua
      luacheck tests
      lua-language-server --check "$out/lua" \
        --configpath "$out/.luarc.json" \
        --logpath "$out" \
        --checklevel="Warning"
      if [[ -f $out/check.json ]]; then
        cat $out/check.json
        exit 1
      fi
    '';
  };

  nvim-nightly = final.neovim-nightly;

  plenary-plugin = final.pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "plenary.nvim";
    src = plenary-nvim;
  };

  telescope-plugin = final.pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "telescope.nvim";
    src = telescope-nvim;
  };

  toggleterm-plugin = final.pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "toggleterm";
    src = toggleterm;
  };

  mkPlenaryTest = {
    name,
    nvim ? final.neovim-unwrapped,
    withTelescope ? true,
    extraPkgs ? [],
  }: let
    nvim-wrapped = final.pkgs.wrapNeovim nvim {
      configure = {
        customRC = ''
          lua << EOF
          vim.cmd('runtime! plugin/plenary.vim')
          EOF
        '';
        packages.myVimPackage = {
          start =
            [
              final.haskell-tools-nvim-dev
              plenary-plugin
              toggleterm-plugin
            ]
            ++ (
              if withTelescope
              then [telescope-plugin]
              else []
            );
        };
      };
    };
  in
    mkDerivation {
      inherit name;

      src = self;

      phases = [
        "unpackPhase"
        "buildPhase"
        "checkPhase"
      ];

      doCheck = true;

      buildInputs = with final;
        [
          nvim-wrapped
          makeWrapper
          haskell-language-server
        ]
        ++ extraPkgs;

      buildPhase = ''
        mkdir -p $out
        cp -r tests $out
        # FIXME: Fore some reason, this doesn't work
        # haskell-language-server-wrapper generate-default-config > $out/tests/hls.json
      '';

      checkPhase = ''
        export HOME=$(realpath .)
        export TEST_CWD=$(realpath $out/tests)
        cd $out
        nvim --headless --noplugin -c "PlenaryBustedDirectory tests {nvim_cmd = 'nvim'}"
      '';
    };
in {
  inherit lints;

  haskell-tools-test = mkPlenaryTest {name = "haskell-tools";};

  haskell-tools-test-no-telescope = mkPlenaryTest {
    name = "haskell-tools-no-telescope";
    withTelescope = false;
  };

  haskell-tools-test-no-telescope-with-hoogle = mkPlenaryTest {
    name = "haskell-tools-no-telescope-local-hoogle";
    withTelescope = false;
    extraPkgs = [final.pkgs.haskellPackages.hoogle];
  };

  haskell-tools-test-nightly = mkPlenaryTest {
    nvim = nvim-nightly;
    name = "haskell-tools-nightly";
  };

  haskell-tools-test-no-telescope-nightly = mkPlenaryTest {
    nvim = nvim-nightly;
    name = "haskell-tools-no-telescope-nightly";
    withTelescope = false;
  };

  haskell-tools-test-no-telescope-with-hoogle-nightly = mkPlenaryTest {
    nvim = nvim-nightly;
    name = "haskell-tools-no-telescope-local-hoogle-nightly";
    withTelescope = false;
    extraPkgs = [final.pkgs.haskellPackages.hoogle];
  };
}
