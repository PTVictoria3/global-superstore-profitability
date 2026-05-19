CREATE DATABASE SuperstoreProfitability;
GO
USE SuperstoreProfitability;
GO
DROP TABLE IF EXISTS orders;
GO

CREATE TABLE orders (
    order_id        NVARCHAR(20)   NOT NULL,
    order_date      DATE           NOT NULL,
    ship_date       DATE           NOT NULL,
    ship_mode       NVARCHAR(50)   NOT NULL,
    customer_name   NVARCHAR(100)  NOT NULL,
    segment         NVARCHAR(50)   NOT NULL,
    state           NVARCHAR(100)  NOT NULL,
    country         NVARCHAR(100)  NOT NULL,
    market          NVARCHAR(50)   NOT NULL,
    region          NVARCHAR(50)   NOT NULL,
    product_id      NVARCHAR(50)   NOT NULL,
    category        NVARCHAR(50)   NOT NULL,
    sub_category    NVARCHAR(50)   NOT NULL,
    product_name    NVARCHAR(300)  NOT NULL,
    sales           DECIMAL(12,4)  NOT NULL,
    quantity        SMALLINT       NOT NULL,
    discount        DECIMAL(6,4)   NOT NULL,
    profit          DECIMAL(12,4)  NOT NULL,
    shipping_cost   DECIMAL(10,4)  NOT NULL,
    order_priority  NVARCHAR(20)   NOT NULL,
    year            SMALLINT       NOT NULL,
    profit_margin   DECIMAL(10,4)  NOT NULL,
    is_loss         BIT            NOT NULL,
    discount_level   NVARCHAR(10)   NOT NULL,
    shipping_days   SMALLINT       NOT NULL
);

GO
-- Nhập dữ liệu từ file csv đã cleaning
BULK INSERT orders
FROM 'D:\project\global-superstore-profitability\data\clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,          
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'   
);


--
SELECT TOP 10 * FROM orders;


--
CREATE OR ALTER VIEW v_market_summary AS
SELECT market,category,year,sub_category,
COUNT(DISTINCT order_id) AS total_orders,
COUNT(DISTINCT customer_name) AS total_customers,
SUM(profit) AS total_profit,
SUM(sales) AS total_sales,
ROUND(SUM(profit)/NULLIF(SUM(sales),0),5) AS profit_margin,
ROUND(AVG(discount),5) AS avg_discount,
ROUND(SUM(CAST(is_loss AS float)) / NULLIF(COUNT(*), 0),5) AS loss_rate,
ROUND(SUM(sales)/NULLIF(COUNT(DISTINCT order_id),0),2) AS aov
FROM orders 
GROUP BY  market,category,year,sub_category



 -- lợi nhuận hằng tháng của mỗi thị trường
 WITH
 monthly AS(
 SELECT market,
 SUM(profit) AS monthly_profit,
 SUM(sales) AS monthly_sales,
 DATEFROMPARTS(YEAR(order_date),MONTH(order_date),1) AS month_start
 FROM orders
 GROUP BY market,DATEFROMPARTS(YEAR(order_date),MONTH(order_date),1)
 )
 SELECT market,month_start,monthly_profit,monthly_sales,
 monthly_profit/NULLIF(monthly_sales,0) AS monthly_profit_margin
 FROM monthly
 ORDER BY market,month_start ASC



-- Phân tích RFM
WITH
rfm_raw AS(
	SELECT customer_name,segment,
	DATEDIFF(DAY,MAX(order_date),(SELECT DATEADD(DAY,1,MAX(order_date))	FROM orders)) AS recency,
	COUNT(DISTINCT order_id) AS frequency,
	SUM(sales)	AS monetary
	FROM orders
	GROUP BY customer_name,segment),
rfm_scores AS (
	SELECT *,
	NTILE(5) OVER(ORDER BY recency DESC)  AS r_score,
	NTILE(5) OVER(ORDER BY frequency DESC) AS f_score,
	NTILE(5) OVER(ORDER BY monetary DESC) AS m_score
	FROM rfm_raw )
SELECT customer_name,segment,recency,frequency,monetary,r_score,f_score,m_score

FROM rfm_scores
ORDER BY monetary DESC



-- Ở mức giảm giá nào thì lợi nhuận âm
SELECT
ROUND(discount,1) AS discount_range,
COUNT(*) AS order_lines,
AVG(profit_margin) AS avg_profit_margin,
SUM(profit)/NULLIF(SUM(sales),0) AS agg_profit_margin,
SUM(CAST(is_loss AS FLOAT))/COUNT(*) AS loss_rate

FROM orders
GROUP BY ROUND(discount,1)
ORDER BY discount_range