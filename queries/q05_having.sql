-- Q5 · HAVING versus WHERE
--
-- Question: for shipped orders only, list regions with more than 150 orders,
-- ordered by order count. Use WHERE and HAVING correctly and explain in a
-- comment why each clause is where it is.
--
-- WHERE filters rows BEFORE grouping. HAVING filters groups AFTER aggregating.
-- Putting an aggregate in WHERE is an error. Putting a row condition in HAVING
-- works but scans more rows than it needs to.

WITH latest_orders AS (
    SELECT order_id, customer_id, order_date, status
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
)
SELECT
    c.region,
    COUNT(*)                              AS shipped_orders,
    COUNT(DISTINCT lo.customer_id)        AS distinct_customers
FROM latest_orders AS lo
JOIN customers     AS c ON c.customer_id = lo.customer_id
WHERE lo.status = 'shipped'               -- row-level: cheaper here, before grouping
GROUP BY c.region
HAVING COUNT(*) > 150                     -- group-level: can only be tested after
ORDER BY shipped_orders DESC;
