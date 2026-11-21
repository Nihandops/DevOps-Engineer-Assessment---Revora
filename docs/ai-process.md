# AI-Assisted Process Documentation

This document outlines the process used to design, build, and verify the PostgreSQL HA cluster. It is structured to demonstrate repeatability, determinism, and how the playbook generalizes to other tasks.

## 1. Determinism
To ensure consistent output and prevent the AI from hallucinating or drifting, I enforced strict determinism in the following ways:
*   **Specs before code:** I wrote the `acceptance-criteria.md` (derived from the PDF) first. Every prompt referenced these criteria before generating any YAML.
*   **Pinned Versions:** I explicitly pinned `PostgreSQL 16`, `k3s v1.28`, and `Patroni 3.3`. If the AI suggested a different version, I rejected it.
*   **Structured Prompts:** I used a consistent template for every prompt:
    *   *Context:* What are we building?
    *   *Constraints:* No operators, single-node k3s, specific storage classes.
    *   *Desired Output:* Single YAML manifest, including inline comments.
    *   *Verification:* "List anything you are unsure about so I can verify it."
*   **Model-Dependent Judgement:** The only parts that depended on the model were debugging specific error logs (e.g., `ImagePullBackOff`, or the `fe_sendauth` password error) and suggesting alternative approaches when the first one failed (like using `pg_rewind` versus a full re-clone).

## 2. Agent-Agnosticism
The process is designed to be reproducible across different AI agents (e.g., ChatGPT, Claude, Gemini). 
*   **Vendor-Specific vs. General Method:** I did not use any vendor-specific features (like ChatGPT's custom GPTs or Claude's artifacts) to generate the core infrastructure. The playbook relies solely on standard text generation.
*   **Prompt Portability:** The prompts are stored in the `prompts/` directory. Any agent that can read a Markdown file and generate YAML can execute this playbook. If a different agent was used, the output would be nearly identical because the constraints (Kubernetes API DCS, no operators) force a specific architecture.

## 3. Generalization (Applying the Playbook to New Tasks)
If I were tasked with building **"HA Redis with Sentinel on Kubernetes"** or **"HA HashiCorp Vault with Raft storage"**, here is how I would reuse this playbook:

*   **Files I would reuse unchanged:**
    *   `Makefile` (the `up`, `down`, `status` structure remains identical).
    *   `namespace.yaml` (namespaces are generic).
    *   `rbac.yaml` (the structure of ServiceAccounts and Roles is the same; only the names change).
    *   The video recording and testing scripts (the methodology of deleting a pod and checking for failover is universal).

*   **Files I would rewrite from scratch:**
    *   `StatefulSet.yaml` (Redis requires different ports, image, and a Sentinel sidecar).
    *   `Services.yaml` (Vault requires different endpoints for UI and API).
    *   `ConfigMap.yaml` (Vault uses HCL configuration, not YAML; Redis uses `redis.conf`).
    *   The backup strategy (Redis uses RDB/AOF, not pgBackRest).

## 4. Second AI Agent Comparison (Optional Requirement)
To test the repeatability of the process, I ran the **failover implementation phase** (generating the Patroni configuration) through a second, different AI agent.

*   **Similarities:** Both agents correctly identified that `synchronous_mode: true` was required for an RPO of zero. Both agents correctly used the Kubernetes API block (`kubernetes: namespace: pg-ha`) instead of configuring an external etcd cluster. Both correctly set `use_pg_rewind: true` to handle rejoining the old primary.
*   **Differences:** 
    *   *Agent A* (used for the primary build) defaulted `maximum_lag_on_failover` to `1048576` (1MB).
    *   *Agent B* defaulted it to `16MB`.
    *   *Resolution:* I chose the 1MB setting from Agent A. In the review, I can explain that a smaller lag threshold is safer for an RPO=0 claim, as Patroni will refuse to promote a replica that is too far behind, preventing accidental data loss.
