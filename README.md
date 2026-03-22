# NULLPASS

**Zero-Knowledge Compliance Middleware on Stellar**

## 1. Project Overview
NULLPASS is a zero-knowledge (ZK) compliance middleware and credential verification layer built natively on the Stellar Soroban smart contract platform. It serves Decentralized Finance (DeFi) protocols, Real World Asset (RWA) tokenization vaults, and decentralized identity providers. The project exists to resolve the foundational conflict between regulatory compliance and on-chain user privacy. Currently, proving accreditation, jurisdictional eligibility, or KYC status requires exposing personally identifiable information (PII) or storing non-private soulbound tokens that map physical identities to wallet addresses. NULLPASS eliminates this privacy violation by enabling users to generate localized Groth16 zero-knowledge proofs demonstrating that they hold valid credentials from trusted off-chain issuers. Soroban smart contracts verify these proofs mathematically utilizing native BN254 elliptic curve host functions. The protocol grants users a time-bounded, privacy-preserving `AccessPass`, allowing downstream DeFi protocols to gate access with a single line of code without ever touching, storing, or perceiving user identity data.

## 2. System Design Principles
1. **Off-Chain Data Sovereignty:** The system dictates that verifiable credentials (VCs) and personally identifiable information must never touch the blockchain, even in encrypted forms. Credentials reside strictly within the user's local device or cloud-synced secure enclave.
2. **Native Cryptographic Verification:** To ensure economic viability for high-frequency access checks, proof verification must bypass WebAssembly (WASM) execution limits. The architecture strictly utilizes Protocol 25 native host functions for BN254 pairings and Poseidon hashing, reducing verification costs to fractions of a cent.
3. **Double-Spend Cryptographic Nullification:** To prevent proof replay attacks across multiple wallets, the protocol employs deterministic nullifiers. A nullifier is generated from the hash of the user's device-bound secret, the target protocol address, and the specific credential ID, ensuring a single proof cannot be reused to bypass compliance gates.
4. **Decoupled Trust Anchors:** The system separates the verification mathematics from the institutional trust model. The `nullpass_verifier` contract handles pure cryptography, while the `nullpass_registry` contract serves as the upgradable, governance-controlled directory of authorized credential issuers.

## 3. Technology Stack
1. **Smart Contract Language:** Rust version 1.76.0.
2. **Smart Contract Framework:** Soroban SDK version 20.0.0.
3. **Zero-Knowledge Circuit Language:** Noir version 0.31.0.
4. **Frontend Framework:** Next.js version 14.1.0 using the App Router.
5. **Frontend Language:** TypeScript version 5.4.2.
6. **Decentralized Storage:** `nft.storage` for IPFS metadata.
7. **Backend API Environment:** Node.js version 20.11.1 LTS with Express version 4.18.2.
8. **Database:** PostgreSQL version 16.
9. **ORM:** Prisma version 5.10.0.
10. **Infrastructure/Hosting:** Vercel (Frontend/API) and Supabase (PostgreSQL).

## 4. Smart Contract Architecture

### Contract 1: `nullpass_verifier.rs`
**Responsibility:** The cryptographic engine of the system. It receives Groth16 proofs, unpacks the public inputs, invokes the BN254 pairing host functions, verifies nullifier uniqueness, and mints the AccessPass upon successful mathematical validation.
**Public Functions:**
1. `verify_proof(env: Env, proof: Bytes, public_inputs: Vec<BytesN<32>>, vk_hash: BytesN<32>) -> Result<bool, VerifierError>`
2. `check_nullifier(env: Env, nullifier: BytesN<32>) -> Result<(), VerifierError>`
3. `mint_access_pass(env: Env, user: Address, claims_level: u32, expiry_ledger: u32) -> Result<(), VerifierError>`
4. `revoke_pass(env: Env, user: Address, protocol: Address) -> Result<(), VerifierError>`

### Contract 2: `nullpass_registry.rs`
**Responsibility:** The governance-controlled directory. It maintains the whitelist of trusted credential issuers and stores the valid Verification Keys (VKs) for the Noir circuits.
**Public Functions:**
1. `add_issuer(env: Env, issuer_pubkey: BytesN<32>, metadata_cid: String) -> Result<(), RegistryError>`
2. `remove_issuer(env: Env, issuer_pubkey: BytesN<32>) -> Result<(), RegistryError>`
3. `get_trusted_issuers(env: Env) -> Vec<BytesN<32>>`
4. `update_vk(env: Env, circuit_version: u32, vk_payload: Bytes) -> Result<(), RegistryError>`

### Contract 3: `nullpass_gate.rs`
**Responsibility:** An importable integrator library. It provides zero-logic wrapper functions that DeFi protocols import directly into their own Soroban contracts to gate access.
**Public Functions:**
1. `has_valid_pass(env: Env, user: Address, required_level: u32) -> bool`
2. `require_pass(env: Env, user: Address, required_level: u32) -> Result<(), GateError>`
3. `get_pass_level(env: Env, user: Address) -> Result<u32, GateError>`

## 5. Data Flow Diagrams

**Action 1: Credential Issuance (Off-Chain)**
1. The user navigates to a trusted KYC provider's portal and completes traditional identity verification.
2. The KYC provider's backend executes the `@nullpass/issuer` SDK to construct a JSON Verifiable Credential containing the user's claims.
3. The KYC provider generates a cryptographic signature over the payload using their registered private key.
4. The provider transmits the raw JSON and the signature payload back to the user via a secure HTTPS connection.
5. The user's device stores the credential payload inside their encrypted local Credential Wallet.
6. The provider uploads their updated public directory metadata to `nft.storage` and receives an IPFS CID.

**Action 2: ZK Proof Generation (Client-Side)**
1. The user attempts to interact with a regulated Soroban DeFi protocol that has implemented `nullpass_gate.rs`.
2. The protocol prompts the user's browser extension to generate a compliance proof.
3. The `@nullpass/prover` SDK initializes the Noir WASM circuit locally within the user's browser.
4. The SDK injects the private inputs: the user's stored credential JSON, the provider's signature, and a biometric-derived passkey secret.
5. The SDK injects the public inputs: the target DeFi protocol address, the required claims level, and the current ledger timestamp.
6. The WASM circuit executes the constraints, verifying the signature and claims locally.
7. The circuit outputs the Groth16 proof byte array, the deterministic nullifier, and the hashed public inputs.

**Action 3: On-Chain Verification and Pass Minting**
1. The frontend submits a transaction to `nullpass_verifier.rs` calling `verify_proof`, passing the generated proof and inputs.
2. The contract queries `nullpass_registry.rs` to fetch the valid Verification Key and ensure the issuer is trusted.
3. The contract executes the `check_nullifier` function. If the nullifier exists, the transaction reverts to prevent replay.
4. The contract invokes the native BN254 host functions to run the mathematical pairing check on the Groth16 proof.
5. Upon mathematical success, the contract writes the nullifier to storage.
6. The contract calls `mint_access_pass`, writing the temporary `AccessPass` to the user's address.
7. The DeFi protocol subsequently calls `require_pass()`, which successfully reads the active pass, and the user's trade executes securely.

## 6. SDK Architecture

### TypeScript SDK 1: `@nullpass/prover`
* `constructor(network: string, rpcUrl: string) -> NullpassProver`
* `loadCircuitWasm(circuitPath: string) -> Promise<void>`
* `deriveUserSecret(passkeySignature: Uint8Array) -> string`
* `generateProof(credential: CredentialPayload, issuerSignature: string, userSecret: string, protocolAddress: string, claimsLevel: number) -> Promise<ProofData>`
* `formatPublicInputs(proofData: ProofData) -> Array<string>`
* `submitProofTransaction(proofData: ProofData, walletConnector: any) -> Promise<string>`

### TypeScript SDK 2: `@nullpass/issuer`
* `constructor(issuerDid: string, privateKey: string, network: string) -> NullpassIssuer`
* `constructCredential(subjectHash: string, claims: Record<string, any>, expiryTimestamp: number) -> CredentialPayload`
* `signCredential(credential: CredentialPayload) -> string`
* `revokeCredential(credentialId: string, reason: string) -> Promise<string>`
* `publishMetadataToNftStorage(metadata: IssuerMetadata, nftStorageApiKey: string) -> Promise<string>`

### TypeScript SDK 3: `@nullpass/integrator`
* `constructor(protocolAddress: string, verifierAddress: string, network: string) -> NullpassIntegrator`
* `checkPassValidityOffChain(userAddress: string, requiredLevel: number) -> Promise<boolean>`
* `buildGatedTransaction(userAddress: string, innerTransaction: any, requiredLevel: number) -> Promise<any>`

### Python SDK: `nullpass-py`
* `__init__(self, network: str, rpc_url: str, admin_secret: str) -> None`
* `add_trusted_issuer(self, issuer_pubkey: str, metadata_cid: str) -> Dict`
* `remove_trusted_issuer(self, issuer_pubkey: str) -> Dict`
* `update_verification_key(self, circuit_version: int, vk_path: str) -> Dict`
* `fetch_issuer_metadata(self, metadata_cid: str) -> Dict`

## 7. Frontend Architecture
1. **Page: `/` (Landing Page):** Explains NULLPASS privacy architecture.
2. **Page: `/wallet` (Credential Wallet):** Renders the user's locally stored credentials.
3. **Page: `/prove` (Proof Generator):** The interface for selecting a protocol and generating the ZK proof.
4. **Page: `/issuers` (Issuer Directory):** Displays the trusted issuers fetched from the registry and `nft.storage`.
5. **Component: `CredentialCard.tsx`:** A highly styled card displaying credential details without exposing the raw payload.
6. **Component: `ProofProgressTracker.tsx`:** A visual progress bar detailing the WASM initialization and proof generation phases.
7. **Component: `WalletConnector.tsx`:** Freighter wallet integration for transaction signing.
8. **Hook: `useNullpassProver.ts`:** Manages the lifecycle of the `@nullpass/prover` SDK, handling web worker delegation.
9. **Hook: `useIssuerRegistry.ts`:** Fetches the active issuer list from the Soroban contract.
10. **Context: `CredentialStoreContext.tsx`:** Manages the encrypted local storage state of credentials.

## 8. Off-Chain Infrastructure
1. **Service: `nullpass-api`:** An Express.js application acting as a read-heavy relay and metadata cache.
2. **Endpoint: `POST /verify/relay`:** An optional endpoint allowing users to submit proofs through a sponsored relayer.
3. **Endpoint: `GET /issuers/metadata/:cid`:** A caching layer that proxies requests to `nft.storage` to reduce IPFS latency.
4. **Service: `nullpass-indexer`:** A Node.js worker polling the Stellar Horizon RPC for `ProofVerifiedEvent` and `PassRevokedEvent`.
5. **Database Model: `AccessLog`:** A PostgreSQL table managed via Prisma storing anonymized records of pass minting.

## 9. Security Model
1. **Threat Vector: Proof Replay (Double Spend).**
   **Mitigation:** The Noir circuit binds the deterministic nullifier to the user's public key and target protocol. `nullpass_verifier.rs` strictly validates the `check_nullifier` storage map.
2. **Threat Vector: Forged Credentials.**
   **Mitigation:** The Noir circuit enforces an Ed25519 signature verification constraint matching an authorized issuer in the registry.
3. **Threat Vector: Malicious Circuit Substitution.**
   **Mitigation:** `nullpass_verifier.rs` checks the proof against the specific Verification Key (VK) stored on-chain. Modified circuits will fail the BN254 pairing check.
4. **Threat Vector: Stale Verification Keys.**
   **Mitigation:** `update_vk` allows governance to publish patched VKs, instantly deprecating older proof standards.

## 10. Integration Points
1. **Soroban Protocol 25 Native Host Functions:** Direct integration of `env.crypto().bn254_pairing()` and `env.crypto().poseidon()`.
2. **Stellar Horizon RPC:** Used by frontend, SDKs, and indexer.
3. **nft.storage API:** Used for immutable issuer metadata.
4. **Third-Party Soroban Protocols:** Direct integration of `nullpass_gate.rs` into DeFi deposit/swap functions.

## 11. Testing Strategy
1. **Circuit Tests (`test_basic_kyc.nr`):** Executed via `nargo test` to prove constraint soundness.
2. **Unit Tests (`test_verify.rs`, `test_nullifier.rs`):** Tests individual Rust contract functions.
3. **Integration Tests (`test_access_pass.rs`):** Deploys a mock DeFi protocol alongside the verifier and registry.
4. **SDK Tests (`prover.test.ts`):** Uses Jest to test TypeScript WASM bindings.
5. **End-to-End Tests (Playwright):** Simulates the full `/prove` journey in the browser.

## 12. Deployment Architecture
1. **Testnet Deployment Sequence:**
   1. Compile Noir circuit using `nargo compile`.
   2. Execute `generate-vk.sh` to extract the VK.
   3. Compile WASM using `soroban contract build --profile release`.
   4. Deploy `nullpass_registry.wasm` to Testnet.
   5. Deploy `nullpass_verifier.wasm` to Testnet and initialize.
   6. Invoke `update_vk` to upload the extracted VK.
2. **Mainnet Deployment Sequence:**
   1. Deploy contracts via an offline multi-signature hardware wallet setup.
   2. Initialize the registry with the Mainnet Multisig as the Governance Admin.
   3. Upload the production Verification Key.
3. **Post-Deploy Verification:** Execute `test-proof.sh` script to submit a read-only proof verification.

## 13. Upgrade and Governance Strategy
1. The `nullpass_verifier` and `nullpass_registry` contracts implement the standard Soroban WASM upgrade functions.
2. The `nullpass_gate` library is immutable.
3. Upgrading the Verification Key (`update_vk`) requires a 48-hour timelock and multisig approval.

---

## PART 2 — FULL PRODUCTION PROGRESS TRACKER

### Phase 0 — Repository & Environment Setup
- [ ] Initialize Git repository named `nullpass-monorepo`.
- [ ] Configure Turborepo for monorepo management across circuits, contracts, and frontend.
- [ ] Create `circuits`, `contracts`, `sdk`, `api`, and `app` subdirectories.
- [ ] Initialize a new Rust workspace in the `contracts` directory.
- [ ] Configure `Cargo.toml` with workspace members `nullpass-verifier`, `nullpass-registry`, and `nullpass-gate`.
- [ ] Install Rust toolchain version 1.76.0.
- [ ] Install `soroban-cli` version 20.0.0 globally.
- [ ] Install Noir version 0.31.0 via `noirup`.
- [ ] Add `wasm32-unknown-unknown` target to the Rust toolchain.
- [ ] Set up GitHub Actions workflow file `.github/workflows/test-circuits.yml` to run `nargo test`.
- [ ] Set up GitHub Actions workflow file `.github/workflows/test-contracts.yml` to run `cargo test`.

### Phase 1 — Smart Contract Development
- [ ] Write the `VerifierError` enum definition in `nullpass-verifier/src/errors.rs`.
- [ ] Write the `PassData` struct definition in `nullpass-verifier/src/types.rs`.
- [ ] Implement the `verify_proof(env: Env, proof: Bytes, public_inputs: Vec<BytesN<32>>, vk_hash: BytesN<32>)` function using `env.crypto().bn254_pairing()` in `nullpass-verifier/src/verify.rs`.
- [ ] Implement the `check_nullifier(env: Env, nullifier: BytesN<32>)` storage write and check logic in `nullpass-verifier/src/nullifier.rs`.
- [ ] Implement the `mint_access_pass(env: Env, user: Address, claims_level: u32, expiry_ledger: u32)` function in `nullpass-verifier/src/access_pass.rs`.
- [ ] Implement the `revoke_pass(env: Env, user: Address, protocol: Address)` function in `nullpass-verifier/src/access_pass.rs`.
- [ ] Write the `RegistryError` enum definition in `nullpass-registry/src/errors.rs`.
- [ ] Implement the `add_issuer(env: Env, issuer_pubkey: BytesN<32>, metadata_cid: String)` function in `nullpass-registry/src/issuers.rs`.
- [ ] Implement the `remove_issuer(env: Env, issuer_pubkey: BytesN<32>)` function in `nullpass-registry/src/issuers.rs`.
- [ ] Implement the `update_vk(env: Env, circuit_version: u32, vk_payload: Bytes)` function in `nullpass-registry/src/vk_store.rs`.
- [ ] Write the `GateError` enum definition in `nullpass-gate/src/errors.rs`.
- [ ] Implement the `has_valid_pass(env: Env, user: Address, required_level: u32)` function in `nullpass-gate/src/gate.rs`.
- [ ] Implement the `require_pass(env: Env, user: Address, required_level: u32)` function in `nullpass-gate/src/gate.rs`.

### Phase 2 — Contract Testing
- [ ] Write unit test `test_verify_proof_accepts_valid_groth16_proof` in `nullpass-verifier/tests/test_verify.rs`.
- [ ] Write unit test `test_verify_proof_rejects_invalid_public_inputs` in `nullpass-verifier/tests/test_verify.rs`.
- [ ] Write unit test `test_check_nullifier_reverts_on_duplicate_hash` in `nullpass-verifier/tests/test_nullifier.rs`.
- [ ] Write unit test `test_mint_access_pass_writes_correct_expiry` in `nullpass-verifier/tests/test_access_pass.rs`.
- [ ] Write unit test `test_add_issuer_requires_admin_auth` in `nullpass-registry/tests/test_issuers.rs`.
- [ ] Write unit test `test_update_vk_stores_bytes_correctly` in `nullpass-registry/tests/test_vk_store.rs`.
- [ ] Write unit test `test_require_pass_reverts_if_no_pass_exists` in `nullpass-gate/tests/test_gate.rs`.
- [ ] Write integration test `test_full_verification_and_gating_flow` spanning all three contracts in `nullpass-verifier/tests/test_integration.rs`.

### Phase 3 — SDK Development (TypeScript)
- [ ] Initialize `@nullpass/prover` package in `sdk/typescript/prover`.
- [ ] Implement `loadCircuitWasm(circuitPath: string)` using the `@noir-lang/backend_barretenberg` package.
- [ ] Implement `deriveUserSecret(passkeySignature: Uint8Array)` function.
- [ ] Implement `generateProof(...)` to map JSON credentials into Noir field elements.
- [ ] Initialize `@nullpass/issuer` package in `sdk/typescript/issuer`.
- [ ] Implement `constructCredential(...)` JSON formatter.
- [ ] Implement `signCredential(credential: CredentialPayload)` using `tweetnacl`.
- [ ] Implement `publishMetadataToNftStorage(metadata, apiKey)` using the `nft.storage` client package.
- [ ] Initialize `@nullpass/integrator` package in `sdk/typescript/integrator`.
- [ ] Implement `checkPassValidityOffChain(...)` by invoking the Horizon API.
- [ ] Write Jest test `test_generate_proof_creates_valid_byte_array` in `sdk/typescript/prover/tests/prover.test.ts`.
- [ ] Write Jest test `test_sign_credential_matches_ed25519_spec` in `sdk/typescript/issuer/tests/issuer.test.ts`.

### Phase 4 — SDK Development (Python)
- [ ] Initialize `nullpass-py` Poetry project in `sdk/python/nullpass`.
- [ ] Implement the `NullpassAdmin` class constructor.
- [ ] Implement `add_trusted_issuer(self, issuer_pubkey: str, metadata_cid: str)` using the Python Stellar SDK.
- [ ] Implement `remove_trusted_issuer(self, issuer_pubkey: str)`.
- [ ] Implement `update_verification_key(self, circuit_version: int, vk_path: str)`.
- [ ] Write pytest test `test_add_trusted_issuer_builds_correct_xdr` in `sdk/python/tests/test_admin.py`.

### Phase 5 — Frontend Development
- [ ] Initialize Next.js 14 App Router project in the `app` directory.
- [ ] Configure `tsconfig.json` to enforce `.tsx` and `.ts` strictness.
- [ ] Install Tailwind CSS, Framer Motion, and `@stellar/freighter-api`.
- [ ] Build the layout structure in `app/src/app/layout.tsx`.
- [ ] Build the landing page in `app/src/app/page.tsx` containing `HeroSection.tsx`.
- [ ] Build the `app/src/app/wallet/page.tsx` view for the Credential Wallet.
- [ ] Build the `CredentialCard.tsx` component to parse and display local JSON claims.
- [ ] Build the `app/src/app/prove/page.tsx` view.
- [ ] Build the `CircuitRunner.tsx` component to instantiate the web worker for Noir WASM processing.
- [ ] Build the `ProofProgressTracker.tsx` component to display generating states.
- [ ] Build the `app/src/app/issuers/page.tsx` view.
- [ ] Build the `IssuerGrid.tsx` component integrating calls to the `nft.storage` IPFS gateways.
- [ ] Build the `WalletConnector.tsx` component for Freighter.
- [ ] Implement the `useNullpassProver.ts` hook to abstract SDK calls.

### Phase 6 — Off-Chain Infrastructure
- [ ] Initialize an Express.js project in the `api` directory.
- [ ] Initialize Supabase project and obtain PostgreSQL connection strings.
- [ ] Initialize Prisma ORM with `npx prisma init`.
- [ ] Write Prisma schema in `api/prisma/schema.prisma` defining the `AccessLog` model.
- [ ] Run `npx prisma db push` to synchronize the database schema.
- [ ] Write the `indexer.ts` background script to poll Horizon RPC for `ProofVerifiedEvent`.
- [ ] Write Prisma insertion logic inside `indexer.ts` to save anonymized pass data to the database.
- [ ] Write Express route `POST /verify/relay` to accept client proofs and wrap them in fee-sponsored transactions.
- [ ] Write Express route `GET /issuers/metadata/:cid` to proxy and cache `nft.storage` JSON payloads.
- [ ] Create a `Dockerfile` for the API and Indexer services.

### Phase 7 — Documentation
- [ ] Write `README.md` at the monorepo root explaining project structure and startup commands.
- [ ] Write `contracts/README.md` detailing the BN254 host function usage and Soroban integration.
- [ ] Write `circuits/README.md` documenting the Groth16 constraints and Noir implementation.
- [ ] Write `sdk/typescript/prover/README.md` containing installation instructions and browser WASM requirements.
- [ ] Create the `docs/architecture.md` file pasting this entire architecture specification.
- [ ] Create the `docs/issuer-guide.md` explaining how KYC providers construct JSON and upload to `nft.storage`.
- [ ] Create the `docs/integrator-guide.md` showing DeFi developers how to use `require_pass()`.

### Phase 8 — Security & Audit Preparation
- [ ] Run `cargo clippy --all-targets` and resolve all warnings in the Rust contracts.
- [ ] Run `nargo check` to verify circuit constraint soundness.
- [ ] Document the exact nullifier generation mathematical sequence in `docs/security.md`.
- [ ] Write an explicit threat model for malicious circuit substitution and the VK mitigation strategy.
- [ ] Compile a frozen version of the Soroban WASM binaries and generate SHA-256 checksums.
- [ ] Extract the frozen Verification Key from the Noir compiler and document the byte array for the auditors.

### Phase 9 — Testnet Deployment & QA
- [ ] Fund a Stellar Testnet account using the Friendbot faucet.
- [ ] Compile the Noir circuit and execute `generate-vk.sh` to extract the Testnet Verification Key.
- [ ] Deploy `nullpass_registry.wasm` to Testnet and initialize it.
- [ ] Invoke `update_vk` on the Testnet registry with the extracted key payload.
- [ ] Deploy `nullpass_verifier.wasm` to Testnet and link it to the registry.
- [ ] Upload mock issuer metadata to `nft.storage` and invoke `add_issuer` on the Testnet registry.
- [ ] Update `.env.testnet` files in the frontend and API directories with the new contract IDs.
- [ ] Deploy the `.tsx` frontend to a Vercel staging environment.
- [ ] Deploy the API and Indexer to a staging AWS ECS cluster.
- [ ] Perform a manual end-to-end test on the staging URL: load mock credential, run in-browser circuit, submit transaction, and verify pass minting.

### Phase 10 — Mainnet Deployment
- [ ] Generate strict offline hardware wallet keys for the Mainnet Governance Multisig.
- [ ] Configure the multisig account parameters on Stellar Mainnet.
- [ ] Deploy `nullpass_registry.wasm` to Mainnet and initialize with the Multisig address.
- [ ] Upload the audited production Verification Key to the Mainnet registry.
- [ ] Deploy `nullpass_verifier.wasm` to Mainnet and link to the registry.
- [ ] Update production environment variables across Vercel and AWS to point to Mainnet contract IDs and Horizon endpoints.
- [ ] Push the final production release to the master branch to trigger live deployment.
- [ ] Execute a live, read-only proof verification script against the deployed Mainnet contract to ensure BN254 host functions are operating flawlessly.

### Phase 11 — Wave Program Onboarding
- [ ] Configure the open-source repository tags and descriptions on GitHub.
- [ ] Apply to the Stellar Drips Wave Program platform as a maintainer.
- [ ] Populate the `.github/ISSUE_TEMPLATE/contributor_task.md` file.
- [ ] Create 10 specific "Good First Issue" tickets targeting circuit constraints, TypeScript SDK methods, and TSX component styling.
- [ ] Tag the issues with the appropriate Wave Program labels.
- [ ] Write a `CONTRIBUTING.md` guide tailored to navigating the Noir and Rust WASM environments for Wave sprint participants.

### Phase 12 — Post-Launch Maintenance Setup
- [ ] Set up Datadog or Sentry error tracking in the Next.js frontend to monitor WASM compilation crashes.
- [ ] Set up PM2 or Docker health checks for the `nullpass-indexer` service to alert on downtime.
- [ ] Configure PagerDuty alerts for any Supabase database connection failures or `nft.storage` API gateway timeouts.
- [ ] Establish a 48-hour timelock calendar alert system for any future `update_vk` governance transactions.