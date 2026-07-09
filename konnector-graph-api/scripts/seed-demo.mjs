import dotenv from "dotenv";

dotenv.config();

const baseUrl = process.env.GRAPH_API_URL ?? "http://localhost:3000";

const demoContacts = [
  {
    sourceIdentifier: "demo-ada",
    displayName: "Ada Lovelace",
    givenName: "Ada",
    familyName: "Lovelace",
    organizationName: "Analytical Engine Society",
    departmentName: "",
    jobTitle: "Mathematician",
    relationships: [{ label: "Friend", name: "Alan Turing" }],
    emails: [{ label: "Work", value: "ada@example.com" }],
    phones: [{ label: "Mobile", value: "+442079460101" }],
    badges: ["friend", "mentor"],
    linkedInProfileURL: "",
    intelligenceRating: 10,
    integrityRating: 9,
    driveRating: 9,
    note: "Pioneer of computing",
  },
  {
    sourceIdentifier: "demo-alan",
    displayName: "Alan Turing",
    givenName: "Alan",
    familyName: "Turing",
    organizationName: "Bletchley Research",
    departmentName: "",
    jobTitle: "Computer Scientist",
    relationships: [
      { label: "Friend", name: "Ada Lovelace" },
      { label: "Colleague", name: "Grace Hopper" },
    ],
    emails: [{ label: "Work", value: "alan@example.com" }],
    phones: [{ label: "Mobile", value: "+442079460103" }],
    badges: ["colleague", "mentor"],
    linkedInProfileURL: "",
    intelligenceRating: 10,
    integrityRating: 10,
    driveRating: 8,
    note: "Cryptography and AI pioneer",
  },
  {
    sourceIdentifier: "demo-grace",
    displayName: "Grace Hopper",
    givenName: "Grace",
    familyName: "Hopper",
    organizationName: "Bletchley Research",
    departmentName: "",
    jobTitle: "Rear Admiral",
    relationships: [
      { label: "Colleague", name: "Alan Turing" },
      { label: "Friend", name: "Katherine Johnson" },
    ],
    emails: [{ label: "Work", value: "grace@example.com" }],
    phones: [{ label: "Mobile", value: "+12025550102" }],
    badges: ["colleague"],
    linkedInProfileURL: "",
    intelligenceRating: 9,
    integrityRating: 9,
    driveRating: 10,
    note: "",
  },
  {
    sourceIdentifier: "demo-katherine",
    displayName: "Katherine Johnson",
    givenName: "Katherine",
    familyName: "Johnson",
    organizationName: "Orbital Mechanics Lab",
    departmentName: "",
    jobTitle: "Research Mathematician",
    relationships: [{ label: "Friend", name: "Grace Hopper" }],
    emails: [{ label: "Work", value: "katherine@example.com" }],
    phones: [{ label: "Mobile", value: "+17575550104" }],
    badges: ["friend", "mentor"],
    linkedInProfileURL: "",
    intelligenceRating: 10,
    integrityRating: 10,
    driveRating: 9,
    note: "",
  },
  {
    sourceIdentifier: "demo-marie",
    displayName: "Marie Curie",
    givenName: "Marie",
    familyName: "Curie",
    organizationName: "Radium Institute",
    departmentName: "",
    jobTitle: "Physicist",
    relationships: [{ label: "Colleague", name: "Ada Lovelace" }],
    emails: [{ label: "Work", value: "marie@example.com" }],
    phones: [{ label: "Mobile", value: "+33155550108" }],
    badges: ["mentor"],
    linkedInProfileURL: "",
    intelligenceRating: 10,
    integrityRating: 10,
    driveRating: 10,
    note: "Nobel laureate",
  },
];

async function ensureDemoUser() {
  const registerResponse = await fetch(`${baseUrl}/auth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: "demo@konnector.app",
      password: "demo-password",
    }),
  });

  if (registerResponse.ok) {
    return registerResponse.json();
  }

  const loginResponse = await fetch(`${baseUrl}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: "demo@konnector.app",
      password: "demo-password",
    }),
  });

  if (!loginResponse.ok) {
    throw new Error(`Auth failed: ${await loginResponse.text()}`);
  }

  return loginResponse.json();
}

const auth = await ensureDemoUser();
console.log("Authenticated demo user");

const syncResponse = await fetch(`${baseUrl}/sync/contacts`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${auth.token}`,
  },
  body: JSON.stringify({ contacts: demoContacts, deletedSourceIdentifiers: [] }),
});

if (!syncResponse.ok) {
  console.error(await syncResponse.text());
  process.exit(1);
}

console.log("Seeded demo contacts:", await syncResponse.json());

const networkResponse = await fetch(
  `${baseUrl}/graph/contacts/demo-alan/network`,
  {
    headers: { Authorization: `Bearer ${auth.token}` },
  }
);
console.log("Alan network sample:", await networkResponse.json());

const commonResponse = await fetch(
  `${baseUrl}/graph/contacts/common?a=demo-ada&b=demo-alan`,
  {
    headers: { Authorization: `Bearer ${auth.token}` },
  }
);
console.log("Ada/Alan commonalities:", await commonResponse.json());
