/**
 * Passenger-style entrypoint (PassengerStartupFile = server.js), for shared Node hosts.
 * Binds process.env.PORT, which managed Node hosts inject and health-check.
 */
const http = require("http");
const { parse } = require("url");
const next = require("next");

const port = Number(process.env.PORT || process.env.APP_PORT || 3000);
const hostname = "0.0.0.0";
const app = next({ dev: false, hostname, port, dir: __dirname });
const handle = app.getRequestHandler();

console.log(
  `[clivora] passenger server.js starting next on ${hostname}:${port} (PORT=${process.env.PORT ?? "unset"})`,
);

app
  .prepare()
  .then(() => {
    http
      .createServer((req, res) => {
        const parsedUrl = parse(req.url, true);
        handle(req, res, parsedUrl);
      })
      .listen(port, hostname, () => {
        console.log(`[clivora] Ready on http://${hostname}:${port}`);
      });
  })
  .catch((err) => {
    console.error("[clivora] failed to start", err);
    process.exit(1);
  });
