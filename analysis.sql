/*
========================================================================
  Why Do Some Cooking Questions Go Unanswered?
  SQL analysis of the Cooking Stack Exchange community
  Run against: cooking.stackexchange.com via Stack Exchange Data Explorer
  https://data.stackexchange.com/cooking/query/new
========================================================================
*/


/* ------------------------------------------------------------------
   STEP 1: Base view — join questions to their accepted answers
   Calculates how long each question took to get an accepted answer.
   Uses a LEFT JOIN (not INNER) so unanswered questions are kept too.
------------------------------------------------------------------ */

SELECT 
    q.Id AS QuestionId,
    q.CreationDate AS QuestionDate,
    q.Score AS QuestionScore,
    q.ViewCount,
    q.OwnerUserId AS AskerId,
    q.AcceptedAnswerId,
    a.Id AS AnswerId,
    a.CreationDate AS AnswerDate,
    a.Score AS AnswerScore,
    a.OwnerUserId AS AnswererId,
    DATEDIFF(MINUTE, q.CreationDate, a.CreationDate) AS MinutesToAccepted
FROM Posts q
LEFT JOIN Posts a 
    ON q.AcceptedAnswerId = a.Id
WHERE q.PostTypeId = 1
ORDER BY q.CreationDate DESC;


/* ------------------------------------------------------------------
   STEP 2: Monthly trend — question volume vs. answer rate over time
   CTE flags whether each question has an accepted answer, then
   aggregates by month to track how the answer rate has changed
   as the community has grown.
------------------------------------------------------------------ */

WITH QuestionStats AS (
    SELECT
        q.Id AS QuestionId,
        q.CreationDate,
        q.AcceptedAnswerId,
        CASE WHEN q.AcceptedAnswerId IS NOT NULL THEN 1 ELSE 0 END AS HasAcceptedAnswer
    FROM Posts q
    WHERE q.PostTypeId = 1
)
SELECT
    FORMAT(CreationDate, 'yyyy-MM') AS Month,
    COUNT(*) AS TotalQuestions,
    SUM(HasAcceptedAnswer) AS QuestionsAnswered,
    CAST(SUM(HasAcceptedAnswer) AS FLOAT) / COUNT(*) * 100 AS PctAnswered
FROM QuestionStats
GROUP BY FORMAT(CreationDate, 'yyyy-MM')
ORDER BY Month;


/* ------------------------------------------------------------------
   STEP 3: Top contributors by month (window function — RANK)
   For each month, ranks users by total answer score. RANK() resets
   fresh at the start of every month via PARTITION BY.
   Filtered to 2024+ to keep the result set manageable; remove the
   WHERE clause for full history.
------------------------------------------------------------------ */

WITH MonthlyAnswers AS (
    SELECT
        a.OwnerUserId AS AnswererId,
        FORMAT(a.CreationDate, 'yyyy-MM') AS Month,
        SUM(a.Score) AS TotalScore,
        COUNT(*) AS AnswerCount
    FROM Posts a
    WHERE a.PostTypeId = 2
      AND a.OwnerUserId IS NOT NULL
    GROUP BY a.OwnerUserId, FORMAT(a.CreationDate, 'yyyy-MM')
)
SELECT
    Month,
    AnswererId,
    TotalScore,
    AnswerCount,
    RANK() OVER (PARTITION BY Month ORDER BY TotalScore DESC) AS MonthlyRank
FROM MonthlyAnswers
WHERE Month >= '2024-01'
ORDER BY Month DESC, MonthlyRank ASC;


/* ------------------------------------------------------------------
   STEP 4: Power-user trajectories (window function — running total)
   Tracks cumulative answer score month-over-month for the top 5
   all-time answerers, to see how their contribution builds over
   their history on the site.
------------------------------------------------------------------ */

WITH UserMonthlyActivity AS (
    SELECT
        a.OwnerUserId AS AnswererId,
        FORMAT(a.CreationDate, 'yyyy-MM') AS Month,
        SUM(a.Score) AS MonthlyScore,
        COUNT(*) AS MonthlyAnswerCount
    FROM Posts a
    WHERE a.PostTypeId = 2
      AND a.OwnerUserId IS NOT NULL
    GROUP BY a.OwnerUserId, FORMAT(a.CreationDate, 'yyyy-MM')
)
SELECT
    AnswererId,
    Month,
    MonthlyScore,
    MonthlyAnswerCount,
    SUM(MonthlyScore) OVER (
        PARTITION BY AnswererId 
        ORDER BY Month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotalScore
FROM UserMonthlyActivity
WHERE AnswererId IN (
    SELECT TOP 5 OwnerUserId
    FROM Posts
    WHERE PostTypeId = 2 AND OwnerUserId IS NOT NULL
    GROUP BY OwnerUserId
    ORDER BY SUM(Score) DESC
)
ORDER BY AnswererId, Month;


/* ------------------------------------------------------------------
   STEP 5: Hardest tags to get answered (CROSS APPLY + segmentation)
   The Tags column stores multiple tags in one string, e.g.
   "<baking><eggs><substitutions>". CROSS APPLY + STRING_SPLIT
   unpivots this into one row per tag, so answer rate and view
   count can be compared by topic.
   Tags with fewer than 30 questions are excluded to avoid noisy,
   small-sample percentages.
------------------------------------------------------------------ */

SELECT
    TRIM(value) AS Tag,
    COUNT(*) AS TotalQuestions,
    SUM(CASE WHEN q.AcceptedAnswerId IS NOT NULL THEN 1 ELSE 0 END) AS AnsweredQuestions,
    CAST(SUM(CASE WHEN q.AcceptedAnswerId IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) 
        / COUNT(*) * 100 AS PctAnswered,
    AVG(CAST(q.ViewCount AS FLOAT)) AS AvgViews
FROM Posts q
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(q.Tags, '<', ''), '>', ','), ',')
WHERE q.PostTypeId = 1
  AND value <> ''
GROUP BY TRIM(value)
HAVING COUNT(*) >= 30
ORDER BY PctAnswered ASC;
