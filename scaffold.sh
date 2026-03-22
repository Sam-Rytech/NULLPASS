#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Bootstrapping NULLPASS ZK Monorepo in current directory..."

# 1. Create Directory Tree
echo "📁 Creating directory structures..."
mkdir -p .github/workflows .github/ISSUE_TEMPLATE
mkdir -p circuits/src
mkdir -p contracts/nullpass-verifier/src contracts/nullpass-verifier/tests
mkdir -p contracts/nullpass-registry/src contracts/nullpass-registry/tests
mkdir -p contracts/nullpass-gate/src contracts/nullpass-gate/tests
mkdir -p sdk/typescript/prover/src sdk/typescript/prover/tests
mkdir -p sdk/typescript/issuer/src sdk/typescript/issuer/tests
mkdir -p sdk/typescript/integrator/src sdk/typescript/integrator/tests
mkdir -p sdk/python/nullpass sdk/python/tests
mkdir -p api/src/routes api/src/services api/prisma
mkdir -p app/src/app/wallet app/src/app/prove app/src/app/issuers
mkdir -p app/src/components app/src/hooks app/src/context
mkdir -p docs scripts

# 2. Create Files
echo "📄 Touching files..."
# Root
touch .env.example .gitignore CHANGELOG.md CONTRIBUTING.md LICENSE README.md
# GitHub
touch .github/workflows/test-circuits.yml .github/workflows/test-contracts.yml
touch .github/ISSUE_TEMPLATE/bug_report.md .github/ISSUE_TEMPLATE/contributor_task.md
# Circuits (Noir)
touch circuits/src/main.nr circuits/src/test_basic_kyc.nr circuits/src/test_accredited.nr
# Contracts (Rust)
touch contracts/nullpass-verifier/src/lib.rs contracts/nullpass-verifier/src/verify.rs contracts/nullpass-verifier/src/nullifier.rs contracts/nullpass-verifier/src/access_pass.rs contracts/nullpass-verifier/src/types.rs contracts/nullpass-verifier/src/errors.rs
touch contracts/nullpass-verifier/tests/test_verify.rs contracts/nullpass-verifier/tests/test_nullifier.rs contracts/nullpass-verifier/tests/test_access_pass.rs contracts/nullpass-verifier/tests/test_integration.rs
touch contracts/nullpass-registry/src/lib.rs contracts/nullpass-registry/src/issuers.rs contracts/nullpass-registry/src/vk_store.rs contracts/nullpass-registry/src/types.rs contracts/nullpass-registry/src/errors.rs
touch contracts/nullpass-registry/tests/test_issuers.rs contracts/nullpass-registry/tests/test_vk_store.rs
touch contracts/nullpass-gate/src/lib.rs contracts/nullpass-gate/src/gate.rs contracts/nullpass-gate/src/errors.rs
touch contracts/nullpass-gate/tests/test_gate.rs
# SDKs (TypeScript)
touch sdk/typescript/prover/src/index.ts sdk/typescript/prover/src/prover.ts sdk/typescript/prover/tests/prover.test.ts
touch sdk/typescript/issuer/src/index.ts sdk/typescript/issuer/src/issuer.ts sdk/typescript/issuer/tests/issuer.test.ts
touch sdk/typescript/integrator/src/index.ts sdk/typescript/integrator/src/integrator.ts sdk/typescript/integrator/tests/integrator.test.ts
# SDKs (Python)
touch sdk/python/nullpass/__init__.py sdk/python/nullpass/admin.py sdk/python/tests/test_admin.py
# API
touch api/src/index.ts api/src/routes/relay.ts api/src/routes/issuers.ts api/src/services/indexer.ts
touch api/prisma/schema.prisma api/Dockerfile
# App
touch app/src/app/page.tsx app/src/app/layout.tsx app/src/app/globals.css
touch app/src/app/wallet/page.tsx app/src/app/prove/page.tsx app/src/app/issuers/page.tsx
touch app/src/components/CredentialCard.tsx app/src/components/ProofProgressTracker.tsx app/src/components/WalletConnector.tsx app/src/components/HeroSection.tsx app/src/components/CircuitRunner.tsx app/src/components/IssuerGrid.tsx
touch app/src/hooks/useNullpassProver.ts app/src/hooks/useIssuerRegistry.ts app/src/context/CredentialStoreContext.tsx
# Docs & Scripts
touch docs/architecture.md docs/issuer-guide.md docs/integrator-guide.md docs/security.md
touch scripts/generate-vk.sh scripts/test-proof.sh

# 3. Populate Package Manifests (No Installation)
echo "📦 Writing Package Manifests and Configurations..."

# Root package.json (Turborepo)
cat << 'EOF' > package.json
{
  "name": "nullpass-monorepo",
  "private": true,
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev --parallel",
    "lint": "turbo run lint",
    "test": "turbo run test"
  },
  "devDependencies": {
    "turbo": "^1.12.4",
    "prettier": "^3.2.5"
  },
  "workspaces": [
    "app",
    "api",
    "sdk/typescript/*"
  ]
}
EOF

# turbo.json
cat << 'EOF' > turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"]
    },
    "lint": {},
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {}
  }
}
EOF

# Noir Nargo.toml
cat << 'EOF' > circuits/Nargo.toml
[package]
name = "nullpass_circuit"
type = "bin"
authors = ["Nullpass Team"]
compiler_version = "0.31.0"

[dependencies]
EOF

# Root Cargo.toml (Rust Workspace)
cat << 'EOF' > contracts/Cargo.toml
[workspace]
members = [
    "nullpass-verifier",
    "nullpass-registry",
    "nullpass-gate"
]
resolver = "2"

[profile.release]
opt-level = "z"
overflow-checks = true
debug = 0
strip = "symbols"
debug-assertions = false
panic = "abort"
codegen-units = 1
lto = true
EOF

# nullpass-verifier Cargo.toml
cat << 'EOF' > contracts/nullpass-verifier/Cargo.toml
[package]
name = "nullpass-verifier"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
soroban-sdk = "20.0.0"

[dev-dependencies]
soroban-sdk = { version = "20.0.0", features = ["testutils"] }
EOF

# nullpass-registry Cargo.toml
cat << 'EOF' > contracts/nullpass-registry/Cargo.toml
[package]
name = "nullpass-registry"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
soroban-sdk = "20.0.0"
EOF

# nullpass-gate Cargo.toml
cat << 'EOF' > contracts/nullpass-gate/Cargo.toml
[package]
name = "nullpass-gate"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
soroban-sdk = "20.0.0"
EOF

# SDK Prover package.json
cat << 'EOF' > sdk/typescript/prover/package.json
{
  "name": "@nullpass/prover",
  "version": "0.1.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "@noir-lang/backend_barretenberg": "^0.31.0",
    "@noir-lang/noir_js": "^0.31.0",
    "@stellar/stellar-sdk": "^11.2.1"
  },
  "devDependencies": {
    "typescript": "^5.4.2",
    "jest": "^29.7.0"
  }
}
EOF

# SDK Issuer package.json
cat << 'EOF' > sdk/typescript/issuer/package.json
{
  "name": "@nullpass/issuer",
  "version": "0.1.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "nft.storage": "^7.1.1",
    "tweetnacl": "^1.0.3"
  },
  "devDependencies": {
    "typescript": "^5.4.2",
    "jest": "^29.7.0"
  }
}
EOF

# SDK Integrator package.json
cat << 'EOF' > sdk/typescript/integrator/package.json
{
  "name": "@nullpass/integrator",
  "version": "0.1.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "@stellar/stellar-sdk": "^11.2.1"
  },
  "devDependencies": {
    "typescript": "^5.4.2",
    "jest": "^29.7.0"
  }
}
EOF

# API package.json
cat << 'EOF' > api/package.json
{
  "name": "nullpass-api",
  "version": "0.1.0",
  "scripts": {
    "build": "tsc",
    "dev": "ts-node-dev src/index.ts",
    "indexer": "ts-node src/services/indexer.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "@prisma/client": "^5.10.0",
    "@stellar/stellar-sdk": "^11.2.1"
  },
  "devDependencies": {
    "typescript": "^5.4.2",
    "ts-node-dev": "^2.0.0",
    "prisma": "^5.10.0"
  }
}
EOF

# App package.json
cat << 'EOF' > app/package.json
{
  "name": "nullpass-app",
  "version": "0.1.0",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@nullpass/prover": "*",
    "@nullpass/issuer": "*",
    "@stellar/freighter-api": "^2.0.0",
    "framer-motion": "^11.0.8",
    "lucide-react": "^0.354.0"
  },
  "devDependencies": {
    "typescript": "^5.4.2",
    "@types/node": "^20.11.25",
    "@types/react": "^18.2.64",
    "tailwindcss": "^3.4.1"
  }
}
EOF

# .gitignore
cat << 'EOF' > .gitignore
# --- OS Metadata ---
.DS_Store

# --- Rust / Soroban / Noir ---
/contracts/target
/circuits/target
**/*.rs.bk
Cargo.lock

# --- Node / Frontend / API ---
node_modules
.npm
dist
.next
/out
build

# --- Environment & Secrets ---
.env
.env.*.local
.env.testnet
.env.mainnet
*.pem
*.key

# --- Databases ---
/api/prisma/dev.db

# --- Turbo ---
.turbo
EOF

echo "✅ Scaffolding complete! The NULLPASS structure is ready."