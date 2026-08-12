-- Q11 · Point-in-time lookup
--
-- Question: value each order using the price that was in force ON THE ORDER
-- DATE, not the price today. Show what using today's price would have cost you.
--
-- This is the query most people get wrong, and it is wrong in a way that looks
-- perfectly fine until someone reconciles against the source system.

WITH latest_orders AS (
    SELECT order_id, customer_id, order_date, status
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
),

-- CORRECT: the price row whose validity window contains the order date.
-- valid_to is exclusive, so the comparison is >= valid_from AND < valid_to.
priced_correctly AS (
    SELECT
        lo.order_id,
        lo.order_date,
        i.product_id,
        i.quantity,
        ph.unit_price,
        i.quantity * ph.unit_price AS line_total
    FROM latest_orders  AS lo
    JOIN order_items    AS i  ON i.order_id   = lo.order_id
    JOIN price_history  AS ph ON ph.product_id = i.product_id
                             AND lo.order_date >= ph.valid_from
                             AND lo.order_date <  ph.valid_to
),

-- WRONG: today's price applied to every historical order.
current_prices AS (
    SELECT product_id, unit_price
    FROM price_history
    WHERE valid_to = '9999-12-31'
),
priced_at_today AS (
    SELECT
        lo.order_id,
        i.quantity * cp.unit_price AS line_total
    FROM latest_orders AS lo
    JOIN order_items   AS i  ON i.order_id  = lo.order_id
    JOIN current_prices AS cp ON cp.product_id = i.product_id
)

SELECT
    ROUND(SUM(pc.line_total), 2)                       AS revenue_point_in_time,
    ROUND((SELECT SUM(line_total) FROM priced_at_today), 2) AS revenue_using_today_price,
    ROUND((SELECT SUM(line_total) FROM priced_at_today)
          - SUM(pc.line_total), 2)                     AS overstatement,
    COUNT(*)                                           AS priced_lines
FROM priced_correctly AS pc;

-- Two checks worth running before you trust this:
--   1. priced_lines should equal the number of order_item rows for latest orders.
--      If it is lower, some order dates fall outside every validity window and
--      the INNER join has silently dropped them.
--   2. No order line should match two price rows. If the count is higher than
--      expected, your validity windows overlap and you have a fan-out.
