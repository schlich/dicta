self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.dicta;
in
{
  options.programs.dicta = {
    enable = lib.mkEnableOption "dicta, a tape recorder for spoken notes on coding agents' work";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.dicta;
      defaultText = lib.literalExpression "dicta.packages.\${system}.dicta";
      description = ''
        The dicta package. Its `noctaliaPlugins` attribute is a Noctalia
        `path` plugin source holding the recorder light.
      '';
    };

    claudeCode.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.claude-code.enable;
      defaultText = lib.literalExpression "config.programs.claude-code.enable";
      description = ''
        Attach pending takes to the next Claude Code prompt sent from the
        window they were recorded in, with a UserPromptSubmit hook plugin.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ cfg.package ]; }
      (lib.mkIf cfg.claudeCode.enable {
        programs.claude-code.plugins.dicta = cfg.package.claudeCodePlugin;
      })
    ]
  );
}
