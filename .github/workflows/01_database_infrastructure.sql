-- ============================================================================
-- PROJECT: AI-Powered Customer Churn Analytics & Lifetime Value Predictor
-- COMPONENT: Phase 1 - Delta Lake Database Infrastructure
-- DESCRIPTION: Creates an optimized Star-Schema data catalog.
-- ============================================================================

-- 1. Initialize Databricks Catalog Schema
CREATE SCHEMA IF NOT EXISTS customer_churn_analytics;
USE customer_churn_analytics;

-- 2. Dimension Table: Customer Master Profiles
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id STRING,
    signup_date DATE,
    country STRING,
    acquisition_channel STRING,
    segment STRING -- Enterprise, Mid-Market, SMB
) USING DELTA;

-- 3. Fact Table: Subscription Billings & Transactions
CREATE TABLE IF NOT EXISTS fact_billing_transactions (
    transaction_id STRING,
    customer_id STRING,
    billing_date DATE,
    amount_paid DECIMAL(10, 2),
    subscription_plan STRING, -- Monthly, Annual
    payment_status STRING -- Success, Failed, Refunded
) USING DELTA;

-- 4. Fact Table: Platform Activity & Product Usage Logs
CREATE TABLE IF NOT EXISTS fact_daily_usage (
    usage_id BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id STRING,
    activity_date DATE,
    login_count INT,
    feature_a_clicks INT,
    feature_b_clicks INT,
    session_duration_mins INT
) USING DELTA;

-- 5. Fact Table: Customer Support Operations Tickets
CREATE TABLE IF NOT EXISTS fact_support_tickets (
    ticket_id STRING,
    customer_id STRING,
    created_date DATE,
    category STRING, -- Billing, Technical, Product Bug
    priority STRING, -- Low, Medium, High
    is_resolved BOOLEAN,
    resolution_time_hours INT
) USING DELTA;
