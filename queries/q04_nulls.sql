-- Q4 · Aggregation and NULL behaviour
--
-- Question: some customers have no credit_limit. Show how COUNT, AVG and SUM
-- each treat those NULLs, and produce the figure a business user actually means
-- when they ask for "average credit limit".

SELECT
    COUNT(*)                                   AS all_customers,
    COUNT(credit_limit)                        AS customers_with_a_limit,
    COUNT(*) - COUNT(credit_limit)             AS customers_with_null,

    -- AVG ignores NULLs entirely: it divides by customers_with_a_limit
    ROUND(AVG(credit_limit), 2)                AS avg_ignoring_nulls,

    -- Treating NULL as zero changes the denominator and the answer
    ROUND(AVG(COALESCE(credit_limit, 0)), 2)   AS avg_treating_null_as_zero,

    -- SUM ignores NULLs too, so the totals agree even though the averages differ
    ROUND(SUM(credit_limit), 2)                AS sum_ignoring_nulls,
    ROUND(SUM(COALESCE(credit_limit, 0)), 2)   AS sum_with_coalesce
FROM customers;

-- The question to ask the business is which they mean. "Average limit across
-- customers who have one" and "average limit across all customers, counting
-- unset as zero" are different numbers and both are defensible. Guessing is not.
--
-- Also worth knowing: NULL = NULL is not true, it is NULL. Use IS NULL.

