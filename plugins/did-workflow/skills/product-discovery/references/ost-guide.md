# Opportunity Solution Tree — Quick Reference

The Opportunity Solution Tree (OST) is a visual framework created by Teresa
Torres for structuring product discovery. It ensures that what you build is
connected to a real user need and a meaningful business outcome.

## The Four Layers

```
Outcome (the business metric you want to move)
  └── Opportunities (unmet user needs that affect the outcome)
        └── Solutions (ideas that address an opportunity)
              └── Experiments (tests that validate the riskiest assumption)
```

Each layer answers a different question:

1. **Outcome** — What result are we trying to achieve?
2. **Opportunities** — What user needs, if addressed, would drive that result?
3. **Solutions** — What could we build to address a specific opportunity?
4. **Experiments** — How do we test whether a solution will actually work?

## Good vs. Bad Outcomes

A good outcome is measurable, time-bound, within the team's influence, and
tied to business value.

| Good outcome                                                          | Why it works                                         |
| --------------------------------------------------------------------- | ---------------------------------------------------- |
| "Reduce support tickets about billing from 120/week to 30/week by Q3" | Specific metric, clear target, team can influence it |
| "Increase trial-to-paid conversion from 12% to 20% in 90 days"        | Measurable, time-bound, directly tied to revenue     |
| "Reduce time-to-first-value from 14 days to 3 days"                   | User-centric metric, team can affect onboarding      |

| Bad outcome                   | Why it fails                                                |
| ----------------------------- | ----------------------------------------------------------- |
| "Improve the product"         | Not measurable — how would you know?                        |
| "Build a notification system" | That's a solution, not an outcome                           |
| "Increase revenue"            | Too broad — the team can't directly influence total revenue |
| "Make users happier"          | Not measurable without defining what "happier" means        |

## Opportunities vs. Solutions

This is the most common mistake in product thinking. Opportunities describe
user needs. Solutions describe what you'll build. Mixing them up leads to
building things nobody asked for.

| Opportunity (user need)                                      | Solution (what to build)                 |
| ------------------------------------------------------------ | ---------------------------------------- |
| "Users can't find the data they need to make decisions"      | "Build a dashboard"                      |
| "New users don't understand what the product does"           | "Create an onboarding tour"              |
| "Customers waste 2 hours/month requesting invoices manually" | "Add self-serve invoice export"          |
| "Team leads don't know which tasks are blocked"              | "Add a blocked-tasks Slack notification" |

**Test:** If you can build it, it's a solution. If users feel it, it's an
opportunity. "Needs a better dashboard" sounds like a need but it's actually
a solution wearing a mask. The real opportunity might be "can't find the data
they need" — and there might be better solutions than a dashboard.

## Evidence Strength

When evaluating opportunities, rate evidence strength honestly:

**Strong evidence:**

- Direct user quotes from interviews or support tickets
- Behavioral data (analytics showing where users struggle or drop off)
- Quantitative research (surveys with significant sample sizes)

**Moderate evidence:**

- Indirect signals (feature requests that imply an underlying need)
- Small sample observations (2–3 user interviews)
- Team observations from customer-facing roles (support, sales)

**Weak evidence:**

- Gut feeling or intuition
- Analogies from other products ("Competitor X does this")
- Assumptions without direct data

Weak evidence is not disqualifying — it means the opportunity needs validation
before you invest heavily. That's what experiments are for.

## Lightweight Experiment Types

The goal of an experiment is to test the riskiest assumption as cheaply as
possible. Don't build the full solution to find out if users want it.

| Experiment type                  | What it tests                                                   | Effort     |
| -------------------------------- | --------------------------------------------------------------- | ---------- |
| **User interviews** (5–8 people) | Whether the opportunity is real and painful                     | Days       |
| **Data analysis**                | Whether existing data already answers the question              | Hours–days |
| **Concierge test**               | Whether the solution concept works, delivered manually          | Days       |
| **Wizard of Oz**                 | Whether users engage with the solution, faked behind the scenes | Days–week  |
| **Prototype test** (10–20 users) | Whether the specific UX/flow works                              | 1–2 weeks  |
| **A/B test** (requires traffic)  | Whether the solution moves the metric                           | 2–4 weeks  |

Start with the cheapest experiment that gives you useful signal. You can always
run a more rigorous test later.

## Common Anti-Patterns

**Jumping to solutions.** Someone says "we should build X" and the team starts
building without asking what outcome X is supposed to drive or what user need
it addresses. The OST forces you to trace the path from outcome to solution.

**Single-solution fixation.** The team converges on the first idea without
exploring alternatives. Always generate at least 2–3 solution candidates
before choosing.

**Outcome-free building.** Features get built because "it seems like a good
idea" or "a customer asked for it" without connecting to a measurable outcome.
If you can't name the metric, you can't measure success.

**Solution masquerading as opportunity.** "We need a mobile app" is not an
opportunity — it's a solution. The opportunity might be "field workers can't
access the system when away from their desk." The mobile app is one possible
solution; a lightweight SMS interface might be another.

**Skipping experiments.** The team is so confident in the solution that they
skip validation and build the full thing. Then they discover the assumption
was wrong after investing weeks or months. The cost of a 3-day experiment is
always lower than the cost of building the wrong thing.
