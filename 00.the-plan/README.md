# Study Plan

This document tracks the logical sequence of the field study. Each item builds on the previous one. All information is drawn from PostHog's public sources — handbook, pricing pages, product documentation, and exec responsibilities.

Commits tell the real story of progress. Check the git history.

---

- [ ] 01 — Understand all PostHog products and how each one is sold
  - [ ] What each product does
  - [ ] Pricing model per product (usage-based, flat, freemium)
  - [ ] Which products are self-serve only vs sales-assisted
  - [ ] Upsell and cross-sell logic between products

- [ ] 02 — Understand how marketing generates demand
  - [ ] Intentional channels: SEO, technical content, YouTube, developer community
  - [ ] Role of Charles Cook and the Demand Gen team
  - [ ] How marketing amplifies word-of-mouth without being the origin of it

- [ ] 03 — Understand how demand splits between self-serve and sales-led
  - [ ] What triggers a self-serve conversion
  - [ ] What triggers routing to a rep
  - [ ] The blurred middle — accounts that pay self-serve but qualify for sales attention
  - [ ] The organic PLG loop and its attribution implications

- [ ] 04 — Understand the sales funnel end to end
  - [ ] Lead origins per channel
  - [ ] Qualification criteria (BANT, ICP score thresholds)
  - [ ] Routing logic between TAE, TAM, and CSM
  - [ ] Handoff points and ownership transitions

> **Output 1 — `acquisition-and-upsell-funnel.md`**
> How PostHog generates demand, how it splits between self-serve and sales-led, how each product fits the conversion and expansion funnel, and where the attribution problem between product and rep first appears.

---

- [ ] 05 — Understand sales structure — TAE, TAM, CSM, BDR
  - [ ] Role definitions and lead sources per role
  - [ ] Book of business logic per role
  - [ ] Performance floors and ramp periods

- [ ] 06 — Understand ICP scoring model
  - [ ] How the 70-point model is constructed in Salesforce
  - [ ] What variables compose the score and their implied weights
  - [ ] Whether the score has been validated against actual revenue outcomes

- [ ] 07 — Understand compensation structure
  - [ ] OTE structure per role
  - [ ] Quota setting logic
  - [ ] Commission sliding scale and accelerators
  - [ ] What counts and what doesn't toward quota

> **Output 2 — `sales-structure-and-compensation.md`**
> Org chart with role definitions, lead sources, and performance mechanics. Full compensation model per role. ICP score reconstruction from public sources with a proposed validation experiment design.

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

> **Output 3 — `revenue-and-compensation-model.md`**
> Three-layer projection model: (1) cost per rep as a function of attainment; (2) total team revenue and compensation cost given rep count and attainment mix; (3) maturity curve showing OTE cost evolution over time. Critical analysis of whether the current incentive structure is aligned with PLG revenue goals. Five analytical frameworks with proposed solutions and honest open questions for each challenge.