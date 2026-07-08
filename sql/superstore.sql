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





--  Sub-category nào, ở market nào, có sales cao nhưng đang lỗ?
-- Ở mức market x category không có ô nào lỗ, phải xuống mức sub_category mới thấy
WITH
loss_groups AS(
	SELECT market,sub_category,
	SUM(sales) AS total_sales,
	SUM(profit) AS total_profit,
	ROUND(SUM(profit)/NULLIF(SUM(sales),0),5) AS profit_margin,
	ROUND(SUM(CAST(is_loss AS FLOAT))/COUNT(*),5) AS loss_rate
	FROM orders
	GROUP BY market,sub_category
	HAVING SUM(profit) < 0
)
SELECT *,
SUM(total_profit) OVER(ORDER BY total_profit ASC) AS cumulative_loss
FROM loss_groups
ORDER BY total_profit ASC



--Ở mức giảm giá nào thì lợi nhuận âm
SELECT
ROUND(discount,1) AS discount_range,
COUNT(*) AS order_lines,
SUM(profit)/NULLIF(SUM(sales),0) AS agg_profit_margin,
SUM(CAST(is_loss AS FLOAT))/COUNT(*) AS loss_rate
FROM orders
GROUP BY ROUND(discount,1)
ORDER BY discount_range



-- So sánh trong cùng sub_category và cùng market
-- Nhìn tổng thể chưa đủ vì discount cao thường rơi vào sản phẩm/thị trường vốn đã lỗ,
-- so sánh trong cùng nhóm mới tách được tác động của discount
SELECT market,sub_category,discount_level,
COUNT(*) AS order_lines,
ROUND(SUM(profit)/NULLIF(SUM(sales),0),5) AS profit_margin,
ROUND(SUM(CAST(is_loss AS FLOAT))/COUNT(*),5) AS loss_rate
FROM orders
GROUP BY market,sub_category,discount_level
ORDER BY market,sub_category,
CASE discount_level WHEN 'No' THEN 1 WHEN 'Low' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END



--  Đơn Critical có được giao nhanh hơn không và nhanh hơn đó tốn thêm bao nhiêu?
SELECT order_priority,ship_mode,
COUNT(*) AS order_lines,
ROUND(AVG(CAST(shipping_days AS FLOAT)),2) AS avg_shipping_days,
ROUND(AVG(shipping_cost),2) AS avg_shipping_cost,
ROUND(SUM(shipping_cost)/NULLIF(SUM(sales),0),5) AS shipping_cost_ratio
FROM orders
GROUP BY order_priority,ship_mode
ORDER BY CASE order_priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END,
AVG(CAST(shipping_days AS FLOAT))



