const functions = require("firebase-functions");
const http = require("http");

const TARGET_URLS = [
  "http://89.116.52.173/api.php",
  "http://200.141.4.137/api.php"
];

function forwardRequest(targetIndex, req, res) {
  if (targetIndex >= TARGET_URLS.length) {
    res.status(500).send(JSON.stringify({ success: false, error: "VPS server connection failed" }));
    return;
  }

  const baseUrl = TARGET_URLS[targetIndex];
  const queryString = req.url.includes("?") ? req.url.substring(req.url.indexOf("?")) : "";
  const fullUrl = `${baseUrl}${queryString}`;

  if (req.method === "POST") {
    const postData = JSON.stringify(req.body || {});
    const parsedUrl = new URL(fullUrl);
    const options = {
      hostname: parsedUrl.hostname,
      port: 80,
      path: parsedUrl.pathname + parsedUrl.search,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
      timeout: 6000,
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
      forwardRequest(targetIndex + 1, req, res);
    });

    apiReq.write(postData);
    apiReq.end();
  } else {
    const parsedUrl = new URL(fullUrl);
    const options = {
      hostname: parsedUrl.hostname,
      port: 80,
      path: parsedUrl.pathname + parsedUrl.search,
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
      timeout: 6000,
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
      forwardRequest(targetIndex + 1, req, res);
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
