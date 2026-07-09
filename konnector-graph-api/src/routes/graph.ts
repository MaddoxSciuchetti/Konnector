import { Router } from "express";
import { authMiddleware } from "../auth.js";
import {
  getContactCommonalities,
  getContactNetwork,
  getOrganizationContacts,
  searchGraph,
} from "../services/graphQueries.js";

export const graphRouter = Router();

graphRouter.use(authMiddleware);

graphRouter.get("/contacts/:sourceIdentifier/network", async (req, res) => {
  const depth = Number(req.query.depth ?? 2);
  const network = await getContactNetwork(
    req.user!.userId,
    req.params.sourceIdentifier,
    depth
  );
  if (!network) {
    res.status(404).json({ error: "Contact not found in graph" });
    return;
  }
  res.json(network);
});

graphRouter.get("/contacts/common", async (req, res) => {
  const idA = req.query.a;
  const idB = req.query.b;
  if (typeof idA !== "string" || typeof idB !== "string") {
    res.status(400).json({ error: "Query params a and b are required" });
    return;
  }

  const common = await getContactCommonalities(req.user!.userId, idA, idB);
  if (!common) {
    res.status(404).json({ error: "One or both contacts not found in graph" });
    return;
  }
  res.json(common);
});

graphRouter.get("/organizations/:name/contacts", async (req, res) => {
  const contacts = await getOrganizationContacts(
    req.user!.userId,
    req.params.name
  );
  res.json({ contacts });
});

graphRouter.get("/search", async (req, res) => {
  const query = req.query.q;
  if (typeof query !== "string") {
    res.status(400).json({ error: "Query param q is required" });
    return;
  }
  const results = await searchGraph(req.user!.userId, query);
  res.json(results);
});
