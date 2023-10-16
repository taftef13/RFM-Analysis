--inspecting data
select * from [dbo].[sales_data_sample]

--checking unique value
select distinct status from [dbo].[sales_data_sample]
select distinct YEAR_ID from [dbo].[sales_data_sample]
select distinct PRODUCTLINE from [dbo].[sales_data_sample]
select distinct Country from [dbo].[sales_data_sample]
select distinct DEALSIZE from [dbo].[sales_data_sample]
select distinct TERRITORY from [dbo].[sales_data_sample] 

--ANALYSIS
---Grouping sales by producline
select PRODUCTLINE, sum(Sales) as Revenue
From [dbo].[sales_data_sample]
group by PRODUCTLINE
order by 2 desc

---Grouping sales by year
select YEAR_ID, sum(Sales) as Revenue
From [dbo].[sales_data_sample]
group by YEAR_ID
order by 2 desc

select distinct MONTH_ID
from [dbo].[sales_data_sample]
where year_id = 2004
order by MONTH_ID 

-- grouping sales by dealsize
select DEALSIZE, sum(sales) Revenue
from [dbo].[sales_data_sample]
Group by DEALSIZE
order by 2 desc

--what was the best month for sales in a specific year ? 
--how much was earned that month ? 
select MONTH_ID, sum(sales) Revenue, count(Ordernumber) Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2003 -- change year to see the rest
group by MONTH_ID
order by Revenue desc

--November seems to be the month, what product do they sell in November ?
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, COUNT(ordernumber) Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2003 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by 3 desc

-- who is our best customer (this could be best answer with RFM) 
drop table if exists #rfm;
with rfm as
(select
	CUSTOMERNAME,
	Sum(sales) MonetaryValue,
	AVG(sales) AvgMonetaryValue,
	COUNT(ordernumber) Frequency,
	max(OrderDate) last_order_date,
	(select max(orderdate) from [dbo].[sales_data_sample]) as Max_last_order_date,
	DATEDIFF(DAY,max(OrderDate),(select max(orderdate) from [dbo].[sales_data_sample])) as Recency
From [dbo].[sales_data_sample]
group by CUSTOMERNAME
),
rfm_calc as
(
	select 
		r.*,
		ntile(4) over (order by Recency desc) rfm_recency,
		ntile(4) over (order by Frequency) rfm_frequency,
		ntile(4) over (order by MonetaryValue) rfm_monetary
	from rfm as r
)
select  
	c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) as rfm_cell_string
into #rfm
from rfm_calc as c
--SEGMENT
select 
	CUSTOMERNAME,  rfm_recency , rfm_frequency , rfm_monetary,
	case
		when rfm_cell_string in (111,112,121,122,123,132,211,212,114,141) then 'lost_customers'
		when rfm_cell_string in (133,134,143,244,334,343,344,113,144,234) then 'slipping away, cannot lose' -- Big spenders who haven't purchased lately
		when rfm_cell_string in (311,411,331,412) then 'new customers'
		when rfm_cell_string in (222,223,233,322,232,221) then 'potential churners'
		when rfm_cell_string in (323,333,321,422,421,332,432) then 'active' --Customers who buy often & recently, but at low price points
		when rfm_cell_string in (433,434,443,444,423) then 'loyal'
	end as rfm_segment
from #rfm

--what products are most often sold together

--select * from [dbo].[sales_data_sample] where ORDERNUMBER =10411
select distinct ORDERNUMBER , stuff(
	(select ',' + PRODUCTCODE
	from [dbo].[sales_data_sample] p
	where ORDERNUMBER in
		(
		select m.ORDERNUMBER					--find the order have 'rn' products
		from (
				select ORDERNUMBER,count(*) rn    
				from [dbo].[sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
		where m.rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path('')) , 1, 1, '') ProductCodes 
from [dbo].[sales_data_sample] s
order by 2 desc