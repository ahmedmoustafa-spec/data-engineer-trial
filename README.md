# Data Engineer Trial Task - Company Activity Pipeline

## Overview
This repository contains the proposed solution for the Company Activity Dashboard pipeline. It details the data modeling, pipeline architecture, and ingestion logic required to combine CRM data (Azure Blob) with Product Usage data (API).

---

## 1. Target Analytics Table (Question 1)

**Table Name:** `fact_daily_company_activity`  
**Grain:** One row per **Company** per **Date**.

### Schema Definition
Below is the proposed schema for the analytics-ready table:

| Column Name | Data Type | Source | Description |
| :--- | :--- | :--- | :--- |
| `activity_date` | DATE | API | The date of the activity (Part of Composite PK) |
| `company_id` | VARCHAR | Shared | Unique Company Identifier (Part of Composite PK) |
| `company_name` | VARCHAR | CRM | Current name of the company |
| `industry_tag` | VARCHAR | CRM | Industry segment |
| `country` | VARCHAR | CRM | Region/Country |
| `daily_active_users` | INT | API | Count of active users for that day |
| `daily_events_count` | INT | API | Count of system events for that day |
| `7d_rolling_active_users` | FLOAT | **Derived** | 7-day moving average of active users |
| `days_since_last_contact` | INT | **Derived** | Days elapsed between activity date and last CRM contact |
| `is_churn_risk` | BOOLEAN | **Derived** | Flag: `1` if activity is low or contact is old, else `0` |

---

## 2. SQL Transformation (Question 2)
The SQL logic merges the incremental usage data with the CRM snapshot to calculate the derived metrics defined above.

* **File:** [`src/transformation.sql`](./src/transformation.sql)
* **Key Logic:** Uses Window Functions for the 7-day rolling average and `CASE` statements for the Churn Risk flag.

---

## 3. Architecture & ADF Flow (Question 3)
The pipeline is designed using Azure Data Factory (ADF) with an Azure Function for API interaction.

* **File:** [`docs/adf_pipeline_design.md`](./docs/adf_pipeline_design.md)

**Simplified Flow:**
```text
[Trigger: Daily @ 1 AM]
      |
      v
[Azure Function: API Ingestion] --> (Lands JSON in Blob Storage)
      |
      v
[Validation Activity] --> (Checks File Existence)
      |
      v
[Copy Activity] --> (Blob JSON -> SQL Staging Tables)
      |
      v
[Stored Procedure] --> (Merges Staging -> Target Table)
      |
      +--> [On Failure: Web Activity (Slack Alert)]

## 4. API Ingestion Strategy (Question 4)
A Python function designed to run in an Azure Function App or Databricks. It handles date logic and lands raw data into the Bronze layer (Blob Storage).

* **File:** [`src/ingestion.py`](./src/ingestion.py)

---

## 5. Prioritization Scenario (Question 5)

**Scenario:** Only 30 minutes remain before the scheduled run.

**Decision:**
I would implement the **API Ingestion Script (Part 4)** first.

**Reasoning:**
* **Data Volatility:** API data is often ephemeral. If we miss the ingestion window, that historical usage data may be lost forever.
* **Dependency Chain:** The database transformation and the dashboard visualization cannot exist without the raw data. Ingestion is the root dependency.
* **Recovery:** If the SQL logic is incomplete or the pipeline fails, we can backfill the transformation later as long as the raw JSON files are safely stored in the Blob (Bronze layer).

**Explicitly Postponed:**
* **Automated Alerting:** I would manually monitor the first run. Setting up Slack webhooks is a "Day 2" optimization.
* **Complex Churn Logic:** I would implement a placeholder logic for churn risk and refine the complex business rule after the data is successfully flowing.