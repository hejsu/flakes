{ ... }: {
  modules.ingress.tailnet.status.endpoints."tcp:80" =
    "tcp://127.0.0.1:8080";

  services.gatus = {
    enable = true;
    settings = {
      web = {
        address = "127.0.0.1";
        port = 8080;
      };
      concurrency = 2;
      storage.type = "memory";

      ui = {
        header = "suspended services";
        "default-sort-by" = "name";
        buttons = [
          { name = "cpa"; link = "http://cpa.blenny-ayu.ts.net/"; }
          { name = "magpie"; link = "http://magpie.blenny-ayu.ts.net/"; }
          { name = "sbsm"; link = "https://sbsm.aoran.eu.org/"; }
        ];
      };

      endpoints = [
        {
          name = "cpa";
          url = "http://cpa.blenny-ayu.ts.net/";
          interval = "5m";
          method = "HEAD";
          client.timeout = "10s";
          conditions = [
            "[CONNECTED] == true"
            "[STATUS] < 500"
          ];
        }
        {
          name = "magpie";
          url = "http://magpie.blenny-ayu.ts.net/";
          interval = "5m";
          method = "HEAD";
          client.timeout = "10s";
          conditions = [
            "[CONNECTED] == true"
            "[STATUS] < 500"
          ];
        }
        {
          name = "sbsm";
          url = "https://sbsm.aoran.eu.org/";
          interval = "5m";
          method = "HEAD";
          client.timeout = "10s";
          conditions = [
            "[CONNECTED] == true"
            "[STATUS] < 500"
          ];
        }
      ];
    };
  };
}
