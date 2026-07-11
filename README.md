# PostHog RevOps Field Study

Built from public sources before applying to the [Revenue Operations Manager (sales focused)](https://posthog.com/careers/revenue-ops-manager-(sales-focused)) role.

**Start with the [Monthly Growth Review](deliverables/01-monthly-growth-review/).** It is the most complete picture of how I work.

## What this is

Rather than describing what I would do in this role, I am showing what I have already done in an analogous one.

The deliverables below are real systems I built and operated at Brasil Paralelo, a Brazilian media and subscription company. Each one is presented as a case: what the problem was, what I built to solve it, and how the operational thinking maps to the specific gaps PostHog is hiring to address. The mapping is grounded in the public handbook and job description, not speculation.

The `context/` folder holds the research behind the mapping: PostHog's product structure, acquisition funnel, sales motion, and compensation mechanics, all reconstructed from public sources.

## Deliverables

1. **[Monthly Growth Review](deliverables/01-monthly-growth-review/)**: a sales performance monitoring system I built and operated at Brasil Paralelo. Connects CRM, chat, transactions, and compensation into a single attribution model refreshed every 30 minutes. Includes the production dbt SQL and an interactive breakdown of the 14 metrics, pipeline stage framework, and weekly decision cadence.

2. **[Compensation model](deliverables/02-compensation-model/)**: the commission pipeline I built at Brasil Paralelo, from staging tables through multiplier logic to automated payout calculation. Includes the production SQL and a case-by-case comparison of what existed before, what I built, and what the PostHog equivalent looks like today.

3. **[ICP score validation](deliverables/03-icp-validation/)**: propensity models built and validated against real revenue outcomes at Brasil Paralelo, mapped to PostHog's unvalidated ICP score problem. Includes the validation methodology SQL and an honest read on where the analogy holds and where it breaks.

## How to navigate

Each deliverable has an interactive HTML version published at `dcherete.github.io/posthog-revops-case/`. Start there. The SQL files in each folder are the production code the case is built on. Go to `context/` when you want to see where a number or assumption came from.

## About me

I'm Davi, a Senior CRM Analyst with 4 years running CRM and revenue analytics at Brasil Paralelo, a Brazilian media and subscription company: a 6.2M-lead database, 800k active subscribers, 7 channels, R$64M in directly attributed CRM revenue, plus lead scoring models credited with another R$45.5M. Working stack: SQL, BigQuery, dbt, Python, Insider CDP. Statistics degree (UNESP).

I'm based in Brazil (GMT-3), which gives me full overlap with GMT-5 working hours. For GMT-8 it means a 1pm to 9pm local schedule, and I'm glad to hold it.

[Resume →](resume.html)

## A note on location

The role is listed for GMT-5. I am in Brazil (GMT-3), two hours ahead. The working overlap is full and I already keep the schedule.

I am not going to argue around the timezone constraint. What I can say is that PostHog is the only company I applied to this cycle, and this repository is the reason why. [The full context is here.](link)

## Status

Work in progress, deliberately public. Each deliverable ends with the open questions that would require internal data to resolve. Knowing what I can't know from the outside is part of the job.