-- Data Inspection
select * from [dbo].[sales_data_sample]
order by ORDERNUMBER 

-- Data cleaning

ALTER TABLE [dbo].[sales_data_sample]
add DATEORDERED date

UPDATE [dbo].[sales_data_sample]
SET DATEORDERED = CONVERT(date, ORDERDATE)

ALTER TABLE [dbo].[sales_data_sample]
DROP COLUMN ORDERDATE 

-- Check unique values
select distinct status from [dbo].[sales_data_sample] 
select distinct year_id from [dbo].[sales_data_sample]
select distinct PRODUCTLINE from [dbo].[sales_data_sample]
select distinct COUNTRY from [dbo].[sales_data_sample]
select distinct DEALSIZE from [dbo].[sales_data_sample] 
select distinct TERRITORY from [dbo].[sales_data_sample] 

-- Analysis

-- Group sales by productline
select PRODUCTLINE, sum(sales) as Revenue
from [dbo].[sales_data_sample]
group by PRODUCTLINE
order by 2 desc

select YEAR_ID, sum(sales) as Revenue
from [dbo].[sales_data_sample]
group by YEAR_ID
order by 2 desc

select DEALSIZE, sum(sales) as Revenue
from [dbo].[sales_data_sample]
group by DEALSIZE
order by 2 desc

-- Best month for a specific year

select year_id, month_id, sum(sales) as Revenue, count(ORDERNUMBER) as Frequency
from [dbo].[sales_data_sample]
group by YEAR_ID, month_ID 
order by 1, 3 desc

-- November seems to be the best month, what product sells?

select year_id, month_id, PRODUCTLINE, sum(sales) as Revenue, count(ORDERNUMBER) as Frequency
from [dbo].[sales_data_sample]
where MONTH_ID = 11
group by YEAR_ID, month_ID , PRODUCTLINE
order by 1, 4 desc


-- Best customer (RFM)
DROP TABLE IF EXISTS #rfm

;with rfm as
	(select CUSTOMERNAME,
		sum(SALES) as MonetaryValue,
		avg(SALES) as AvgMonetaryValue,
		count(ORDERNUMBER) as Frequency,
		max(DATEORDERED) as last_order_date,
		(select max(DATEORDERED) from [dbo].[sales_data_sample]) as max_order_date,
		DATEDIFF(day, max(DATEORDERED), (select max(DATEORDERED) from [dbo].[sales_data_sample])) as Recency
	from [dbo].[sales_data_sample]
	group by CUSTOMERNAME),
rfm_calc as
	(select *,
		ntile(4) over(order by Recency desc) as rfm_recency,
		ntile(4) over(order by Frequency) as rfm_frequency,
		ntile(4) over(order by AvgMonetaryValue) as rfm_monetary
	from rfm)

select *,
rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) as rfm_cell_str
into #rfm
from rfm_calc

select CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary, rfm_cell, rfm_cell_str,  
	case
		when rfm_cell_str in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141, 131, 142, 113) then 'lost_customers'
		when rfm_cell_str in (133, 134, 143, 244, 334, 343, 344, 144, 234, 224, 214) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately)
		when rfm_cell_str in (311, 411, 331, 421, 312) then 'new customers'
		when rfm_cell_str in (222, 223, 233, 322, 241, 231, 221, 242) then 'potential churners'
		when rfm_cell_str in (323, 333,321, 422, 332, 432, 341, 441, 342, 442, 314, 414) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_str in (433, 434, 443, 444, 424) then 'loyal'
	end as rfm_segment
from #rfm