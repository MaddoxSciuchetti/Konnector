import { withSession } from "../neo4j.js";
import {
  ContactSyncInput,
  fullName,
  normalizeEmail,
  normalizeOrgName,
  normalizePersonName,
  normalizePhone,
} from "../types.js";

interface ContactIndexEntry {
  sourceIdentifier: string;
  displayName: string;
  givenName: string;
  familyName: string;
}

function resolveRelationshipTarget(
  rawName: string,
  contacts: ContactIndexEntry[]
): { kind: "contact"; sourceIdentifier: string } | { kind: "external"; name: string } {
  const normalizedRaw = normalizePersonName(rawName);
  const lowerRaw = rawName.trim().toLowerCase();

  for (const contact of contacts) {
    if (contact.displayName.trim().toLowerCase() === lowerRaw) {
      return { kind: "contact", sourceIdentifier: contact.sourceIdentifier };
    }
  }

  for (const contact of contacts) {
    const normalizedFull = normalizePersonName(
      fullName(contact.givenName, contact.familyName)
    );
    if (normalizedFull === normalizedRaw && normalizedFull.length > 0) {
      return { kind: "contact", sourceIdentifier: contact.sourceIdentifier };
    }
  }

  const firstNameMatches = contacts.filter(
    (c) => c.givenName.trim().toLowerCase() === normalizedRaw.split(" ")[0]
  );
  if (firstNameMatches.length === 1) {
    return {
      kind: "contact",
      sourceIdentifier: firstNameMatches[0].sourceIdentifier,
    };
  }

  return { kind: "external", name: normalizedRaw };
}

export async function upsertBadgesCatalog(): Promise<void> {
  const badges = [
    { identifier: "friend", title: "Friend" },
    { identifier: "colleague", title: "Colleague" },
    { identifier: "client", title: "Client" },
    { identifier: "mentor", title: "Mentor" },
    { identifier: "family", title: "Family" },
  ];

  await withSession(async (session) => {
    for (const badge of badges) {
      await session.run(
        `MERGE (b:Badge {identifier: $identifier})
         SET b.title = $title`,
        badge
      );
    }
  });
}

export async function syncContactsForUser(
  userId: string,
  contacts: ContactSyncInput[],
  deletedSourceIdentifiers: string[]
): Promise<void> {
  await upsertBadgesCatalog();

  const index: ContactIndexEntry[] = contacts.map((c) => ({
    sourceIdentifier: c.sourceIdentifier,
    displayName: c.displayName,
    givenName: c.givenName,
    familyName: c.familyName,
  }));

  await withSession(async (session) => {
    await session.executeWrite(async (tx) => {
      for (const sourceIdentifier of deletedSourceIdentifiers) {
        await tx.run(
          `MATCH (u:User {userId: $userId})-[:OWNS]->(c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           DETACH DELETE c`,
          { userId, sourceIdentifier }
        );
      }

      for (const contact of contacts) {
        await tx.run(
          `MERGE (u:User {userId: $userId})
           MERGE (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           MERGE (u)-[:OWNS]->(c)
           SET c.displayName = $displayName,
               c.givenName = $givenName,
               c.familyName = $familyName,
               c.jobTitle = $jobTitle,
               c.note = $note,
               c.linkedInProfileURL = $linkedInProfileURL,
               c.intelligenceRating = $intelligenceRating,
               c.integrityRating = $integrityRating,
               c.driveRating = $driveRating,
               c.synchronizedAt = coalesce(datetime($synchronizedAt), datetime())`,
          {
            userId,
            sourceIdentifier: contact.sourceIdentifier,
            displayName: contact.displayName,
            givenName: contact.givenName,
            familyName: contact.familyName,
            jobTitle: contact.jobTitle,
            note: contact.note,
            linkedInProfileURL: contact.linkedInProfileURL,
            intelligenceRating: contact.intelligenceRating,
            integrityRating: contact.integrityRating,
            driveRating: contact.driveRating,
            synchronizedAt: contact.synchronizedAt ?? null,
          }
        );

        await tx.run(
          `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           OPTIONAL MATCH (c)-[oldOrg:WORKS_AT]->(:Organization)
           DELETE oldOrg`,
          { userId, sourceIdentifier: contact.sourceIdentifier }
        );

        if (contact.organizationName.trim()) {
          const orgName = normalizeOrgName(contact.organizationName);
          await tx.run(
            `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
             MERGE (o:Organization {name: $orgName})
             SET o.displayName = $displayName
             MERGE (c)-[w:WORKS_AT]->(o)
             SET w.department = $department, w.jobTitle = $jobTitle`,
            {
              userId,
              sourceIdentifier: contact.sourceIdentifier,
              orgName,
              displayName: contact.organizationName,
              department: contact.departmentName,
              jobTitle: contact.jobTitle,
            }
          );
        }

        await tx.run(
          `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           OPTIONAL MATCH (c)-[oldBadge:HAS_BADGE]->(:Badge)
           DELETE oldBadge`,
          { userId, sourceIdentifier: contact.sourceIdentifier }
        );

        for (const badgeId of contact.badges) {
          await tx.run(
            `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
             MERGE (b:Badge {identifier: $badgeId})
             MERGE (c)-[:HAS_BADGE]->(b)`,
            { userId, sourceIdentifier: contact.sourceIdentifier, badgeId }
          );
        }

        await tx.run(
          `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           OPTIONAL MATCH (c)-[oldEmail:HAS_EMAIL]->(:Email)
           DELETE oldEmail`,
          { userId, sourceIdentifier: contact.sourceIdentifier }
        );

        for (const email of contact.emails) {
          const address = normalizeEmail(email.value);
          if (!address) continue;
          await tx.run(
            `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
             MERGE (e:Email {address: $address})
             MERGE (c)-[r:HAS_EMAIL]->(e)
             SET r.label = $label`,
            {
              userId,
              sourceIdentifier: contact.sourceIdentifier,
              address,
              label: email.label,
            }
          );
        }

        await tx.run(
          `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           OPTIONAL MATCH (c)-[oldPhone:HAS_PHONE]->(:Phone)
           DELETE oldPhone`,
          { userId, sourceIdentifier: contact.sourceIdentifier }
        );

        for (const phone of contact.phones) {
          const number = normalizePhone(phone.value);
          if (!number) continue;
          await tx.run(
            `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
             MERGE (p:Phone {number: $number})
             MERGE (c)-[r:HAS_PHONE]->(p)
             SET r.label = $label`,
            {
              userId,
              sourceIdentifier: contact.sourceIdentifier,
              number,
              label: phone.label,
            }
          );
        }

        await tx.run(
          `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
           OPTIONAL MATCH (c)-[oldKnows:KNOWS|KNOWS_EXTERNAL]->()
           DELETE oldKnows`,
          { userId, sourceIdentifier: contact.sourceIdentifier }
        );
      }

      for (const contact of contacts) {
        for (const relationship of contact.relationships) {
          const target = resolveRelationshipTarget(relationship.name, index);
          if (target.kind === "contact") {
            if (target.sourceIdentifier === contact.sourceIdentifier) continue;
            await tx.run(
              `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
               MATCH (other:Contact {userId: $userId, sourceIdentifier: $otherId})
               MERGE (c)-[r:KNOWS]->(other)
               SET r.label = $label, r.rawName = $rawName`,
              {
                userId,
                sourceIdentifier: contact.sourceIdentifier,
                otherId: target.sourceIdentifier,
                label: relationship.label,
                rawName: relationship.name,
              }
            );
          } else {
            await tx.run(
              `MATCH (c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
               MERGE (ep:ExternalPerson {userId: $userId, name: $name})
               MERGE (c)-[r:KNOWS_EXTERNAL]->(ep)
               SET r.label = $label, r.rawName = $rawName`,
              {
                userId,
                sourceIdentifier: contact.sourceIdentifier,
                name: target.name,
                label: relationship.label,
                rawName: relationship.name,
              }
            );
          }
        }
      }
    });
  });
}

export async function deleteContactFromGraph(
  userId: string,
  sourceIdentifier: string
): Promise<void> {
  await withSession(async (session) => {
    await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(c:Contact {userId: $userId, sourceIdentifier: $sourceIdentifier})
       DETACH DELETE c`,
      { userId, sourceIdentifier }
    );
  });
}
