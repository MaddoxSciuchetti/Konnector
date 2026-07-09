import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
import neo4j from "neo4j-driver";

dotenv.config();

const __dirname = dirname(fileURLToPath(import.meta.url));
const schemaPath = join(__dirname, "../neo4j/schema.cypher");
const schema = readFileSync(schemaPath, "utf8");

const uri = process.env.NEO4J_URI ?? "neo4j://localhost:7687";
const username = process.env.NEO4J_USERNAME ?? "neo4j";
const password = process.env.NEO4J_PASSWORD;

if (!password) {
  console.error("NEO4J_PASSWORD is required");
  process.exit(1);
}

const driver = neo4j.driver(uri, neo4j.auth.basic(username, password));
const session = driver.session({ database: process.env.NEO4J_DATABASE ?? "neo4j" });

const statements = schema
  .split("\n")
  .reduce((acc, line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("//")) return acc;
    if (acc.length === 0) {
      acc.push(trimmed);
      return acc;
    }
    const last = acc[acc.length - 1];
    acc[acc.length - 1] = `${last} ${trimmed}`;
    if (trimmed.endsWith(";")) {
      acc[acc.length - 1] = acc[acc.length - 1].slice(0, -1);
      acc.push("");
    }
    return acc;
  }, [])
  .map((s) => s.trim())
  .filter(Boolean);

try {
  for (const statement of statements) {
    await session.run(statement);
    console.log(`Applied: ${statement.slice(0, 60)}...`);
  }
  console.log("Schema migration complete.");
} finally {
  await session.close();
  await driver.close();
}
