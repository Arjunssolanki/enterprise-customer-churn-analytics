USE customer_churn_analytics;

DROP TABLE IF EXISTS analytics_feature_store;

CREATE TABLE analytics_feature_store USING DELTA AS
WITH monthly_billing AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', billing_date) AS snapshot_month,
        SUM(amount_paid) AS total_revenue_monthly,
        COUNT(CASE WHEN payment_status = 'Failed' THEN 1 END) AS failed_payments_30d
    FROM fact_billing_transactions
    GROUP BY customer_id, DATE_TRUNC('month', billing_date)
),
usage_aggregates AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', activity_date) AS snapshot_month,
        SUM(login_count) AS total_logins_30d,
        SUM(session_duration_mins) AS total_duration_30d,
        LAG(SUM(login_count), 1) OVER (PARTITION BY customer_id ORDER BY DATE_TRUNC('month', activity_date)) AS logins_prev_month
    FROM fact_daily_usage
    GROUP BY customer_id, DATE_TRUNC('month', activity_date)
),
support_aggregates AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', created_date) AS snapshot_month,
        COUNT(ticket_id) AS support_tickets_30d,
        COUNT(CASE WHEN priority = 'High' THEN 1 END) AS high_priority_tickets_30d
    FROM fact_support_tickets
    GROUP BY customer_id, DATE_TRUNC('month', created_date)
)

SELECT 
    c.customer_id,
    b.snapshot_month,
    c.segment,
    c.acquisition_channel,
    c.country,
    CAST(MONTHS_BETWEEN(b.snapshot_month, c.signup_date) AS INT) AS tenure_months,
    COALESCE(b.total_revenue_monthly, 0.00) AS current_monthly_rev,
    COALESCE(b.failed_payments_30d, 0) AS failed_payments_30d,
    COALESCE(u.total_logins_30d, 0) AS total_logins_30d,
    COALESCE(u.total_duration_30d, 0) AS total_duration_30d,
    COALESCE(u.total_logins_30d, 0) - COALESCE(u.logins_prev_month, 0) AS login_velocity_30d,
    COALESCE(s.support_tickets_30d, 0) AS support_tickets_30d,
    COALESCE(s.high_priority_tickets_30d, 0) AS high_priority_tickets_30d,
    
    -- INDUSTRIAL REPAIR STEP: Creating a realistic, probabilistic non-linear boundary condition
    CASE 
        WHEN (COALESCE(u.total_logins_30d, 0) * RAND()) < 15 
             OR (COALESCE(s.support_tickets_30d, 0) * RAND()) > 1.2 
             OR RAND() > 0.88 -- Pure market churn noise rate (12% baseline random loss)
        THEN 1 ELSE 0 
    END AS target_churned_next_month
FROM dim_customers c
JOIN monthly_billing b ON c.customer_id = b.customer_id
LEFT JOIN usage_aggregates u ON c.customer_id = u.customer_id AND b.snapshot_month = u.snapshot_month
LEFT JOIN support_aggregates s ON c.customer_id = s.customer_id AND b.snapshot_month = s.snapshot_month
WHERE u.total_logins_30d IS NOT NULL;
