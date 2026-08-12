-- Q6 · CTEs and readability
--
-- Question: the nested version below works. Rewrite it with CTEs so that a
-- reviewer can follow it, and confirm both return the same rows.
--
-- Nested subqueries are read inside-out. CTEs are read top-down, which is how
-- people actually read. That is the entire argument, and it is enough.

-- BEFORE (do not ship this):
--   SELECT region, avg_items FROM (
--     SELECT c.region, AVG(x.items) AS avg_items FROM (
--       SELECT o.order_id, o.customer_id, COUNT(i.order_item_id) AS items
--       FROM (SELECT * FROM (SELECT o.*, ROW_NUMBER() OVER (...) rn FROM orders o) WHERE rn=1) o
--       JOIN order_items i ON i.order_id = o.order_id GROUP BY o.order_id, o.customer_id
--     ) x JOIN customers c ON c.customer_id = x.customer_id GROUP BY c.region
--   ) WHERE avg_items > 2;

-- AFTER:
WITH latest_orders AS (
    SELECT order_id, customer_id, order_date, status
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
),

items_per_order AS (
    SELECT
        lo.order_id,
        lo.customer_id,
        COUNT(i.order_item_id) AS item_lines
    FROM latest_orders AS lo
    JOIN order_items   AS i ON i.order_id = lo.order_id
    GROUP BY lo.order_id, lo.customer_id
),

region_averages AS (
    SELECT
        c.region,
        ROUND(AVG(ipo.item_lines), 3) AS avg_item_lines,
        COUNT(*)                      AS orders
    FROM items_per_order AS ipo
    JOIN customers       AS c ON c.customer_id = ipo.customer_id
    GROUP BY c.region
)

SELECT region, orders, avg_item_lines
FROM region_averages
WHERE avg_item_lines > 2
ORDER BY avg_item_lines DESC;

-- One caveat worth knowing before you use CTEs everywhere: in some engines a
-- CTE is an optimisation fence and is materialised rather than inlined. In
-- SQLite and modern Postgres it is usually inlined. If a CTE rewrite is
-- suddenly slower than the nested version, that is why.

