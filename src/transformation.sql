/*
  Question 2: SQL Transformation
  Description: Merges Usage Staging (Incremental) with CRM Staging (Snapshot).
  Target Table: fact_daily_company_activity
*/

WITH usage_metrics AS (
    SELECT 
        u.company_id,
        u.date AS activity_date,
        u.active_users,
        u.events,
        -- Calculate 7-Day Rolling Average of Active Users
        AVG(u.active_users) OVER (
            PARTITION BY u.company_id 
            ORDER BY u.date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7d_active_users
    FROM stg_api_usage u
)

SELECT
    m.activity_date,
    m.company_id,
    -- CRM Attributes
    c.name AS company_name,
    c.country,
    c.industry_tag,
    -- Activity Metrics
    m.active_users AS daily_active_users,
    m.events AS daily_events_count,
    ROUND(m.rolling_7d_active_users, 2) AS 7d_rolling_active_users,
    
    -- Derived Metric: Days since last contact
    DATEDIFF(day, c.last_contact_at, m.activity_date) AS days_since_last_contact,

    -- Derived Metric: Churn Risk
    -- Logic: Risk if 0 active users today AND (very low events OR no contact in > 90 days)
    CASE 
        WHEN m.active_users = 0 AND (m.events < 5 OR DATEDIFF(day, c.last_contact_at, m.activity_date) > 90) 
        THEN 1 
        ELSE 0 
    END AS is_churn_risk

FROM usage_metrics m
LEFT JOIN stg_crm_companies c 
    ON m.company_id = c.company_id;