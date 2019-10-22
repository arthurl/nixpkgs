{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lms;
in
{
  options = {

    services.lms = {
      enable = mkEnableOption "LMS (Lightweight Music Server). A self-hosted, music streaming server.";

      home = mkOption {
        type = types.path;
        default = "/var/lib/lms";
        description = ''
          Path to the working directory. Must have write privileges in order to
          create and modify this directory.
        '';
      };

      virtualHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Name of the nginx virtualhost to setup as reverse proxy. If null, do
          not setup any virtualhost.
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          The address on which to bind LMS.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 5082;
        description = ''
          The port on which LMS will listen to.
        '';
      };

      enableSubsonicApi = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable the Subsonic API.
        '';
      };

      acousticbrainzApiUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://acousticbrainz.org/api/v1/";
        description = ''
          Acoustic brainz's root API url. If null, use default url.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "lms";
        description = ''
          User account under which LMS runs. You have to create the user
          yourself if you specify a different user from the default.
        '';
      };

    };
  };

  config = mkIf cfg.enable {
    systemd.services.lms = {
      description = "Lightweight Music Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart =
          let lmsConfig = pkgs.writeText "lms.conf" ''
                # Auto-generated LMS config file
                working-dir = "${cfg.home}";
                listen-port = ${toString cfg.port};
                listen-addr = "${cfg.listenAddress}";
                behind-reverse-proxy = ${boolToString (cfg.virtualHost != null)};
                docroot = "${pkgs.lms}/share/lms/docroot/;/resources,/css,/images,/js,/favicon.ico";
                approot = "${pkgs.lms}/share/lms/approot";
                api-subsonic = ${boolToString cfg.enableSubsonicApi};
              ''
              + strings.optionalString (cfg.acousticbrainzApiUrl != null) ''
                acousticbrainz-api-url = "${cfg.acousticbrainzApiUrl}";
              '';
          in "${pkgs.lms}/bin/lms ${lmsConfig}";
        Restart = "on-failure";
        RestartSec = 1;
        User = cfg.user;
        Group = "lms";
        WorkingDirectory = cfg.home;
        UMask = "0022";
      };
    };

    # from: https://github.com/epoupon/lms#reverse-proxy-settings
    services.nginx = mkIf (cfg.virtualHost != null) {
      enable = true;
      virtualHosts.${cfg.virtualHost} = {
        locations."/" = {
          proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 120;
          '';
        };
        extraConfig = ''
          proxy_request_buffering off;
          proxy_buffering off;
          proxy_buffer_size 4k;
        '';
      };
    };

    users.users = mkIf (cfg.user == "lms") {
      lms = {
        description = "LMS service user";
        name = cfg.user;
        group = "lms";
        home = cfg.home;
        createHome = true;
      };
    };

    users.groups.lms = {};
  };
}
