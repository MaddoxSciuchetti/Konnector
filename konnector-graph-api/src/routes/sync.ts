import { Router } from "express";
import { authMiddleware } from "../auth.js";
import { syncBatchSchema } from "../types.js";
import {
  deleteContactFromGraph,
  syncContactsForUser,
} from "../services/syncService.js";

export const syncRouter = Router();

syncRouter.use(authMiddleware);

syncRouter.post("/contacts", async (req, res) => {
  try {
    const body = syncBatchSchema.parse(req.body);
    await syncContactsForUser(
      req.user!.userId,
      body.contacts,
      body.deletedSourceIdentifiers
    );
    res.json({
      synced: body.contacts.length,
      deleted: body.deletedSourceIdentifiers.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Sync failed";
    res.status(400).json({ error: message });
  }
});

syncRouter.delete("/contacts/:sourceIdentifier", async (req, res) => {
  try {
    await deleteContactFromGraph(req.user!.userId, req.params.sourceIdentifier);
    res.status(204).send();
  } catch (error) {
    const message = error instanceof Error ? error.message : "Delete failed";
    res.status(400).json({ error: message });
  }
});
