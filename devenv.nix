{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  expert = inputs.expert.packages.${pkgs.stdenv.hostPlatform.system}.default;
  refactorexSource = inputs.refactorex;
  refactorexStateDirectory =
    "refactorex-${builtins.substring 0 12 (builtins.hashString "sha256" (toString refactorexSource))}";
in
{
  packages =
    with pkgs;
    [
      #
      beam27Packages.elixir-ls
      expert
      emmet-language-server
      typescript-language-server
      git
      lefthook
      nodejs_24
      pnpm
      # pgcli
      # secretspec
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      chromium
      inotify-tools
      libnotify
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      terminal-notifier
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.CoreServices
    ];

  dotenv.disableHint = true;

  languages.elixir = {
    enable = true;
  };

  # needed by elixir-ls:
  languages.erlang = {
    enable = true;
  };

  languages.typescript.enable = true;

  scripts.refactorex.exec = ''
    set -eu

    install_dir="$DEVENV_STATE/${refactorexStateDirectory}"
    compiled_marker="$install_dir/.devenv-compiled"

    if [ ! -f "$compiled_marker" ]; then
      mkdir -p "$install_dir"
      cp -R ${refactorexSource}/. "$install_dir/"
      chmod -R u+w "$install_dir"

      (
        cd "$install_dir/refactorex_lsp"
        mix deps.get >&2
        mix compile >&2
      )

      touch "$compiled_marker"
    fi

    exec "$install_dir/bin/start" "$@"
  '';

  services.adminer.enable = true;

  services.postgres = {
    enable = true;
    port = 5432;
    listen_addresses = "localhost";

    initialDatabases = [
      { name = "lex_dev"; }
      { name = "lex_test"; }
    ];
    initialScript = ''
      CREATE ROLE postgres SUPERUSER LOGIN;
    '';
  };

  # processes.phx-server = {
  #   exec = "PORT=4000 mix phx.server";
  #   # if your Phoenix app is in a subdir, set cwd explicitly, e.g.:
  #   # cwd = "${config.git.root}/youmap";
  # };

  process.manager.implementation = "overmind";

  # enable iex history
  env =
    {
      ERL_AFLAGS = "-kernel shell_history enabled";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
    };
  #
  # env.REDIS_URL = config.secretspec.secrets.REDIS_URL;
}
