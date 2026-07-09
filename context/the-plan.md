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
  - [ ] Whether the score has been validated against actual revenue outcomes

- [x] 07 — Understand compensation structure
  - [x] OTE structure per role
  - [x] Quota setting logic
  - [x] Commission sliding scale and accelerators
  - [x] What counts and what doesn't toward quota

> **Context doc 3 — `sales-structure-and-compensation.md`**
> Account lifecycle and role definitions. Lead sources and book of business per role. Full compensation mechanics for TAE, TAM, BDR, and Team Lead. Cross-sell multiplier table. Five structural gaps in the current model mapped to RevOps deliverables.

---

- [ ] 08 — Model revenue and commission projections
  - [ ] Estimate TAE and TAM quota ranges from public data and market benchmarks
  - [ ] Build commission scenarios at 80%, 100%, 120%, 150% attainment
  - [ ] Sensitivity analysis: what happens if deal size drops 30%, ramp extends, clawback rate rises
  - [ ] Maturity curve: how OTE cost evolves quarter over quarter as reps move through ramp, stabilize, or are replaced — and whether the model reaches sustainable equilibrium or keeps escalating
  - [ ] Does the current model incentivize the right behavior in a PLG context?

- [ ] 09 — Map the five core challenges
  - [ ] Incentive misalignment in PLG attribution
  - [ ] Absence of real-time revenue visibility
  - [ ] Unvalidated assumptions about what drives revenue
  - [ ] Attribution problem between product and rep
  - [ ] Compensation as a single point of failure

- [ ] 10 — Produce analysis and proposed solution for each challenge
  - [ ] Analytical framework per problem
  - [ ] Proposed solution with explicit premises
  - [ ] What data I would need internally to calibrate each solution
  - [ ] Open questions that require internal access to resolve

> **Context doc 4 — `revenue-and-compensation-model.md`**
> Three-layer projection model: (1) cost per rep as a function of attainment; (2) total team revenue and compensation cost given rep count and attainment mix; (3) maturity curve showing OTE cost evolution over time. Critical analysis of whether the current incentive structure is aligned with PLG revenue goals. Five analytical frameworks with proposed solutions and honest open questions for each challenge.

---

## Deliverables

The five deliverables are the public-facing work product of this study. Each one is built on top of the context docs above.

> **Deliverable 01 — Monthly Growth Review mock** (`deliverables/01-monthly-growth-review/`)
> The memo I would ship in month one. Gainers and losers, new vs. expansion revenue, leading indicators, and one decision recommendation. Includes the SQL that generates it. Built on the acquisition funnel and sales structure context docs.

> **Deliverable 02 — Alerting spec** (`deliverables/02-alerting-spec/`)
> A trigger catalog for proactive revenue monitoring. Each trigger defines signal, threshold, owner, recommended action, delivery channel, and false-positive control. With executable detection queries. Directly addresses the pipeline leakage and underperformance detection gaps identified in the sales structure doc.

> **Deliverable 03 — Compensation model** (`deliverables/03-compensation-model/`)
> Rep-level cost as a function of attainment, team-level scenarios at 80/100/120/150% attainment, sensitivity analysis, and a maturity curve of OTE cost over time. Built on top of context doc 3 and context doc 4.

> **Deliverable 04 — ICP score validation** (`deliverables/04-icp-validation/`)
> An experiment design to test whether the ICP score actually tracks revenue outcomes, and what to change if it doesn't. Addresses the open question from task 06.

> **Deliverable 05 — Attribution and NRR** (`deliverables/05-attribution-and-nrr/`)
> How demand splits between self-serve and sales-led, where attribution between product and rep breaks down, and a methodology for decomposing the deltas in NRR.
