{
  description = "zenpilot: let Claude drive your Zen browser";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # `nix run github:beSaif/zenpilot -- setup`, or register it with an MCP client:
      #   claude mcp add zenpilot -- nix run github:beSaif/zenpilot
      # Zen itself isn't included: install it your usual way (or set ZENPILOT_ZEN to its command).
      packages = forAll (pkgs: rec {
        default = zenpilot;
        zenpilot = pkgs.writeShellApplication {
          name = "zenpilot";
          # The dialogs and notifications need a GUI tool on PATH; uv fetches the Python dependencies.
          runtimeInputs = [ pkgs.uv pkgs.python312 ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.zenity pkgs.libnotify pkgs.wl-clipboard pkgs.xdg-utils ];
          text = ''
            # uv's own downloaded Pythons don't run on NixOS.
            export UV_PYTHON=${pkgs.python312}/bin/python UV_PYTHON_DOWNLOADS=never
            # `zenpilot setup` registers this command with MCP clients.
            export ZENPILOT_COMMAND="$0"
            exec uv tool run --from ${self} zenpilot "$@"
          '';
        };
      });

      apps = forAll (pkgs: rec {
        default = zenpilot;
        zenpilot = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.zenpilot}/bin/zenpilot";
        };
      });

      # PyPI's ruff and uv-managed Pythons are generic Linux binaries, which NixOS can't run:
      # use these, and run `ruff` directly rather than `uv run ruff`.
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.uv pkgs.python312 pkgs.ruff ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.zenity pkgs.libnotify pkgs.wl-clipboard pkgs.xdg-utils ];
          UV_PYTHON = "${pkgs.python312}/bin/python";
          UV_PYTHON_DOWNLOADS = "never";
        };
      });
    };
}
