# Konnector Graph API

Backend service that syncs contact data into Neo4j and exposes relationship queries for the Konnector iOS app.

## Setup

```sh
cd konnector-graph-api
cp .env.example .env
# Set NEO4J_PASSWORD (and Aura URI for production)
npm install
npm run migrate
npm run dev
```

## Local Neo4j (Docker)

```sh
neo4j-cli docker create --name konnector --wait --rw
neo4j-cli credential dbms list
```

Use the `konnector` credential URI and password in `.env`.

## Neo4j Aura (Konnector instance)

1. Store Aura Console API credentials:
   ```sh
   neo4j-cli credential aura-client add --name konnector --client-id <ID> --client-secret <SECRET> --rw
   ```
2. Find the instance:
   ```sh
   neo4j-cli aura workspace list --format toon
   neo4j-cli aura instance list --format toon
   ```
3. Store Bolt credentials and set `NEO4J_URI`, `NEO4J_USERNAME`, `NEO4J_PASSWORD` on Render.

## Seed demo data

With the API running:

```sh
npm run seed
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Sign in |
| POST | `/sync/contacts` | Upsert contact batch |
| GET | `/graph/contacts/:id/network` | Contact neighborhood |
| GET | `/graph/contacts/common?a=&b=` | Shared orgs, badges, connections |
| GET | `/graph/search?q=` | Graph-powered search |

## Deploy on Render

[`render.yaml`](../render.yaml) defines the web service. Set `NEO4J_URI`, `NEO4J_USERNAME`, and `NEO4J_PASSWORD` in the Render dashboard to your Aura Konnector instance.
