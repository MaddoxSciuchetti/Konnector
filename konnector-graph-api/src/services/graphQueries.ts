import { withSession, toPlain } from "../neo4j.js";

function contactNode(record: Record<string, unknown>) {
  return {
    sourceIdentifier: record.sourceIdentifier as string,
    displayName: record.displayName as string,
    givenName: (record.givenName as string) ?? "",
    familyName: (record.familyName as string) ?? "",
    jobTitle: (record.jobTitle as string) ?? "",
    organizationName: (record.organizationName as string) ?? "",
  };
}

export async function getContactNetwork(
  userId: string,
  sourceIdentifier: string,
  depth = 2
) {
  const maxDepth = Math.min(Math.max(depth, 1), 3);

  return withSession(async (session) => {
    const centerResult = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(c:Contact {sourceIdentifier: $sourceIdentifier})
       OPTIONAL MATCH (c)-[:WORKS_AT]->(o:Organization)
       RETURN c, collect(DISTINCT o.displayName) AS organizations`,
      { userId, sourceIdentifier }
    );

    if (centerResult.records.length === 0) {
      return null;
    }

    const centerRecord = centerResult.records[0];
    const centerProps = centerRecord.get("c").properties as Record<string, unknown>;
    const organizations = centerRecord.get("organizations") as string[];

    const neighborhoodResult = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(center:Contact {sourceIdentifier: $sourceIdentifier})
       MATCH path = (center)-[:KNOWS|KNOWS_EXTERNAL|WORKS_AT*1..${maxDepth}]-(related)
       WHERE related:Contact OR related:ExternalPerson OR related:Organization
       WITH DISTINCT related, labels(related) AS nodeLabels
       OPTIONAL MATCH (related:Contact)-[:WORKS_AT]->(org:Organization)
       RETURN related, nodeLabels, collect(DISTINCT org.displayName) AS organizations`,
      { userId, sourceIdentifier }
    );

    const nodes: Array<Record<string, unknown>> = [
      {
        ...contactNode(centerProps),
        organizationName: organizations[0] ?? "",
        kind: "contact",
        isCenter: true,
      },
    ];
    const edges: Array<Record<string, unknown>> = [];

    for (const record of neighborhoodResult.records) {
      const related = record.get("related");
      const nodeLabels = record.get("nodeLabels") as string[];
      const orgs = record.get("organizations") as string[];
      const props = related.properties as Record<string, unknown>;

      if (nodeLabels.includes("Contact")) {
        nodes.push({
          ...contactNode(props),
          organizationName: orgs[0] ?? "",
          kind: "contact",
          isCenter: false,
        });
      } else if (nodeLabels.includes("ExternalPerson")) {
        nodes.push({
          name: props.name,
          kind: "external",
          isCenter: false,
        });
      } else if (nodeLabels.includes("Organization")) {
        nodes.push({
          name: props.displayName ?? props.name,
          kind: "organization",
          isCenter: false,
        });
      }
    }

    const edgeResult = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(center:Contact {sourceIdentifier: $sourceIdentifier})
       MATCH (center)-[r:KNOWS|KNOWS_EXTERNAL|WORKS_AT]-(related)
       RETURN type(r) AS type,
              r.label AS label,
              center.sourceIdentifier AS fromId,
              center.displayName AS fromName,
              related.sourceIdentifier AS toContactId,
              related.displayName AS toContactName,
              related.name AS toExternalName,
              labels(related) AS toLabels`,
      { userId, sourceIdentifier }
    );

    for (const record of edgeResult.records) {
      const toLabels = record.get("toLabels") as string[];
      const toId = toLabels.includes("Contact")
        ? (record.get("toContactId") as string)
        : toLabels.includes("ExternalPerson")
          ? (record.get("toExternalName") as string)
          : (record.get("toExternalName") as string) ??
            (record.get("toContactName") as string);

      edges.push({
        type: record.get("type"),
        label: record.get("label") ?? null,
        from: record.get("fromId") ?? record.get("fromName"),
        to: toId,
        toKind: toLabels.includes("Contact")
          ? "contact"
          : toLabels.includes("ExternalPerson")
            ? "external"
            : "organization",
      });
    }

    const uniqueNodes = Array.from(
      new Map(
        nodes.map((node) => [
          `${node.kind}:${node.sourceIdentifier ?? node.name}`,
          node,
        ])
      ).values()
    );

    return {
      center: toPlain({
        ...contactNode(centerProps),
        organizationName: organizations[0] ?? "",
      }),
      nodes: toPlain(uniqueNodes),
      edges: toPlain(edges),
    };
  });
}

export async function getContactCommonalities(
  userId: string,
  sourceIdentifierA: string,
  sourceIdentifierB: string
) {
  return withSession(async (session) => {
    const result = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(a:Contact {sourceIdentifier: $idA})
       MATCH (u)-[:OWNS]->(b:Contact {sourceIdentifier: $idB})
       OPTIONAL MATCH (a)-[:WORKS_AT]->(o:Organization)<-[:WORKS_AT]-(b)
       OPTIONAL MATCH (a)-[:HAS_BADGE]->(badge:Badge)<-[:HAS_BADGE]-(b)
       OPTIONAL MATCH (a)-[:KNOWS]-(mutual:Contact)-[:KNOWS]-(b)
       WHERE mutual <> a AND mutual <> b
       RETURN collect(DISTINCT o.displayName) AS sharedOrganizations,
              collect(DISTINCT badge.title) AS sharedBadges,
              collect(DISTINCT {sourceIdentifier: mutual.sourceIdentifier, displayName: mutual.displayName}) AS mutualConnections`,
      { userId, idA: sourceIdentifierA, idB: sourceIdentifierB }
    );

    if (result.records.length === 0) {
      return null;
    }

    const record = result.records[0].toObject();
    return toPlain({
      sharedOrganizations: record.sharedOrganizations.filter(Boolean),
      sharedBadges: record.sharedBadges.filter(Boolean),
      mutualConnections: record.mutualConnections.filter(
        (c: { sourceIdentifier?: string }) => c.sourceIdentifier
      ),
    });
  });
}

export async function getOrganizationContacts(
  userId: string,
  organizationName: string
) {
  const normalized = organizationName.trim().toLowerCase();

  return withSession(async (session) => {
    const result = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(c:Contact)-[:WORKS_AT]->(o:Organization {name: $orgName})
       RETURN c.sourceIdentifier AS sourceIdentifier,
              c.displayName AS displayName,
              c.jobTitle AS jobTitle
       ORDER BY c.displayName`,
      { userId, orgName: normalized }
    );

    return result.records.map((record) => record.toObject());
  });
}

export async function searchGraph(userId: string, query: string) {
  const trimmed = query.trim().toLowerCase();
  if (!trimmed) return { coworkers: [], byBadge: [], related: [] };

  return withSession(async (session) => {
    const coworkers = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(anchor:Contact)
       WHERE toLower(anchor.displayName) CONTAINS $query
       MATCH (u)-[:OWNS]->(other:Contact)-[:WORKS_AT]->(o:Organization)<-[:WORKS_AT]-(anchor)
       WHERE other <> anchor
       RETURN anchor.displayName AS anchorName,
              other.sourceIdentifier AS sourceIdentifier,
              other.displayName AS displayName,
              o.displayName AS organizationName
       LIMIT 20`,
      { userId, query: trimmed }
    );

    const byBadge = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(c:Contact)-[:HAS_BADGE]->(b:Badge)
       WHERE toLower(b.title) CONTAINS $query OR toLower(b.identifier) CONTAINS $query
       RETURN c.sourceIdentifier AS sourceIdentifier,
              c.displayName AS displayName,
              b.title AS badgeTitle
       LIMIT 20`,
      { userId, query: trimmed }
    );

    const related = await session.run(
      `MATCH (u:User {userId: $userId})-[:OWNS]->(c:Contact)
       WHERE toLower(c.displayName) CONTAINS $query
       MATCH (c)-[:KNOWS|KNOWS_EXTERNAL]-(related)
       RETURN c.displayName AS anchorName,
              labels(related) AS relatedLabels,
              related.sourceIdentifier AS sourceIdentifier,
              related.displayName AS displayName,
              related.name AS externalName
       LIMIT 20`,
      { userId, query: trimmed }
    );

    return {
      coworkers: coworkers.records.map((r) => r.toObject()),
      byBadge: byBadge.records.map((r) => r.toObject()),
      related: related.records.map((r) => ({
        anchorName: r.get("anchorName"),
        relatedKind: (r.get("relatedLabels") as string[]).includes("Contact")
          ? "contact"
          : "external",
        displayName:
          r.get("displayName") ?? r.get("externalName") ?? "Unknown",
        sourceIdentifier: r.get("sourceIdentifier"),
      })),
    };
  });
}
