const express = require("express");
const path = require("path");
const { createProxyMiddleware } = require("http-proxy-middleware");

const app = express();
const PORT = process.env.PORT;
const API = process.env.API

// ---- Serve static frontend files ----
app.use(express.static(path.join(__dirname, "public")));

// ---- Proxy API requests to backend ----
// assumes your API service runs at http://api-service:3000 inside Docker/K8s
app.use(
  "/api",
  createProxyMiddleware({
    target: API,
    changeOrigin: true,
    pathRewrite: { "^/api": "" }
  })
);

// ---- Fallback to index.html ----
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.listen(PORT, () => {
  console.log(`Frontend running at http://localhost:${PORT}`);
});
