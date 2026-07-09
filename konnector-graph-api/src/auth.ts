import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { Request, Response, NextFunction } from "express";
import { withSession } from "./neo4j.js";

export interface AuthUser {
  userId: string;
  email: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

function jwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error("JWT_SECRET is required");
  }
  return secret;
}

export function signToken(user: AuthUser): string {
  return jwt.sign({ sub: user.userId, email: user.email }, jwtSecret(), {
    expiresIn: "30d",
  });
}

export function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing authorization token" });
    return;
  }
  try {
    const payload = jwt.verify(header.slice(7), jwtSecret()) as {
      sub: string;
      email: string;
    };
    req.user = { userId: payload.sub, email: payload.email };
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

export async function registerUser(
  email: string,
  password: string
): Promise<AuthUser> {
  const normalizedEmail = email.trim().toLowerCase();
  const passwordHash = await bcrypt.hash(password, 12);
  const userId = crypto.randomUUID();

  await withSession(async (session) => {
    const existing = await session.run(
      "MATCH (u:User {email: $email}) RETURN u LIMIT 1",
      { email: normalizedEmail }
    );
    if (existing.records.length > 0) {
      throw new Error("Email already registered");
    }

    await session.run(
      `CREATE (u:User {
        userId: $userId,
        email: $email,
        passwordHash: $passwordHash,
        createdAt: datetime()
      })`,
      { userId, email: normalizedEmail, passwordHash }
    );
  });

  return { userId, email: normalizedEmail };
}

export async function loginUser(
  email: string,
  password: string
): Promise<AuthUser> {
  const normalizedEmail = email.trim().toLowerCase();

  const user = await withSession(async (session) => {
    const result = await session.run(
      "MATCH (u:User {email: $email}) RETURN u.userId AS userId, u.passwordHash AS passwordHash LIMIT 1",
      { email: normalizedEmail }
    );
    return result.records[0]?.toObject() as
      | { userId: string; passwordHash: string }
      | undefined;
  });

  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    throw new Error("Invalid email or password");
  }

  return { userId: user.userId, email: normalizedEmail };
}

export async function ensureDemoUser(): Promise<AuthUser> {
  const email = "demo@konnector.app";
  const password = "demo-password";

  try {
    return await loginUser(email, password);
  } catch {
    return registerUser(email, password);
  }
}
