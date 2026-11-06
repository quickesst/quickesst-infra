# Quickesst Infra

Infrastructure as code for the Quickesst platform: Kubernetes, Terraform modules and deployment tooling.

## Purpose

This repository describes, as code, the infrastructure that runs the Quickesst platform. It is built around three commitments:

- **Modern** — everything is declarative, versioned and reproducible: Kubernetes, Terraform, operators instead of hand-run scripts, and CI-driven deployments.
- **Secure** — a zero-trust approach: no implicit trust in the network, encryption in transit and at rest, least privilege everywhere, defense in depth, and no secrets in code.
- **Sovereign and European** — the platform runs on European providers, and data is never processed by services subject to non-European jurisdictions such as the US CLOUD Act. This is a deliberate architectural and commercial choice, consistent with GDPR and with the expectations of our users regarding their personal data.

The application code (API, BFFs, frontends) lives in separate repositories.

## Architecture

### Environments

| Environment | Platform | Purpose |
|---|---|---|
| Local | Docker Compose | Application development, unit and integration tests |
| Dev | k3s on a dedicated server | First real Kubernetes environment, infrastructure development |
| Staging | k3s on a dedicated server | Functional testing and QA |
| Preprod | Scaleway Kubernetes Kapsule | Exact replica of production; final validation of CI, infrastructure and application before release. Not a QA environment. |
| Prod | k3s on a separate dedicated server at launch, then Scaleway Kubernetes Kapsule | Production |

Preprod and prod run in **separate clusters**. Preprod uses the same modules, versions and topology as prod; only sizes differ. Its data is a copy of production, **anonymised before it leaves the production perimeter**, with generated documents in place of real ones.

A later move to **Scaleway Kosmos** (multi-provider nodes) is planned for resilience. See [Network](#network).

### Components

| Layer | Component | Role |
|---|---|---|
| Network (CNI) | Cilium | Pod networking and enforcement of standard `NetworkPolicy` |
| Service mesh | Linkerd *(planned)* | Mutual TLS between services, workload identity, L7 authorisation |
| Platform | cert-manager | Certificate issuance and rotation |
| Database | CloudNativePG | PostgreSQL operator: instances, roles, databases, failover |
| Identity | Zitadel | OIDC identity provider |
| Backups | Barman Cloud plugin | Continuous WAL archiving and base backups to S3-compatible storage |
| Secrets | Vault + External Secrets *(planned)* | Single source of truth for secrets |

### Network

- **CNI:** Cilium on self-managed clusters and on Kapsule. When moving to Kosmos, the CNI becomes Kilo (WireGuard mesh between nodes and providers).
- To keep that move painless, this repository **does not rely on Cilium-specific features**: only standard Kubernetes `NetworkPolicy`, and service-to-service security handled by Linkerd, which works on any CNI.
- **Default deny:** every namespace denies all traffic by default; each required flow is opened explicitly.
- **Egress:** only the components that need it may reach the Internet, restricted to their destinations.

## Repository structure

The Terraform code and its deployment tasks are added topic by topic (see [Roadmap](#roadmap)). Entries marked *(planned)* are not in the repository yet.

```
main.tf                          # (planned) root module: providers and module composition
modules/                         # (planned)
  platform/                      # cert-manager, Cilium (self-managed clusters only)
  postgres/                      # CloudNativePG operator, backup plugin, PostgreSQL instance
  database/                      # roles, credentials, pg_hba, databases
  zitadel/                       # Zitadel and its secrets
  backup/                        # object storage bucket, credentials, ObjectStore, scheduled backups
scripts/                         # (planned)
  shipper/
    shipper-infra-deploy.yaml    # Task definitions for infrastructure deployment
Taskfile.yml                     # (planned) Task entry point
flake.nix                        # Nix development shell with pinned tooling
flake.lock                       # exact versions of the Nix inputs (committed)
.terraform.lock.hcl              # (planned) exact provider versions and checksums
.pre-commit-config.yaml          # pre-commit hooks (gitleaks)
.env.example                     # required environment variables (no values)
.gitignore                       # excludes secrets, Terraform state and local artefacts
.envrc                           # direnv: loads the Nix development shell on entering the directory
k3s/                             # k3s server settings for self-managed clusters (dev, staging)
  config.yaml                    # installed as /etc/rancher/k3s/config.yaml
  audit-policy.yaml              # Kubernetes API audit policy
  pod-security.yaml              # Pod Security Admission defaults
renovate.json                    # dependency update policy (Renovate)
```

Each module has `development` and `production` variants selected from the current environment, sharing a `common` implementation.

### Dependency order

```
platform (CNI, cert-manager)
  └─ postgres (operator, backup plugin, instance)
       ├─ database (roles, pg_hba, databases)
       │    └─ zitadel
       └─ backup
```

## Prerequisites

- Nix with flakes enabled, and direnv (development shell with pinned tooling)
- Docker with Docker Compose (local development)
- Terraform **≥ 1.11** (required for ephemeral values and write-only arguments)
- [Task](https://taskfile.dev)
- kubectl and Helm
- gitleaks (pre-commit hook)
- Access to the target cluster and to the Terraform state backend

## Getting started

1. Copy the environment template and fill in the credentials:

   ```bash
   cp .env.example .env
   chmod 600 .env
   ```

   | Variable | Used by |
      |---|---|
   | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Terraform state backend (S3-compatible) |
   | `MINIO_USER` / `MINIO_PASSWORD` | MinIO provider (bucket and user management) |

   `.env` is loaded by Task and must never be committed. In CI, the same variables come from the CI secret store.

2. Deploy (available once the Terraform modules and deployment tasks are merged):

   ```bash
   task shipper:default
   ```

   The deployment script sets the target environment (`TF_VAR_qks_current_env`).

## Conventions

- **Pinned versions** for every provider and Helm chart. `.terraform.lock.hcl` is committed. Do not run `terraform init -upgrade` routinely: updates go through Renovate pull requests.
- **Dependency updates with [Renovate](https://docs.renovatebot.com):** Renovate watches Terraform providers, Helm chart versions, container images and the Nix flake inputs, and opens a pull request for each update. A **minimum release age** delays every update by a few days after its publication, so that broken or compromised releases are usually withdrawn before they reach this repository. Each pull request goes through the full CI pipeline; updates to critical components (PostgreSQL, CloudNativePG, Zitadel, Cilium, Vault) are never merged automatically.
- Root modules pin exact provider versions; child modules only declare minimum versions.
- **No secrets in code, plans or logs.** Generated secrets are alphanumeric and long (64 characters), which avoids escaping issues in connection strings, YAML and shells.
- **Critical resources are protected** with `lifecycle { prevent_destroy = true }`: Zitadel masterkey, database role passwords, PostgreSQL cluster, backup bucket.
- **Plans are reviewed before apply** in preprod and prod. CI fails on any destroy or replacement of a protected resource.
- One branch per topic, with a verifiable completion criterion in each ticket.

## Security

- **Zero trust:** default-deny network policies, mutual TLS between services (Linkerd), identity-based authorisation.
- **Least privilege:** dedicated, scoped credentials per component (for example, the backup user can only access its own bucket). Root credentials are only used for bootstrapping and kept offline.
- **Secrets:** today generated by Terraform and stored in Kubernetes Secrets; the state backend is encrypted at rest. Target: Vault as the single source of truth, synchronised by External Secrets, so that Terraform only handles references.
- **Admin accounts** are separate from day-to-day accounts and require hardware-backed MFA. A break-glass account, independent of Zitadel, is kept in the crisis vault.
- **Crisis vault:** encryption keys and recovery material (Zitadel masterkeys, Vault unseal keys, backup storage credentials, restore procedure) are encrypted with at least two YubiKeys stored in separate locations.
- Pre-commit and CI run gitleaks to prevent any secret from entering the history.

## Operations

### Health checks

```bash
kubectl get nodes
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl get cluster -n postgres
kubectl get backups -n postgres
```

### Backups and restore

- PostgreSQL is backed up as a **whole instance** (base backups + continuous WAL archiving), allowing point-in-time recovery.
- Restores always create a **new cluster** from the backup; the decision to restore is always made by a human.
- A restore drill into an ephemeral cluster runs regularly to prove backups are usable.

## Known pitfalls

- **Zitadel chart:** the configuration secret key must be `config-yaml` (chart default), not `config.yaml`. Otherwise the configuration is silently ignored.
- **Zitadel domain:** `ExternalDomain` and `ExternalPort` are recorded when the instance is created. Changing them later requires a fresh instance (reset the `zitadel` database).
- **Zitadel masterkey:** must be exactly 32 characters, and **must be backed up**. Losing it makes all encrypted Zitadel data unrecoverable, even with a database backup.
- **Passwords with special characters** break connection strings in some clients (Zitadel among them). Use long alphanumeric passwords instead.
- **Cross-namespace secrets:** a pod can only mount Secrets from its own namespace. Until Vault and External Secrets are in place, secrets are copied by Terraform.
- **CloudNativePG `Database` resources** recreate a dropped database **empty**: a manual `DROP DATABASE` is silently masked.
- **Helm keeps CRDs** on uninstall (CloudNativePG); remove them manually for a full cleanup.
- **Kosmos does not support Scaleway Private Networks**; Kapsule does.

## Roadmap

- [x] Repository bootstrap (gitignore, gitleaks, CI lint)
- [ ] CNI (Cilium)
- [ ] Platform (cert-manager)
- [ ] PostgreSQL instance
- [ ] Databases and roles
- [ ] Zitadel
- [ ] Backups
- [ ] Vault and External Secrets
- [ ] Network policies (default deny)
- [ ] Linkerd