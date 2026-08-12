-- Q12 · Rewrite a slow correlated subquery, and measure the improvement
--
-- Question: for every SHIPPED order, how many orders had that customer placed
-- in total (any status) up to and including that date? The correlated version
-- below is correct and slow. Rewrite it with a window function, prove the
-- answers are identical, and measure both with bench.py.
--
-- There are two traps here. One is performance. The other will cost you more.

-- ---------------------------------------------------------------- SLOW
-- The subquery runs once per outer row. With N orders and no supporting index
-- this is a nested scan: the work grows with the square of the row count.
--
--   SELECT
--       o.order_id, o.customer_id, o.order_date,
--       (SELECT COUNT(*)
--          FROM orders AS o2
--         WHERE o2.customer_id = o.customer_id
--           AND o2.order_date <= o.order_date) AS orders_to_date
--   FROM orders AS o
--   WHERE o.status = 'shipped';
--
-- Read it carefully. The outer query filters to shipped. The SUBQUERY DOES NOT.
-- It counts every order the customer placed, whatever its status.

-- ---------------------------------------------------------------- WRONG REWRITE
-- This is the obvious rewrite and it is wrong. WHERE is applied BEFORE window
-- functions, so the window only ever sees shipped rows and the counts come out
-- lower. It is faster, it looks right, and it silently answers a different
-- question.
--
--   SELECT order_id, customer_id, order_date,
--          COUNT(*) OVER (PARTITION BY customer_id ORDER BY order_date
--                         RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
--   FROM orders
--   WHERE status = 'shipped';

-- ---------------------------------------------------------------- RIGHT
-- Compute the window over ALL rows first, then filter. The filter has to happen
-- after the window, which means it happens in an outer query.

WITH counted AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        status,
        COUNT(*) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
            RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS orders_to_date
    FROM orders                       -- no WHERE here: the window needs every row
)
SELECT
    order_id,
    customer_id,
    order_date,
    orders_to_date
FROM counted
WHERE status = 'shipped'              -- filter after the window has been computed
ORDER BY customer_id, order_date
LIMIT 20;

-- The logical order of evaluation, which is not the order you write it in:
--
--   FROM -> WHERE -> GROUP BY -> HAVING -> WINDOW -> SELECT -> ORDER BY -> LIMIT
--
-- WHERE runs before window functions. HAVING runs before window functions.
-- If you need to filter on a window result, or filter after one, you need a
-- second query level. That is not a limitation, it is the definition.

-- RANGE, not ROWS, is also deliberate. The question says "up to and including
-- that date". With ROWS, two orders on the same date get different counts
-- depending on their arbitrary order within the day. RANGE groups tied ORDER BY
-- values together, which is what "up to and including that date" means.

-- ---------------------------------------------------------------- MIDDLE
-- Without window functions, a self-join with grouping still reads each table
-- once and is far better than the correlated version:
--
--   SELECT o.order_id, COUNT(*) AS orders_to_date
--   FROM orders AS o
--   JOIN orders AS o2 ON o2.customer_id = o.customer_id
--                    AND o2.order_date <= o.order_date
--   WHERE o.status = 'shipped'
--   GROUP BY o.order_row_id, o.order_id;

-- ---------------------------------------------------------------- INDEX
-- Measure again with a supporting index and see how much of the gap it closes
-- on its own:
--
--   CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
--
-- Column order in a composite index matters. (customer_id, order_date) supports
-- an equality on customer_id followed by a range on order_date.
-- (order_date, customer_id) does not help this query at all.
