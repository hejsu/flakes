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
      ];
    };
  };
}
