import neo4j, { Driver, Session } from "neo4j-driver";

let driver: Driver | null = null;

export function getDriver(): Driver {
  if (!driver) {
    const uri = process.env.NEO4J_URI ?? "neo4j://localhost:7687";
    const username = process.env.NEO4J_USERNAME ?? "neo4j";
    const password = process.env.NEO4J_PASSWORD;
    if (!password) {
      throw new Error("NEO4J_PASSWORD is required");
    }
    driver = neo4j.driver(uri, neo4j.auth.basic(username, password));
  }
  return driver;
}

export async function closeDriver(): Promise<void> {
  if (driver) {
    await driver.close();
    driver = null;
  }
}

export async function withSession<T>(
  work: (session: Session) => Promise<T>
): Promise<T> {
  const session = getDriver().session({
    database: process.env.NEO4J_DATABASE ?? "neo4j",
  });
  try {
    return await work(session);
  } finally {
    await session.close();
  }
}

export function toPlain(value: unknown): unknown {
  if (value === null || value === undefined) return value;
  if (typeof value === "object" && value !== null && "toNumber" in value) {
    return (value as { toNumber: () => number }).toNumber();
  }
  if (Array.isArray(value)) return value.map(toPlain);
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    if ("properties" in obj && "labels" in obj) {
      return {
        labels: obj.labels,
        ...(obj.properties as Record<string, unknown>),
      };
    }
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(obj)) {
      out[k] = toPlain(v);
    }
    return out;
  }
  return value;
}
