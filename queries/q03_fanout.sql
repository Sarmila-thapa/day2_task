-- Q3 · The fan-out trap
--
-- Question: one row per order joined to many rows per order_item. Show the
-- inflated figure a naive join produces, then produce the correct one.
--
-- This is the bug that produces a revenue number three times too big and is
-- only caught when someone in finance says "that can't be right".

WITH deduped_orders AS (
    -- Use only the latest version of each order, so the fan-out is the only
    -- thing being demonstrated here (see Q7 for the deduplication itself).
    SELECT order_id, customer_id, order_date, status
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
),

-- WRONG: counting distinct orders after joining to items multiplies the count
wrong AS (
    SELECT
        d.status,
        COUNT(*)              AS order_count_inflated,
        SUM(i.quantity)       AS total_quantity
    FROM deduped_orders AS d
    JOIN order_items   AS i ON i.order_id = d.order_id
    GROUP BY d.status
),

-- RIGHT: aggregate the many-side first, then join one-to-one
items_per_order AS (
    SELECT order_id, SUM(quantity) AS order_quantity
    FROM order_items
    GROUP BY order_id
),
correct AS (
    SELECT
        d.status,
        COUNT(*)                      AS order_count,
        SUM(ipo.order_quantity)       AS total_quantity
    FROM deduped_orders AS d
    LEFT JOIN items_per_order AS ipo ON ipo.order_id = d.order_id
    GROUP BY d.status
)

SELECT
    c.status,
    w.order_count_inflated,
    c.order_count,
    w.order_count_inflated - c.order_count AS rows_added_by_fanout,
    w.total_quantity,
    c.total_quantity
FROM correct AS c
JOIN wrong   AS w ON w.status = c.status
ORDER BY c.status;

-- Note that total_quantity is identical in both. Summing the many-side is fine.
-- It is COUNT(*) and any aggregate over the ONE-side that get inflated.

