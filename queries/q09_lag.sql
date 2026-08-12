-- Q9 · LAG — month-over-month change
--
-- Question: monthly shipped order counts, with the previous month's figure and
-- the percentage change. Handle the first month, which has no previous value.

WITH latest_orders AS (
    SELECT order_id, order_date, status
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
),

monthly AS (
    SELECT
        substr(order_date, 1, 7) AS month,          -- 'YYYY-MM'
        COUNT(*)                 AS orders
    FROM latest_orders
    WHERE status = 'shipped'
    GROUP BY substr(order_date, 1, 7)
)

SELECT
    month,
    orders,
    LAG(orders)    OVER (ORDER BY month) AS prev_month_orders,
    orders - LAG(orders) OVER (ORDER BY month) AS change,
    CASE
        WHEN LAG(orders) OVER (ORDER BY month) IS NULL THEN NULL   -- first month
        WHEN LAG(orders) OVER (ORDER BY month) = 0     THEN NULL   -- avoid div by zero
        ELSE ROUND(
            100.0 * (orders - LAG(orders) OVER (ORDER BY month))
                  / LAG(orders) OVER (ORDER BY month), 2)
    END AS pct_change
FROM monthly
ORDER BY month;

-- LAG returns NULL for the first row of each partition. Returning NULL is the
-- honest answer — do not COALESCE it to zero, which would report a 100% drop
-- that never happened.
--
-- LEAD is the same function looking forward. LAG(orders, 3) looks back three rows.
