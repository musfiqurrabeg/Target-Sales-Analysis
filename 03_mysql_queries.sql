-- 1. List all unique cities where customers are located.

SELECT 
	DISTINCT customer_city 
FROM customers;


-- 2. Find the total sales per category

SELECT 
	UPPER(products.product_category) AS category,
	ROUND(SUM(payments.payment_value), 2) AS sales
FROM products 
JOIN order_items
ON products.product_id = order_items.product_id
JOIN payments 
ON payments.order_id = order_items.order_id
GROUP BY category;


-- 3. Count the number of orders placed in 2017.

SELECT 
	COUNT(order_id) AS total_order
FROM orders
WHERE YEAR(order_purchase_timestamp) = 2017;


-- 4. Calculate the percentage of orders that were paid in installments.

SELECT 
	(SUM(
		CASE 
			WHEN payment_installments >= 1 THEN 1
			ELSE 0
		END
	) / COUNT(*)) * 100 AS percentage_paid_installments
FROM payments;


-- 5. Count the number of customers from each state.

SELECT 
	customer_state,
	COUNT(customer_id)
FROM customers
GROUP BY customer_state
ORDER BY customer_state;


-- 6. Calculate the number of orders per month in 2018.

SELECT 
	MONTHNAME(order_purchase_timestamp) AS months,
	COUNT(order_id) AS total_order
FROM orders
WHERE YEAR(order_purchase_timestamp) = 2018
GROUP BY months;


-- 7. Find the average number of products per order, grouped by customer city.

with count_per_order as 
(
SELECT 
	orders.order_id, 
	orders.customer_id, 
	COUNT(order_items.order_id) AS oc
FROM orders JOIN order_items
ON orders.order_id = order_items.order_id
GROUP BY orders.order_id, orders.customer_id
)
SELECT 
	customers.customer_city, 
	ROUND(AVG(count_per_order.oc),2) AS average_orders
FROM customers JOIN count_per_order
ON customers.customer_id = count_per_order.customer_id
GROUP BY customers.customer_city 
ORDER BY average_orders DESC;



-- 8. Calculate the percentage of total revenue contributed by each product category.

SELECT 
UPPER(products.product_category) AS category, 
ROUND((SUM(payments.payment_value)/
		(SELECT 
			SUM(payment_value) 
		FROM payments)
		) * 100, 2) AS sales_percentage
FROM products JOIN order_items 
ON products.product_id = order_items.product_id
JOIN payments 
ON payments.order_id = order_items.order_id
GROUP BY category 
ORDER BY sales_percentage DESC;



-- 9. Identify the correlation between product price and the number of times a product has been purchased.

SELECT 
	products.product_category AS category,
	COUNT(order_items.product_id) AS order_count,
	ROUND(AVG(order_items.price), 2) AS price
FROM products 
JOIN order_items
ON products.product_id = order_items.product_id
GROUP BY products.product_category;



-- 10. Calculate the total revenue generated by each seller, and rank them by revenue.

SELECT
	*,
	DENSE_RANK() OVER(ORDER BY revenue DESC) AS rn
FROM (
	SELECT
		order_items.seller_id AS sellerid,
		SUM(payments.payment_value) AS revenue
	FROM order_items
	JOIN payments
	ON order_items.order_id = payments.order_id
	GROUP BY order_items.seller_id
) AS a;


-- 11. Calculate the moving average of order values for each customer over their order history.

SELECT 
	customer_id,
	order_purchase_timestamp,
	payment,
	avg(payment) over(partition by customer_id order by order_purchase_timestamp
	rows between 2 preceding and current row) as mov_avg
FROM (
	SELECT
		orders.customer_id, 
		orders.order_purchase_timestamp, 
		payments.payment_value as payment
	FROM payments JOIN orders
	ON payments.order_id = orders.order_id
) AS a;



-- 12. Calculate the cumulative sales per month for each year.

SELECT 
	years, 
	months, 
	payment, 
	SUM(payment) OVER(order by years, months) 
	cumulative_sales 
FROM 
(
	SELECT 
		year(orders.order_purchase_timestamp) as years,
		month(orders.order_purchase_timestamp) as months,
		round(sum(payments.payment_value),2) as payment 
	FROM orders JOIN payments
	ON orders.order_id = payments.order_id
	GROUP BY years, months 
	ORDER BY years, months
) as a;



-- 13. Calculate the year-over-year growth rate of total sales.

WITH payment_per_year AS (
    SELECT 
        YEAR(orders.order_purchase_timestamp) AS year,
        ROUND(SUM(payments.payment_value), 2) AS total_payment
    FROM orders
    JOIN payments ON orders.order_id = payments.order_id
    GROUP BY year
    ORDER BY year
)
SELECT 
    year,
    ROUND(
        ((total_payment - LAG(total_payment) OVER (ORDER BY year)) / 
         LAG(total_payment) OVER (ORDER BY year)) * 100, 
        2
    ) AS yoy_growth_percentage
FROM payment_per_year;



-- 14. Calculate the retention rate of customers, defined as the percentage of customers
-- who make another purchase within 6 months of their first purchase.

WITH first_orders AS (
    SELECT
        customers.customer_id,
        MIN(orders.order_purchase_timestamp) AS first_order_date
    FROM customers
    JOIN orders ON customers.customer_id = orders.customer_id
    GROUP BY customers.customer_id
),
next_orders_within_6_months AS (
    SELECT 
        customers.customer_id,
        COUNT(DISTINCT orders.order_id) AS next_orders_count
    FROM customers
    JOIN orders ON customers.customer_id = orders.customer_id
    JOIN first_orders ON customers.customer_id = first_orders.customer_id
    WHERE orders.order_purchase_timestamp > first_orders.first_order_date
      AND orders.order_purchase_timestamp <= DATE_ADD(first_orders.first_order_date, INTERVAL 6 MONTH)
    GROUP BY customers.customer_id
)
SELECT
    ROUND(
        100 * COUNT(DISTINCT next_orders_within_6_months.customer_id) / COUNT(DISTINCT first_orders.customer_id),
        2
    ) AS repurchase_rate
FROM first_orders
LEFT JOIN next_orders_within_6_months
ON first_orders.customer_id = next_orders_within_6_months.customer_id;


-- 15. Identify the top 3 customers who spent the most money in each year.

WITH ranked_customers AS (
	SELECT 
		YEAR(orders.order_purchase_timestamp) AS years,
		orders.customer_id,
		SUM(payments.payment_value) AS total_payment,
		DENSE_RANK() OVER(
			PARTITION BY YEAR(orders.order_purchase_timestamp) 
			ORDER BY SUM(payments.payment_value) DESC
		) AS ranks
	FROM orders JOIN payments
	ON orders.order_id = payments.order_id
	GROUP BY YEAR(orders.order_purchase_timestamp), orders.customer_id
)
SELECT
	years,
	customer_id,
	total_payment,
	ranks
FROM ranked_customers
WHERE ranks <=3
ORDER BY years, ranks

