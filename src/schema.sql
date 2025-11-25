CREATE TABLE fact_daily_company_activity (
    activity_date DATE NOT NULL,
    company_id VARCHAR(50) NOT NULL,
    company_name VARCHAR(255),
    industry_tag VARCHAR(100),
    country VARCHAR(100),
    daily_active_users INT DEFAULT 0,
    daily_events_count INT DEFAULT 0,
    rolling_7d_active_users FLOAT,
    days_since_last_contact INT,
    is_churn_risk BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (company_id, activity_date)
);