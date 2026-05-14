#!/bin/bash

echo "🚀 Creating AMA-NexOra project..."

mkdir -p ama-nexora
cd ama-nexora

# Root files
cat << 'EOF' > pnpm-workspace.yaml
packages:
  - 'artifacts/*'
  - 'lib/*'
EOF

cat << 'EOF' > package.json
{
  "name": "ama-nexora-workspace",
  "private": true,
  "scripts": {
    "dev": "pnpm -r --parallel run dev",
    "db:push": "pnpm --filter @workspace/db run push"
  }
}
EOF

############################################
# LIB / DB
############################################
mkdir -p lib/db/src/schema

cat << 'EOF' > lib/db/package.json
{
  "name": "@workspace/db",
  "version": "1.0.0",
  "type": "module",
  "main": "src/index.ts",
  "scripts": {
    "push": "drizzle-kit push"
  },
  "dependencies": {
    "drizzle-orm": "^0.30.0",
    "drizzle-kit": "^0.20.0",
    "pg": "^8.11.0"
  }
}
EOF

cat << 'EOF' > lib/db/drizzle.config.ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/schema/index.ts",
  out: "./drizzle",
  driver: "pg",
  dbCredentials: {
    connectionString: process.env.DATABASE_URL!
  }
});
EOF

cat << 'EOF' > lib/db/src/schema/index.ts
import { pgTable, text, serial, timestamp, integer, boolean, jsonb } from "drizzle-orm/pg-core";

export const adminsTable = pgTable("admins", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const projectsTable = pgTable("projects", {
  id: serial("id").primaryKey(),
  name: jsonb("name").$type<{ en: string; ar: string }>().notNull(),
  type: text("type").notNull(),
  link: text("link").notNull().default("#"),
  image: text("image"),
  description: jsonb("description").$type<{ en: string; ar: string }>().notNull(),
  tags: jsonb("tags").$type<{ en: string[]; ar: string[] }>().notNull().default({ en: [], ar: [] }),
  sortOrder: integer("sort_order").notNull().default(0),
  membersOnly: boolean("members_only").notNull().default(false),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const messagesTable = pgTable("messages", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull(),
  message: text("message").notNull(),
  isRead: boolean("is_read").notNull().default(false),
  visitorId: integer("visitor_id"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const visitorsTable = pgTable("visitors", {
  id: serial("id").primaryKey(),
  email: text("email").notNull().unique(),
  displayName: text("display_name"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  lastSeenAt: timestamp("last_seen_at").defaultNow().notNull(),
});
EOF

############################################
# LIB / API-ZOD
############################################
mkdir -p lib/api-zod/src

cat << 'EOF' > lib/api-zod/package.json
{
  "name": "@workspace/api-zod",
  "version": "1.0.0",
  "type": "module",
  "main": "src/index.ts",
  "dependencies": {
    "zod": "^3.23.0"
  }
}
EOF

cat << 'EOF' > lib/api-zod/src/index.ts
export const placeholder = "Zod schemas go here";
EOF

############################################
# LIB / API-CLIENT-REACT
############################################
mkdir -p lib/api-client-react/src

cat << 'EOF' > lib/api-client-react/package.json
{
  "name": "@workspace/api-client-react",
  "version": "1.0.0",
  "type": "module",
  "main": "src/index.ts",
  "dependencies": {
    "react": "^18.2.0",
    "axios": "^1.6.0"
  }
}
EOF

cat << 'EOF' > lib/api-client-react/src/index.ts
export const placeholder = "React API hooks go here";
EOF

############################################
# BACKEND
############################################
mkdir -p artifacts/api-server/src/routes
mkdir -p artifacts/api-server/scripts

cat << 'EOF' > artifacts/api-server/package.json
{
  "name": "api-server",
  "version": "1.0.0",
  "type": "module",
  "main": "src/index.ts",
  "scripts": {
    "dev": "ts-node-dev --respawn src/index.ts"
  },
  "dependencies": {
    "@workspace/db": "workspace:*",
    "@workspace/api-zod": "workspace:*",
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "cookie-parser": "^1.4.6",
    "dotenv": "^16.3.0",
    "pg": "^8.11.0",
    "drizzle-orm": "^0.30.0",
    "bcryptjs": "^2.4.3"
  },
  "devDependencies": {
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.3.0"
  }
}
EOF

cat << 'EOF' > artifacts/api-server/.env
PORT=8080
DATABASE_URL=postgres://user:pass@localhost:5432/dbname
ADMIN_JWT_SECRET=your_super_secret_random_string_here
OTP_CONSOLE_FALLBACK=1
EOF

cat << 'EOF' > artifacts/api-server/src/index.ts
import express from "express";
import cors from "cors";
import cookieParser from "cookie-parser";
import router from "./routes";
import dotenv from "dotenv";

dotenv.config();

const app = express();
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

app.use("/api", router);

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(\`Backend running on port \${port}\`));
EOF

cat << 'EOF' > artifacts/api-server/src/db.ts
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import * as schema from "@workspace/db/src/schema";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

export const db = drizzle(pool, { schema });
EOF

cat << 'EOF' > artifacts/api-server/src/routes/index.ts
import { Router } from "express";
import admin from "./admin";
import projects from "./projects";

const router = Router();

router.use("/admin", admin);
router.use("/projects", projects);

export default router;
EOF

cat << 'EOF' > artifacts/api-server/src/routes/admin.ts
import { Router } from "express";
import { db } from "../db";
import { adminsTable } from "@workspace/db/src/schema";
import bcrypt from "bcryptjs";

const router = Router();

router.post("/login", async (req, res) => {
  const { username, password } = req.body;

  const [admin] = await db.select().from(adminsTable).where(adminsTable.username.eq(username));

  if (!admin) return res.status(401).json({ error: "Invalid credentials" });

  const ok = await bcrypt.compare(password, admin.passwordHash);
  if (!ok) return res.status(401).json({ error: "Invalid credentials" });

  res.json({ success: true });
});

export default router;
EOF

cat << 'EOF' > artifacts/api-server/src/routes/projects.ts
import { Router } from "express";
import { db } from "../db";
import { projectsTable } from "@workspace/db/src/schema";

const router = Router();

router.get("/", async (_req, res) => {
  const projects = await db.select().from(projectsTable);
  res.json(projects);
});

export default router;
EOF

cat << 'EOF' > artifacts/api-server/scripts/seed-admin.ts
import bcrypt from "bcryptjs";
import { db } from "../src/db";
import { adminsTable } from "@workspace/db/src/schema";

async function main() {
  const hash = await bcrypt.hash("changeme123", 10);

  await db.insert(adminsTable).values({
    username: "admin",
    passwordHash: hash
  });

  console.log("Admin created successfully");
}

main();
EOF

############################################
# FRONTEND
############################################
mkdir -p artifacts/ama-nexora/src
mkdir -p artifacts/ama-nexora/public/images

cat << 'EOF' > artifacts/ama-nexora/package.json
{
  "name": "ama-nexora",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.3.0"
  }
}
EOF

cat << 'EOF' > artifacts/ama-nexora/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
  server: {
    proxy: {
      "/api": "http://localhost:8080"
    }
  }
});
EOF

cat << 'EOF' > artifacts/ama-nexora/src/main.tsx
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

cat << 'EOF' > artifacts/ama-nexora/src/App.tsx
import data from "./data.json";

export default function App() {
  return (
    <div style={{ padding: 40 }}>
      <h1>{data.owner}</h1>
      <h2>Projects</h2>

      {data.projects.map((p, i) => (
        <div key={i} style={{ marginBottom: 20 }}>
          <h3>{p.name.en}</h3>
          <p>{p.description.en}</p>
        </div>
      ))}
    </div>
  );
}
EOF

cat << 'EOF' > artifacts/ama-nexora/src/data.json
{
  "owner": "AMA NexOra",
  "brand": "AMA.intel",
  "email": "AMA.intel.sa@gmail.com",
  "projects": [
    {
      "name": { "en": "AMA Landing Page", "ar": "صفحة هبوط AMA" },
      "type": "Web",
      "description": { "en": "A premium landing page...", "ar": "صفحة هبوط فخمة..." },
      "tags": { "en": ["React", "Three.js"], "ar": ["رياكت"] },
      "preview": "/images/project-ama-landing.png",
      "link": "#"
    }
  ]
}
EOF

############################################
# README
############################################
cat << 'EOF' > README.md
# AMA NexOra — Monorepo

## Run Project

### Install
pnpm install

### Push DB
pnpm db:push

### Seed Admin
pnpm --filter api-server ts-node artifacts/api-server/scripts/seed-admin.ts

### Run Dev
pnpm dev

Frontend → http://localhost:5173  
Backend → http://localhost:8080
EOF

echo "🎉 Project created successfully!"

