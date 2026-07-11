# Study Plan

This document tracks the logical sequence of the field study. Each item builds on the previous one. All information is drawn from PostHog's public sources — handbook, pricing pages, product documentation, and exec responsibilities.

Commits tell the real story of progress. Check the git history.

---

- [x] 01 — Understand all PostHog products and how each one is sold
  - [x] What each product does
  - [x] Pricing model per product (usage-based, flat, freemium)
  - [x] Which products are self-serve only vs sales-assisted
  - [x] Upsell and cross-sell logic between products

- [x] 02 — Understand how marketing generates demand
  - [x] Intentional channels: SEO, technical content, YouTube, developer community
  - [x] Role of Charles Cook and the Demand Gen team
  - [x] How marketing amplifies word-of-mouth without being the origin of it

- [x] 03 — Understand how demand splits between self-serve and sales-led
  - [x] What triggers a self-serve conversion
  - [x] What triggers routing to a rep
  - [x] The blurred middle — accounts that pay self-serve but qualify for sales attention
  - [x] The organic PLG loop and its attribution implications

- [x] 04 — Understand the sales funnel end to end
  - [x] Lead origins per channel
  - [x] Qualification criteria (BANT, ICP score thresholds)
  - [x] Routing logic between TAE, TAM, and CSM
  - [x] Handoff points and ownership transitions

> **Context doc 1 — `products-and-sales-model.md`**
> Product structure and pricing mechanics: 15 products, billing metrics, free tiers, and commercial triggers per product. Platform packages (Boost, Scale, Enterprise) and the expansion logic. Why the attribution problem is structural.

> **Context doc 2 — `acquisition-funnel.md`**
> How PostHog generates demand, how it splits between self-serve and sales-led, routing criteria per team (TAE, TAM, BDR), lead scoring model, funnel flows, handoff failure modes, and RevOps implications.

---

- [x] 05 — Understand sales structure — TAE, TAM, CSM, BDR
  - [x] Role definitions and lead sources per role
  - [x] Book of business logic per role
  - [x] Performance floors and ramp periods

- [x] 06 — Understand ICP scoring model
  - [x] How the 70-point model is constructed in Salesforce
  - [x] What variables compose the score and their implied weights
  - [x] Whether the score has been validated against actual revenue outcomes (answer from public sources: it has not)

- [x] 07 — Understand compensation structure
  - [x] OTE structure per role
  - [x] Quota setting logic
  - [x] Commission sliding scale and accelerators
  - [x] What counts and what doesn't toward quota

> **Context doc 3 — `sales-structure-and-compensation.md`**
> Account lifecycle and role definitions. Lead sources and book of business per role. Full compensation mechanics for TAE, TAM, BDR, and Team Lead. Cross-sell multiplier table. Five structural gaps in the current model mapped to RevOps deliverables.

---

- [x] 08 — Map the five core challenges and produce proposed solutions
  - [x] Incentive misalignment in PLG attribution
  - [x] Absence of real-time revenue visibility
  - [x] No operating cadence for sales-led revenue
  - [x] Unvalidated ICP score
  - [x] Compensation as a single point of failure (manual, no automation)

  > **Approach shift:** tasks 08-10 were originally scoped as speculative modeling exercises using synthetic data calibrated to PostHog's public anchors. The approach changed: rather than simulate what the work would look like, the deliverables show real systems built and operated at Brasil Paralelo, mapped to the specific gaps PostHog is hiring to solve. The five challenges above are addressed directly in the deliverables.

- [x] 09 — Produce deliverables grounded in real operational experience
  - [x] Analytical framework per problem (documented in each deliverable HTML)
  - [x] Proposed solution with explicit premises
  - [x] Honest acknowledgment of what differs between the BP and PostHog contexts
  - [x] Open questions that require internal access to resolve

---

## Deliverables

> **Deliverable 01 — Monthly Growth Review** (`deliverables/01-monthly-growth-review/`)
> A sales performance monitoring system built and operated at Brasil Paralelo. Connects CRM, chat, transactions, and compensation into a BigQuery attribution model refreshed every 30 minutes in production. Covers the 14 metrics tracked weekly, the pipeline stage framework, the weekly decision cadence, and a direct mapping to the five JD problems PostHog is hiring to solve. Includes the production dbt SQL (`dtm_seller_conversion_rate.sql`).

> **Deliverable 02 — Compensation model** (`deliverables/02-compensation-model/`)
> The commission pipeline built and automated at Brasil Paralelo: staging tables for rep targets and tier thresholds, fact tables for monthly revenue by rep, and a transformation layer applying multiplier logic and outputting attainment and payout per rep. Includes the production dbt SQL (`compensation-pipeline.sql`) and a case-by-case comparison of what existed before, what was built, and what the PostHog equivalent looks like today.

> **Deliverable 03 — ICP score validation** (`deliverables/03-icp-validation/`)
> Propensity models built and validated against real revenue outcomes at Brasil Paralelo, mapped to PostHog's unvalidated ICP score problem. Includes the validation methodology SQL and an honest read on where the analogy holds and where it breaks.
