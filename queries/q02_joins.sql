-- Q2 · INNER versus LEFT join
--
-- Question: how many customers have never placed an order? Show why an INNER
-- join cannot answer this and a LEFT join can.
--
-- The trap: adding a WHERE clause on the right-hand table silently converts a
-- LEFT join back into an INNER join. That is the single most common join bug.

-- Customers with no orders at all
SELECT
    c.region,
    COUNT(*) AS customers_with_no_orders
FROM customers AS c
LEFT JOIN orders AS o
       ON o.customer_id = c.customer_id
WHERE o.order_row_id IS NULL          -- the IS NULL test is what makes it an anti-join
GROUP BY c.region
ORDER BY customers_with_no_orders DESC, c.region;

-- Compare: this looks similar and is wrong. Putting a condition on the right
-- table in WHERE (rather than in ON) discards the unmatched rows first.
--
--   SELECT COUNT(*) FROM customers c
--   LEFT JOIN orders o ON o.customer_id = c.customer_id
--   WHERE o.status = 'shipped';       -- now an INNER join in all but name

