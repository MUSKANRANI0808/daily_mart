const functions = require("firebase-functions");
const http = require("http");

const TARGET_HOSTS = ["89.116.52.173", "200.141.4.137"];

function forwardRequest(hostIndex, req, res) {
  if (hostIndex >= TARGET_HOSTS.length) {
    res.status(500).send(JSON.stringify({ error: "All VPS targets failed" }));
    return;
  }

  const targetHost = TARGET_HOSTS[hostIndex];
  const queryString = req.url.includes("?") ? req.url.substring(req.url.indexOf("?")) : "";

  if (req.method === "POST") {
    const postData = JSON.stringify(req.body || {});
    const options = {
      hostname: targetHost,
      port: 80,
      path: `/api.php${queryString}`,
      method: "POST",
      headers: {
        "Host": "200.141.4.137",
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
      timeout: 4000,
    };

    const apiReq = http.request(options, (apiRes) => {
      let data = "";
      apiRes.on("data", (chunk) => (data += chunk));
      apiRes.on("end", () => {
        res.set("Content-Type", "application/json");
        res.status(200).send(data);
      });
    });

    apiReq.on("error", () => {
      forwardRequest(hostIndex + 1, req, res);
    });

    apiReq.write(postData);
    apiReq.end();
  } else {
    const options = {
      hostname: targetHost,
      port: 80,
      path: `/api.php${queryString}`,
      method: "GET",
      headers: {
        "Host": "200.141.4.137",
      },
      timeout: 4000,
    };

    const apiReq = http.request(options, (apiRes) => {
      let data = "";
      apiRes.on("data", (chunk) => (data += chunk));
      apiRes.on("end", () => {
        res.set("Content-Type", "application/json");
        res.status(200).send(data);
      });
    });

    apiReq.on("error", () => {
      forwardRequest(hostIndex + 1, req, res);
    });

    apiReq.end();
  }
}

exports.api = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "*");
  res.set("Access-Control-Allow-Methods", "*");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  forwardRequest(0, req, res);
});
