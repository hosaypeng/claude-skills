---
name: finance-analysis
description: "Comprehensive financial and psychological analysis of personal finance data. Use when user says '/finance-analysis'."
user-invocable: true
---

# Personal Finance Analysis

Run a deep financial and behavioral analysis using the latest master CSV data and Obsidian note.

---

## Phase 1: Ensure Data is Current

1. Run `/personal-finance-update` first to sync all tables.
2. Read the Obsidian note at:
   ```
   /Users/hsp/Library/Mobile Documents/iCloud~md~obsidian/Documents/20_areas/personal/personal_finance.md
   ```
3. Read the memory file at:
   ```
   ~/.claude/projects/-Users-hsp-Sync-personal-finance-master/memory/MEMORY.md
   ```

---

## Phase 2: Load Raw Data

1. Read all master CSVs from `/Users/hsp/Sync/personal_finance/master/` for years 2020 onward (the reliable range).
2. Compute any metrics not already in the Obsidian tables — monthly breakdowns, per-category trends, income source timelines, cash flow by month.

---

## Phase 3: Financial Analysis

Present the following, using actual numbers from the data:

1. **Net worth trajectory & cash flow** — yearly and monthly trends (2020–present). Income vs outflow. Is the user saving, breaking even, or bleeding?
2. **Spending efficiency** — which categories deliver ROI (education, health, business investments) vs pure consumption? Quantify the split.
3. **Burn rate** — true monthly cost of living including cash withdrawals and transfers. Compare employed months vs unemployed months.
4. **Risk exposure** — income concentration (single source?), liquidity gaps, untracked blind spots (UOB joint account, cash spending, StanChart).
5. **Runway projection** — at current burn rate with no income change, how many months of runway remain? What if luxuries are cut to zero?
6. **Category deep-dives** — flag any category with unusual patterns, sudden changes, or outsized impact on the overall picture.

---

## Phase 4: Psychological & Behavioral Analysis

Analyze the spending data as a behavioral signal:

1. **Values revealed by spending** — what do the numbers say about priorities and identity, beyond stated beliefs?
2. **Stated vs actual** — where do stated beliefs (minimalism, antifragility, wealth-first) conflict with actual spending behavior?
3. **Emotional triggers** — correlate spending spikes with life events (layoff, travel, seasons, wife-related). Are there patterns?
4. **Impulse vs deliberate** — what fraction of spending looks planned vs reactive? Use transaction frequency, amounts, and timing.
5. **Relationship with money** — fearful, strategic, impulsive, or evolving? How has the pattern shifted from 2020 to now?
6. **Self-deception audit** — where is spending rationalized as "investment" or "necessity" when data suggests comfort or status?
7. **Highest-impact behavioral change** — one concrete change that the data shows would have the biggest financial effect.

---

## Phase 5: Report

Structure the output as:

1. **Executive Summary** — 3-5 bullet points, the most important findings.
2. **Financial Analysis** — numbered sections from Phase 3, with tables and numbers.
3. **Behavioral Analysis** — numbered sections from Phase 4, referencing specific transactions and patterns.
4. **Recommendations** — 3 actionable items ranked by financial impact.

Be brutally honest. Use actual numbers. Challenge the user's self-narrative where data contradicts it. No flattery, no hedging.
