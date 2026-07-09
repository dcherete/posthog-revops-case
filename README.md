# PostHog RevOps Field Study

This is an analysis of PostHog's sales-led revenue engine, built from public sources before applying to the [Revenue Ops Manager (sales focused)](https://posthog.com/careers/revenue-ops-manager-(sales-focused)) role.

**If you only read one thing, read the [Monthly Growth Review mock](deliverables/01-monthly-growth-review/).** It's the closest thing to the actual work product this role ships every month.

## Why this exists

I want this role. Rather than telling you I can do the job, I decided to do a version of it in public: reconstruct how PostHog generates and expands revenue, model the compensation machine, and design the monitoring layer. All of it using only the handbook, pricing pages, public team data, and disclosed financials.

Everything here runs on synthetic data calibrated to PostHog's public anchors. Any number that isn't publicly sourced is declared inline, with the reasoning behind the estimate and a note on how much the conclusions depend on it.

## Deliverables

1. **[Monthly Growth Review mock](deliverables/01-monthly-growth-review/)**: the memo I would ship in month one. Gainers and losers, new vs. expansion revenue, leading indicators, and one decision recommendation. Includes the SQL that generates it.
2. **[Alerting spec](deliverables/02-alerting-spec/)**: a trigger catalog for proactive revenue monitoring. Each trigger defines signal, threshold, owner, recommended action, delivery channel, and false-positive control. With executable detection queries.
3. **[Compensation model](deliverables/03-compensation-model/)**: rep-level cost as a function of attainment, team-level scenarios at 80/100/120/150% attainment, sensitivity analysis, and a maturity curve of OTE cost over time.
4. **[ICP score validation](deliverables/04-icp-validation/)**: an experiment design to test whether the ICP score actually tracks revenue outcomes, and what to change if it doesn't.
5. **[Attribution & NRR](deliverables/05-attribution-and-nrr/)**: how demand splits between self-serve and sales-led, where attribution between product and rep breaks down, and a methodology for decomposing the deltas in NRR.

## How to navigate

Each deliverable in `deliverables/` stands alone. The `context/` folder holds the research that feeds them: product structure, acquisition funnel, sales structure and compensation mechanics, and the study plan. Start with a deliverable, go to `context/` when you want to see where a number came from.

The commit history is the methodology. Each commit reflects a real study session.

## About me

I'm Davi, a Senior CRM Analyst with 4 years running CRM and revenue analytics at Brasil Paralelo, a Brazilian media and subscription company: a 6.2M-lead database, 800k active subscribers, 7 channels, R$64M in directly attributed CRM revenue, plus lead scoring models credited with another R$45.5M. Working stack: SQL, BigQuery, dbt, Python, Insider CDP. Statistics degree (UNESP).

I'm based in Brazil (GMT-3), which gives me full overlap with GMT-5 working hours. For GMT-8 it means a 1pm to 9pm local schedule, and I'm glad to hold it.

## Status

Work in progress, deliberately public. Each deliverable ends with the open questions that would require internal data to resolve. Knowing what I can't know from the outside is part of the job.