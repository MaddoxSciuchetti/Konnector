import { Router } from "express";
import { z } from "zod";
import { loginUser, registerUser, signToken } from "../auth.js";

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const authRouter = Router();

authRouter.post("/register", async (req, res) => {
  try {
    const body = registerSchema.parse(req.body);
    const user = await registerUser(body.email, body.password);
    res.status(201).json({ token: signToken(user), user });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Registration failed";
    res.status(400).json({ error: message });
  }
});

authRouter.post("/login", async (req, res) => {
  try {
    const body = loginSchema.parse(req.body);
    const user = await loginUser(body.email, body.password);
    res.json({ token: signToken(user), user });
  } catch {
    res.status(401).json({ error: "Invalid email or password" });
  }
});
