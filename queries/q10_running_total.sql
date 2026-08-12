-- Q10 · Running totals and window framing
--
-- Question: daily shipped-order counts for 2024, with a cumulative running
-- total and a 7-day moving average. Be explicit about the frame.

WITH latest_orders AS (
    SELECT order_id, order_date, status
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
),

daily AS (
    SELECT order_date AS day, COUNT(*) AS orders
    FROM latest_orders
    WHERE status = 'shipped'
      AND order_date >= '2024-01-01'
    GROUP BY order_date
)

SELECT
    day,
    orders,

    -- Cumulative from the start of the window to this row
    SUM(orders) OVER (
        ORDER BY day
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,

    -- Trailing 7-day average: this row plus the six before it
    ROUND(AVG(1.0 * orders) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_7d,

    -- Centred 7-day average, for comparison
    ROUND(AVG(1.0 * orders) OVER (
        ORDER BY day
        ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING
    ), 2) AS centred_avg_7d
FROM daily
ORDER BY day
LIMIT 30;

-- The frame matters more than people expect. With ORDER BY and no explicit
-- frame the default is RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW, and
-- RANGE groups tied ORDER BY values together — so with duplicate days you get
-- the same running total on both rows rather than an incrementing one.
-- Write the frame out. It costs one line and removes an entire class of bug.
