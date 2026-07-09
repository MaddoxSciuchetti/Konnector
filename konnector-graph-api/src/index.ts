import "dotenv/config";
import cors from "cors";
import express from "express";
import { authRouter } from "./routes/auth.js";
import { graphRouter } from "./routes/graph.js";
import { syncRouter } from "./routes/sync.js";
import { closeDriver, getDriver } from "./neo4j.js";

const app = express();
const port = Number(process.env.PORT ?? 3000);

app.use(cors());
app.use(express.json({ limit: "2mb" }));

app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "konnector-graph-api" });
});

app.get("/", (_req, res) => {
  res.json({
    service: "konnector-graph-api",
    status: "ok",
    endpoints: {
      health: "GET /health",
      register: "POST /auth/register",
      login: "POST /auth/login",
      sync: "POST /sync/contacts",
      network: "GET /graph/contacts/:sourceIdentifier/network",
      common: "GET /graph/contacts/common?a=&b=",
      search: "GET /graph/search?q=",
    },
  });
});

app.use("/auth", authRouter);
app.use("/sync", syncRouter);
app.use("/graph", graphRouter);

async function start() {
  getDriver();
  app.listen(port, "0.0.0.0", () => {
    console.log(`konnector-graph-api listening on 0.0.0.0:${port}`);
  });
}

process.on("SIGTERM", async () => {
  await closeDriver();
  process.exit(0);
});

start().catch((error) => {
  console.error(error);
  process.exit(1);
});
