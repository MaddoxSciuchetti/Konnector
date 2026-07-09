import { z } from "zod";

export const labeledStringSchema = z.object({
  label: z.string(),
  value: z.string(),
});

export const relationshipSchema = z.object({
  label: z.string(),
  name: z.string(),
});

export const contactSyncSchema = z.object({
  sourceIdentifier: z.string(),
  displayName: z.string(),
  givenName: z.string().default(""),
  familyName: z.string().default(""),
  organizationName: z.string().default(""),
  departmentName: z.string().default(""),
  jobTitle: z.string().default(""),
  relationships: z.array(relationshipSchema).default([]),
  emails: z.array(labeledStringSchema).default([]),
  phones: z.array(labeledStringSchema).default([]),
  badges: z.array(z.string()).default([]),
  linkedInProfileURL: z.string().default(""),
  intelligenceRating: z.number().int().default(0),
  integrityRating: z.number().int().default(0),
  driveRating: z.number().int().default(0),
  note: z.string().default(""),
  synchronizedAt: z.string().datetime().optional(),
});

export const syncBatchSchema = z.object({
  contacts: z.array(contactSyncSchema),
  deletedSourceIdentifiers: z.array(z.string()).default([]),
});

export type ContactSyncInput = z.infer<typeof contactSyncSchema>;

export function normalizeOrgName(name: string): string {
  return name.trim().toLowerCase();
}

export function normalizeEmail(address: string): string {
  return address.trim().toLowerCase();
}

export function normalizePhone(number: string): string {
  return number.replace(/\D/g, "");
}

export function normalizePersonName(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, " ");
}

export function fullName(givenName: string, familyName: string): string {
  return `${givenName} ${familyName}`.trim();
}
