-- ============================================================================
-- PROJECT: AI-Powered Customer Churn Analytics & Lifetime Value Predictor
-- COMPONENT: Phase 1 - Delta Lake Production Mock Data Seed Engine (Probabilistic)
-- DESCRIPTION: Generates 1,000 highly realistic rows with realistic data noise.
-- ============================================================================

USE customer_churn_analytics;

TRUNCATE TABLE dim_customers;
TRUNCATE TABLE fact_billing_transactions;
TRUNCATE TABLE fact_daily_usage;
TRUNCATE TABLE fact_support_tickets;

-- 1. Populate dim_customers
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

-- 2. Populate fact_billing_transactions
INSERT INTO fact_billing_transactions
SELECT 
    CONCAT('TX-', c.customer_id, '-', LPAD(CAST(m.month_idx AS STRING), 2, '0')) AS transaction_id,
    c.customer_id,
    DATE_ADD(c.signup_date, m.month_idx * 30) AS billing_date,
    CASE c.segment 
        WHEN 'SMB' THEN 49.00 
        WHEN 'Mid-Market' THEN 199.00 
        ELSE 999.00 END AS amount_paid,
    'Monthly' AS subscription_plan,
    CASE WHEN RAND() > 0.95 THEN 'Failed' ELSE 'Success' END AS payment_status
FROM dim_customers c
CROSS JOIN EXPLODE(SEQUENCE(0, 10)) AS m(month_idx)
WHERE DATE_ADD(c.signup_date, m.month_idx * 30) <= DATE('2026-10-01');

-- 3. Populate fact_daily_usage
INSERT INTO fact_daily_usage (customer_id, activity_date, login_count, feature_a_clicks, feature_b_clicks, session_duration_mins)
SELECT 
    c.customer_id,
    d.activity_date,
    CAST(RAND() * 5 + 1 AS INT) AS login_count,
    CAST(RAND() * 12 AS INT) AS feature_a_clicks,
    CAST(RAND() * 10 AS INT) AS feature_b_clicks,
    CAST(RAND() * 50 + 5 AS INT) AS session_duration_mins
FROM dim_customers c
CROSS JOIN (
    SELECT DATE_ADD(DATE('2026-09-01'), idx) AS activity_date 
    FROM EXPLODE(SEQUENCE(0, 30)) AS t(idx)
) d
WHERE d.activity_date >= c.signup_date;

-- 4. Populate fact_support_tickets
INSERT INTO fact_support_tickets
SELECT 
    CONCAT('TCK-', LPAD(CAST(id AS STRING), 5, '0')) AS ticket_id,
    CONCAT('CUST-', LPAD(CAST(CAST(RAND()*1000 + 1 AS INT) AS STRING), 5, '0')) AS customer_id,
    DATE_ADD(DATE('2026-09-01'), CAST(RAND() * 30 AS INT)) AS created_date,
    CASE CAST(RAND() * 3 AS INT)
        WHEN 0 THEN 'Billing Issue' WHEN 1 THEN 'Technical Bug' ELSE 'Product Feedback' END AS category,
    CASE CAST(RAND() * 3 AS INT)
        WHEN 0 THEN 'Low' WHEN 1 THEN 'Medium' ELSE 'High' END AS priority,
    CASE WHEN RAND() > 0.20 THEN TRUE ELSE FALSE END AS is_resolved,
    CAST(RAND() * 72 + 1 AS INT) AS resolution_time_hours
FROM EXPLODE(SEQUENCE(1, 600)) AS t(id);
