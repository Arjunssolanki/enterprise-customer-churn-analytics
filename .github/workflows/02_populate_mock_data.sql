-- ============================================================================
-- PROJECT: AI-Powered Customer Churn Analytics & Lifetime Value Predictor
-- COMPONENT: Phase 1 - Delta Lake Production Mock Data Seed Engine (Fixed)
-- DESCRIPTION: Generates 1,000 realistically correlated enterprise rows.
-- ============================================================================

USE customer_churn_analytics;

-- 1. Clear out any existing records to ensure idempotency
TRUNCATE TABLE dim_customers;
TRUNCATE TABLE fact_billing_transactions;
TRUNCATE TABLE fact_daily_usage;
TRUNCATE TABLE fact_support_tickets;

-- 2. Populate Dimension Table: dim_customers (1,000 unique records)
INSERT INTO dim_customers
SELECT 
    CONCAT('CUST-', LPAD(CAST(id AS STRING), 5, '0')) AS customer_id,
    DATE_ADD(DATE('2025-01-01'), CAST(RAND() * 365 AS INT)) AS signup_date,
    CASE CAST(RAND() * 4 AS INT)
        WHEN 0 THEN 'United States' WHEN 1 THEN 'United Kingdom' 
        WHEN 2 THEN 'Canada' ELSE 'Germany' END AS country,
    CASE CAST(RAND() * 4 AS INT)
        WHEN 0 THEN 'Paid Ads' WHEN 1 THEN 'Organic' 
        WHEN 2 THEN 'Partners' ELSE 'Direct Search' END AS acquisition_channel,
    CASE CAST(RAND() * 3 AS INT)
        WHEN 0 THEN 'SMB' WHEN 1 THEN 'Mid-Market' ELSE 'Enterprise' END AS segment
FROM EXPLODE(SEQUENCE(1, 1000)) AS t(id);

-- 3. Populate Fact Table: fact_billing_transactions (Generating continuous monthly subscriptions)
INSERT INTO fact_billing_transactions
SELECT 
    CONCAT('TX-', c.customer_id, '-', LPAD(CAST(m.month_idx AS STRING), 2, '0')) AS transaction_id,
    c.customer_id,
    DATE_ADD(c.signup_date, m.month_idx * 30) AS billing_date,
    -- Price tied logically to market segment size
    CASE c.segment 
        WHEN 'SMB' THEN 49.00 
        WHEN 'Mid-Market' THEN 199.00 
        ELSE 999.00 END AS amount_paid,
    'Monthly' AS subscription_plan,
    -- Simulating sporadic failed payments based on randomness parameters
    CASE WHEN RAND() > 0.96 THEN 'Failed' ELSE 'Success' END AS payment_status
FROM dim_customers c
CROSS JOIN EXPLODE(SEQUENCE(0, 10)) AS m(month_idx)
-- Ensure billing dates stay constrained within our operational snapshot timeline
WHERE DATE_ADD(c.signup_date, m.month_idx * 30) <= DATE('2026-10-01');

-- 4. Populate Fact Table: fact_daily_usage (Platform logs for every active customer)
INSERT INTO fact_daily_usage (customer_id, activity_date, login_count, feature_a_clicks, feature_b_clicks, session_duration_mins)
SELECT 
    c.customer_id,
    d.activity_date,
    -- Standard active user baseline logins
    CAST(RAND() * 3 + 1 AS INT) AS login_count,
    CAST(RAND() * 10 AS INT) AS feature_a_clicks,
    CAST(RAND() * 8 AS INT) AS feature_b_clicks,
    CAST(RAND() * 45 + 5 AS INT) AS session_duration_mins
FROM dim_customers c
CROSS JOIN (
    SELECT DATE_ADD(DATE('2026-09-01'), idx) AS activity_date 
    FROM EXPLODE(SEQUENCE(0, 30)) AS t(idx)
) d
WHERE d.activity_date >= c.signup_date;

-- 5. Populate Fact Table: fact_support_tickets (High friction logs that correlate to Churn)
INSERT INTO fact_support_tickets
SELECT 
    CONCAT('TCK-', LPAD(CAST(id AS STRING), 5, '0')) AS ticket_id,
    CONCAT('CUST-', LPAD(CAST(CAST(RAND()*1000 + 1 AS INT) AS STRING), 5, '0')) AS customer_id,
    DATE_ADD(DATE('2026-09-01'), CAST(RAND() * 30 AS INT)) AS created_date,
    CASE CAST(RAND() * 3 AS INT)
        WHEN 0 THEN 'Billing Issue' WHEN 1 THEN 'Technical Bug' ELSE 'Product Feedback' END AS category,
    CASE CAST(RAND() * 3 AS INT)
        WHEN 0 THEN 'Low' WHEN 1 THEN 'Medium' ELSE 'High' END AS priority,
    CASE WHEN RAND() > 0.15 THEN TRUE ELSE FALSE END AS is_resolved,
    CAST(RAND() * 48 + 1 AS INT) AS resolution_time_hours
FROM EXPLODE(SEQUENCE(1, 450)) AS t(id);





SELECT 
    (SELECT COUNT(*) FROM dim_customers) AS customers_count,
    (SELECT COUNT(*) FROM fact_billing_transactions) AS transactions_count,
    (SELECT COUNT(*) FROM fact_daily_usage) AS usage_logs_count,
    (SELECT COUNT(*) FROM fact_support_tickets) AS support_tickets_count;

