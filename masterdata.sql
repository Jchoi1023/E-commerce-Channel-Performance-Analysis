-- Joined orders, order_items, and users tables to calculate
-- monthly revenue, total orders, and unique customers by traffic source,
-- excluding cancelled and returned orders

-- SELECT
--   u.traffic_source,
--   DATE_TRUNC(o.created_at, MONTH) AS order_month,
--   COUNT(DISTINCT o.order_id) AS total_orders,
--   COUNT(DISTINCT o.user_id) AS unique_customers,
--   ROUND(SUM(oi.sale_price), 2) AS total_revenue
-- FROM `bigquery-public-data.thelook_ecommerce.orders` o
-- LEFT JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi
--   ON o.order_id = oi.order_id
-- LEFT JOIN `bigquery-public-data.thelook_ecommerce.users` u
--   ON o.user_id = u.id
-- WHERE o.status NOT IN ('Cancelled', 'Returned')
--   AND o.created_at BETWEEN '2022-01-01' AND '2024-12-31'
-- GROUP BY u.traffic_source, order_month
-- ORDER BY order_month, total_revenue DESC

-- CTE 1: base monthly revenue by traffic source
WITH monthly_revenue AS (
  SELECT
    u.traffic_source,
    DATE(DATE_TRUNC(o.created_at, MONTH)) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.user_id) AS unique_customers,
    ROUND(SUM(oi.sale_price), 2) AS total_revenue
  FROM `bigquery-public-data.thelook_ecommerce.orders` o
  LEFT JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi
    ON o.order_id = oi.order_id
  LEFT JOIN `bigquery-public-data.thelook_ecommerce.users` u
    ON o.user_id = u.id
  WHERE o.status NOT IN ('Cancelled', 'Returned')
    AND o.created_at BETWEEN '2022-01-01' AND '2024-12-31'
  GROUP BY u.traffic_source, order_month
),

-- CTE 2: add month-over-month growth and channel rank
final AS (
  SELECT
    traffic_source,
    order_month,
    total_orders,
    unique_customers,
    total_revenue,
    LAG(total_revenue) OVER (PARTITION BY traffic_source ORDER BY order_month) AS prev_month_revenue,
    ROUND((total_revenue - LAG(total_revenue) OVER (PARTITION BY traffic_source ORDER BY order_month))
      / NULLIF(LAG(total_revenue) OVER (PARTITION BY traffic_source ORDER BY order_month), 0) * 100, 2) AS mom_growth_pct,
    RANK() OVER (PARTITION BY order_month ORDER BY total_revenue DESC) AS channel_rank
  FROM monthly_revenue
)

SELECT * FROM final
ORDER BY order_month, channel_rank