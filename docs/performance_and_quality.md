# Performance, Data Quality & Communication Strategy

## 1. Optimization Plan (The "30-Minute" Fix)

**Context:** The pipeline takes 3+ hours because it likely rescans the entire historical dataset every day. We are restricted to touching **one file** (the SQL transformation).

| Rank | Change | Why this order? |
| :--- | :--- | :--- |
| **1** | **Add Incremental Filtering**<br>`WHERE date = '{{ target_date }}'` | **Highest Impact.** Currently, the query performs a full table scan ($O(N)$). Filtering to a single day reduces the data volume to $O(1)$, instantly dropping runtime from hours to minutes. This is the only way to solve the "3+ hour" issue immediately within the constraints. |
| **2** | **Fix Idempotency logic**<br>`DELETE` target partition before `INSERT` | **Data Quality.** Once we make the load incremental (Step 1), we risk duplicating data if the job re-runs. We must ensure that running the SQL for a specific date safely overwrites existing data rather than appending to it. |
| **3** | **Timezone Standardization**<br>Explicit `CONVERT_TIMEZONE('UTC', ...)` | **Accuracy.** Mismatches often occur because the API provides UTC data, but the SQL casts to `DATE` (truncating time) without handling offsets, causing events near midnight to fall into the wrong day. |

---

## 2. Code Review: Risks & Flaws

**SQL Snippet:**
```sql
SELECT company_id, date, SUM(events) AS events
FROM fact_events
GROUP BY company_id, date;
```

### Risk A: Full Table Scan (Performance Limit)
* **The Flaw:** The query lacks a `WHERE` clause. As `fact_events` grows, the database must read every row from the beginning of time to calculate the `GROUP BY`, causing the 3+ hour runtime.
* **The Fix:** Switch to an **Incremental Pattern**. Pass a parameter (e.g., via Airflow/ADF) to process only the relevant date:
    ```sql
    WHERE date >= '{{ start_date }}' AND date < '{{ end_date }}'
    ```

### Risk B: Timezone Mismatches (Data Integrity)
* **The Flaw:** Casting a timestamp directly to a `date` implies the server's local time. If the API returns UTC and the dashboard expects EST, events happening at 11 PM UTC will appear on "Day X" in the raw data but "Day X+1" (or X-1) in the dashboard, causing the reported mismatches.
* **The Fix:** Explicitly cast timestamps to the reporting timezone before grouping.
    ```sql
    -- Example for Snowflake/Postgres
    GROUP BY DATE(CONVERT_TIMEZONE('UTC', 'America/New_York', event_timestamp))
    ```

### Risk C: Aggregation Ambiguity
* **The Flaw:** `SUM(events)` implies that `events` is a pre-aggregated counter column. However, usually "fact" tables contain raw granular events (1 row = 1 event). If `events` is actually an ID column or a constant `1`, `SUM` might return nonsense or huge numbers.
* **The Fix:** Verify schema. If counting raw occurrences, use `COUNT(event_id)` or `COUNT(*)` instead of `SUM`.

---

## 3. Investigating Pipeline Performance

**Real-World Scenario:**
I once encountered a pipeline ("Daily User Sessions") that suddenly degraded from 30 minutes to 4 hours.

**Investigation Steps (The Debugging Loop):**

1.  **Check the "Explain Plan":**
    * *Action:* Run `EXPLAIN SELECT ...` on the slow query.
    * *What I looked for:* Was it doing a **Full Table Scan** instead of a **Partition Scan**?
    * *Result:* The query was filtering on `created_at` (timestamp) but the table was partitioned by `date_key` (int). The database couldn't prune partitions, so it read everything.

2.  **Check for Data Skew:**
    * *Action:* Run a profile query: `SELECT company_id, COUNT(*) FROM source GROUP BY 1 ORDER BY 2 DESC LIMIT 10`.
    * *Theory:* If one company accidentally sent 100M events (bot attack or bug), the "Reducer" or "Group By" step for that specific key would hang, stalling the whole job.

3.  **Check Resource Contention (Locks/Queues):**
    * *Action:* Check the Data Warehouse active queries list (e.g., `sys.dm_exec_requests` in SQL Server or Query History in Snowflake).
    * *Theory:* Was my job "Running" or "Queued/Blocked"? Sometimes the issue isn't the code, but a higher-priority job hogging all cluster slots.

---

## 4. Slack Update to Analytics Team

**Channel:** `#data-analytics-alerts`
**Topic:** Pipeline Performance Fix

> **Update: Company Activity Pipeline Latency**
>
> Hi team, I'm deploying a fix for the `fact_daily_company_activity` pipeline which has been running long (3h+) and causing delays.
>
> * **What I'm Changing:** Switching the pipeline from a "full historical reload" to an **incremental daily load**. It will now only process yesterday's data instead of re-calculating history every morning.
> * **Impact:** Run times should drop to <15 minutes. Data for "yesterday" will land much earlier (by ~01:15 AM).
> * **Caveat:** Historical data updates won't happen automatically anymore. If we need to restate history (e.g., for a bug fix), I will trigger a manual backfill.
> * **Please Watch:** Verify that the numbers for yesterday match your expectations in the dashboard this morning.
>
> Let me know if you see any anomalies!