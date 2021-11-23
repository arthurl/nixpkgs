{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lms;
in
{
  options.services.lms = {
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

    theadCount = mkOption {
      type = types.int;
      default = 0;
      description = ''
        Number of threads to be used to dispatch http requests. 0 means auto
        detect.
      '';
    };

    listenbrainzApiBaseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://api.listenbrainz.org";
      description = ''
        Listen brainz's root API url. If null, use default url.
      '';
    };

    listenbrainzMaxSyncListenCount = mkOption {
      type = types.int;
      default = 1000;
      description = ''
        How many listens to retrieve when syncing. 0 disables sync.
      '';
    };

    listenbrainzSyncPeriod = mkOption {
      type = types.int;
      default = 1;
      description = ''
        How often to resync listens. 0 disables sync.
      '';
    };

    acousticbrainzApiBaseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://acousticbrainz.org";
      description = ''
        Acoustic brainz's root API url. If null, use default url.
      '';
    };

    loginThrottlerMaxEntries = mkOption {
      type = types.int;
      default = 10000;
      description = ''
        Max entries in the login throttler (1 entry per IP address. For IPv6,
        the whole /64 block is used).
      '';
    };

    enableSubsonicApi = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable the Subsonic API.
      '';
    };

    coverArtMaxSize = mkOption {
      type = types.int;
      default = 10;
      description = ''
        Max external cover file size in MBytes.
      '';
    };

    coverArtCacheSize = mkOption {
      type = types.int;
      default = 30;
      description = ''
        Max cover cache size in MBytes.
      '';
    };

    coverArtJpegQuality = mkOption {
      type = types.int;
      default = 75;
      description = ''
        JPEG quality for covers (range is 1-100).
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

  config = mkIf cfg.enable {
    systemd.services.lms = {
      description = "Lightweight Music Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart =
          let lmsConfig = pkgs.writeText "lms.conf" (''
                # Auto-generated LMS config file
                working-dir = "${cfg.home}";
                listen-port = ${toString cfg.port};
                listen-addr = "${cfg.listenAddress}";
                behind-reverse-proxy = ${boolToString (cfg.virtualHost != null)};
                docroot = "${pkgs.lms}/share/lms/docroot/;/resources,/css,/images,/js,/favicon.ico";
                approot = "${pkgs.lms}/share/lms/approot";
                http-server-thread-count = ${toString cfg.theadCount};
              ''
              + strings.optionalString (cfg.listenbrainzApiBaseUrl != null) ''
                listenbrainz-api-base-url = "${cfg.listenbrainzApiBaseUrl}";
              ''
              + ''
                listenbrainz-max-sync-listen-count = ${toString cfg.listenbrainzMaxSyncListenCount};
                listenbrainz-sync-listens-period-hours = ${toString cfg.listenbrainzSyncPeriod};
              ''
              + strings.optionalString (cfg.acousticbrainzApiBaseUrl != null) ''
                acousticbrainz-api-base-url = "${cfg.acousticbrainzApiBaseUrl}";
              ''
              + ''
                login-throttler-max-entries = ${toString cfg.loginThrottlerMaxEntries};
                api-subsonic = ${boolToString cfg.enableSubsonicApi};
                cover-max-file-size = ${toString cfg.coverArtMaxSize};
                cover-max-cache-size = ${toString cfg.coverArtCacheSize};
                cover-jpeg-quality = ${toString cfg.coverArtJpegQuality};
              '');
          in "${pkgs.lms}/bin/lms ${lmsConfig}";
        Restart = "on-failure";
        RestartSec = 5;
        User = cfg.user;
        Group = "lms";
        WorkingDirectory = cfg.home;
        UMask = "0022";

        NoNewPrivileges = true;
        ProtectSystem = true;
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
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
          proxy_read_timeout 10m;
          proxy_send_timeout 10m;
          keepalive_timeout 10m;
        '';
      };
    };

    users.users = mkIf (cfg.user == "lms") {
      lms = {
        isSystemUser = true;
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
