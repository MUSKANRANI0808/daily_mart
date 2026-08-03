const functions = require("firebase-functions");
const http = require("http");

exports.api = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "*");
  res.set("Access-Control-Allow-Methods", "*");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  const queryString = req.url.includes("?") ? req.url.substring(req.url.indexOf("?")) : "";
  const targetUrl = `http://200.141.4.137/api.php${queryString}`;

  if (req.method === "POST") {
    const postData = JSON.stringify(req.body || {});
    const parsedUrl = new URL(targetUrl);
    const options = {
      hostname: parsedUrl.hostname,
      port: 80,
      path: parsedUrl.pathname + parsedUrl.search,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
    };

    const apiReq = http.request(options, (apiRes) => {
      let data = "";
      apiRes.on("data", (chunk) => (data += chunk));
      apiRes.on("end", () => {
        res.set("Content-Type", "application/json");
        res.status(200).send(data);
      });
    });

    apiReq.on("error", (err) => {
      res.status(500).send(JSON.stringify({ error: err.message }));
    });

    apiReq.write(postData);
    apiReq.end();
  } else {
    http.get(targetUrl, (apiRes) => {
      let data = "";
      apiRes.on("data", (chunk) => (data += chunk));
      apiRes.on("end", () => {
        res.set("Content-Type", "application/json");
        res.status(200).send(data);
      });
    }).on("error", (err) => {
      res.status(500).send(JSON.stringify({ error: err.message }));
    });
  }
});
