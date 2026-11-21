# PostgreSQL High Availability on Kubernetes

**Author:** MD. Saidur Rahman Nihan
**Assignment:** PostgreSQL HA on Kubernetes (Patroni + k3s)

## 1. Architecture Overview

This project deploys a highly available PostgreSQL 16 cluster on a single-node Kubernetes cluster (k3s).

- **Replication:** 1 primary and 2 replicas using physical streaming replication.
- **Orchestration:** Patroni provides high availability. The Kubernetes API is used as the Distributed Configuration Store (DCS) for leader election and split-brain prevention.
- **Consistency (RPO):** Synchronous replication is enabled (`synchronous_mode: true`). The RPO is 0 for committed transactions: if the primary crashes, the synchronous replica has every committed transaction.
- **Client connectivity:** Applications connect to `pg-primary.pg-ha.svc.cluster.local` (read-write) and `pg-replicas.pg-ha.svc.cluster.local` (read-only). Patroni labels each pod with its current role, and the Services select pods by that label, so after a failover traffic follows the new leader and connection strings never change.

### Components

| Component | Role |
|---|---|
| `pg-0` | Initial primary (Patroni + PostgreSQL 16, ports 5432 / 8008) |
| `pg-1` | Synchronous replica |
| `pg-2` | Asynchronous replica |
| Kubernetes DCS | Leader lease and cluster configuration |
| `pg-primary` Service | ClusterIP, routes to the current leader |
| `pg-replicas` Service | ClusterIP, routes to replicas |

## 2. Prerequisites

- Ubuntu Server 24.04 VM
- k3s installed
- `kubectl` and `make` installed

## 3. How to Run (Single Entry Point)

The entire deployment can automated via a Makefile.

Deploy the cluster with Makefile:

```bash
make up
```

Check the cluster status:

```bash
make status
```

Test automatic failover (deletes the primary pod):

```bash
make test-failover
```

Tear down the entire environment:

```bash
make down
```

## 4. Evidence of Automatic Failover (RTO)

- **Start time:** 5:00
- **End time:** 6:00
- **Measured RTO:** 29 seconds

**Evidence:** During the live test, the primary pod was deleted. Patroni promoted a replica, and the old primary rejoined as a replica using `pg_rewind`. Data written before the failover (row 1) survived, and writes succeeded on the new primary (row 2) using the exact same connection string. This demonstrates zero data loss (RPO = 0).

## 5. Engineering Trade-offs & Custom Edits

To make this work on constrained hardware without operators, I made the following custom choices:

- **Patroni config injection:** A Python script in the init phase of `postgres-statefulset.yaml` injects Kubernetes environment variables (pod name, pod IP) into the Patroni YAML at startup.
- **Security:** The container runs as the `postgres` user, not `root`, and startup scripts use `set -e` to fail fast.
- **DCS choice:** I used the Kubernetes API as the DCS instead of a standalone `etcd` cluster. This saved roughly 1.5 GB of RAM, which was critical for a single-VM setup.

## 6. Known Limitations (What I Did Not Implement)

Per the assignment rules, I have documented what is incomplete and why:

- **Automated backups and PITR:** I did not implement pgBackRest or MinIO object storage. I focused on the replication and failover mechanics (the highest priority per the FAQ) rather than deploying a backup system I could not fully explain.
- **Monitoring:** I relied on `patronictl list` and Kubernetes native metrics rather than deploying a full Prometheus/Grafana stack, due to VM RAM constraints.
- **TLS:** PostgreSQL connections are not encrypted with TLS.
- **Single node:** All pods run on one k3s node, so this setup protects against pod and process failure, not node or host failure.

