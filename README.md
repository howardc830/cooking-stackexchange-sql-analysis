# Why Do Some Cooking Questions Go Unanswered?
 
A SQL analysis of the Cooking Stack Exchange community, exploring what separates questions that get fast, high-quality answers from ones that sit unanswered — and who the top contributors driving the site are.
 
**Tools Used:** SQL Server (via the [Stack Exchange Data Explorer](https://data.stackexchange.com/cooking/query/new))
**Dataset:** [cooking.stackexchange.com](https://cooking.stackexchange.com) — live, queryable via the Data Explorer
 
---
 
## Business Question
 
What separates a question that gets a fast, accepted answer from one that sits unanswered — and who are the users driving the most value on this site?
 
---
 
## Key Findings
 
- **Answer rates have declined over time.** Early questions (2010) were answered roughly 80-84% of the time. By 2011, that had dropped into the 63-76% range, and the decline continues as the community has grown — a common pattern as question volume outpaces the number of active answerers.
- **"Breakfast" is the hardest tag to get help with.** Only 26% of breakfast-tagged questions get an accepted answer — the lowest rate of any tag with meaningful volume — despite averaging over 13,000 views each. High interest, low answer rate is a real gap. Catering (27%), mustard (29%), and chips (30%) round out the list.
- **A small group of power users drives a large share of answer value**, and their activity patterns differ — some (like the top contributor identified in this analysis) start strong immediately and taper over time, rather than building up gradually.
---
 
## Queries
 
All queries are in [`analysis.sql`](./analysis.sql). Results are saved as CSVs in [`/data`](./data).
 
| # | File | What it does |
|---|------|---------------|
| 1 | `01_questions_accepted_answers.csv` | Joins every question to its accepted answer (if one exists) and calculates time-to-acceptance. Base view for the rest of the analysis. |
| 2 | `02_monthly_answer_rate.csv` | CTE aggregating question volume and answer rate by month, to track trends over time. |
| 3 | `03_top_contributors_by_month.csv` | Window function (`RANK() OVER PARTITION BY month`) ranking top-scoring answerers each month. |
| 4 | `04_power_user_running_totals.csv` | Window function (running `SUM() OVER`) tracking cumulative score growth for the top 5 all-time answerers. |
| 5 | `05_hardest_tags_by_answer_rate.csv` | `CROSS APPLY` + `STRING_SPLIT` to break out tags, then segments answer rate and view count by tag to find the hardest topics to get help with. |
 
---
 
## Notes
 
- Recent months (last 1-2 months of data) show artificially low answer rates simply due to time lag — new questions haven't had a chance to be answered yet. Excluded from trend commentary above.
- Tags with fewer than 30 questions were excluded from the tag-level analysis to avoid noisy percentages from small sample sizes.
