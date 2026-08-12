-- Q8 · ROW_NUMBER versus RANK versus DENSE_RANK
--
-- Question: top 3 products by quantity sold in each region. Show all three
-- ranking functions side by side so the difference at a tie is visible.

WITH latest_orders AS (
    SELECT order_id, customer_id
    FROM (
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
        FROM orders AS o
    )
    WHERE rn = 1
),

region_product_totals AS (
    SELECT
        c.region,
        p.product_name,
        SUM(i.quantity) AS units
    FROM latest_orders AS lo
    JOIN customers     AS c ON c.customer_id = lo.customer_id
    JOIN order_items   AS i ON i.order_id    = lo.order_id
    JOIN products      AS p ON p.product_id  = i.product_id
    GROUP BY c.region, p.product_name
),

ranked AS (
    SELECT
        region,
        product_name,
        units,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY units DESC) AS rn,
        RANK()       OVER (PARTITION BY region ORDER BY units DESC) AS rnk,
        DENSE_RANK() OVER (PARTITION BY region ORDER BY units DESC) AS dense
    FROM region_product_totals
)

SELECT region, product_name, units, rn, rnk, dense
FROM ranked
WHERE rnk <= 3                 -- RANK, so genuine ties all appear
ORDER BY region, rnk, product_name;

--   ROW_NUMBER  1,2,3,4  — always unique, arbitrary at a tie unless you break it
--   RANK        1,2,2,4  — ties share a rank, then it skips
--   DENSE_RANK  1,2,2,3  — ties share a rank, no gap
--
-- "Top 3" is ambiguous when there are ties. Ask which behaviour is wanted before
-- you pick one. Choosing ROW_NUMBER silently drops a genuinely tied product.

