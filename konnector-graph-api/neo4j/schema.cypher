CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT contact_per_user IF NOT EXISTS
FOR (c:Contact) REQUIRE (c.userId, c.sourceIdentifier) IS UNIQUE;

CREATE CONSTRAINT org_name IF NOT EXISTS
FOR (o:Organization) REQUIRE o.name IS UNIQUE;

CREATE CONSTRAINT badge_id IF NOT EXISTS
FOR (b:Badge) REQUIRE b.identifier IS UNIQUE;

CREATE CONSTRAINT email_address IF NOT EXISTS
FOR (e:Email) REQUIRE e.address IS UNIQUE;

CREATE CONSTRAINT phone_number IF NOT EXISTS
FOR (p:Phone) REQUIRE p.number IS UNIQUE;

CREATE CONSTRAINT external_person_per_user IF NOT EXISTS
FOR (ep:ExternalPerson) REQUIRE (ep.userId, ep.name) IS UNIQUE;

CREATE INDEX contact_display_name IF NOT EXISTS
FOR (c:Contact) ON (c.displayName);

CREATE INDEX contact_user IF NOT EXISTS
FOR (c:Contact) ON (c.userId);
