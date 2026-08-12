-- Q1 · Grain
--
-- Question: what is the grain of the orders table? Prove it with a query rather
-- than asserting it, and show how many order_ids have more than one row.
--
-- Why this is first: grain is the first thing to establish about any table and
-- the thing most people assume instead of checking. Every later query in this
-- lab depends on getting this right.

SELECT
    COUNT(*)                                        AS total_rows,
    COUNT(DISTINCT order_id)                        AS distinct_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id)             AS surplus_rows,
    ROUND(
        1.0 * COUNT(*) / COUNT(DISTINCT order_id), 4
    )                                               AS rows_per_order_id
FROM orders;

-- The grain is NOT one row per order. It is one row per *version* of an order.
-- Any query that treats order_id as unique will double count the corrected ones.
