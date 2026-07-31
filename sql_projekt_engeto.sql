-- 1. tabulka --

create table t_liliana_chundelova_project_sql_primary_final as
with avg_prices as ( 
select  
	extract(year from date_from)::int as year, 
	category_code, 
	round(avg(value)::numeric, 2) as avg_price 
from czechia_price 
group by extract(year from date_from)::int, 
category_code 
), 
avg_payrolls as ( 
select industry_branch_code, 
	payroll_year as year, 
	round(avg(value)::numeric, 2) as avg_payroll 
from czechia_payroll 
where value_type_code = 5958 
	and calculation_code = 200 
group by payroll_year, 
	industry_branch_code 
) 
select ap.avg_payroll, 
	ap.year, 
	ap.industry_branch_code,
	cpib.name as industry_branch, 
	apr.avg_price, 
	apr.category_code,
	cprc.name as product,
	e.gdp 
from avg_prices apr 
join avg_payrolls ap 
	on apr.year = ap.year 
join czechia_payroll_industry_branch cpib 
	on ap.industry_branch_code = cpib.code 
join czechia_price_category cprc 
	on apr.category_code = cprc.code 
join economies e 
	on ap.year = e.year::int  
	and e.country = 'Czech Republic';

-- 2. tabulka --

create table t_liliana_chundelova_project_sql_secondary_final as
select country,
	gdp,
	population,
	gini,
	year
from economies
where lower(trim(country)) in (
    'albania',
    'andorra',
    'austria',
    'belarus',
    'belgium',
    'bosnia and herzegovina',
    'bulgaria',
    'croatia',
    'cyprus',
    'czech republic',
    'denmark',
    'estonia',
    'finland',
    'france',
    'georgia',
    'germany',
    'greece',
    'hungary',
    'iceland',
    'ireland',
    'italy',
    'kazakhstan',
    'kosovo',
    'latvia',
    'liechtenstein',
    'lithuania',
    'luxembourg',
    'malta',
    'moldova',
    'monaco',
    'montenegro',
    'netherlands',
    'north macedonia',
    'norway',
    'poland',
    'portugal',
    'romania',
    'russian federation',
    'san marino',
    'serbia',
    'slovakia',
    'slovenia',
    'spain',
    'sweden',
    'switzerland',
    'turkey',
    'ukraine',
    'united kingdom'
)
and year between 2006 and 2018;

--podklad pro odpověď na 1. otázku--

with clear_payroll as (
    select distinct
        year,
        industry_branch,
        avg_payroll
    from t_liliana_chundelova_project_sql_primary_final 
),
payroll_lag as (
select
 	year,
    industry_branch,
    avg_payroll,
    lag(avg_payroll) over 
   		(partition by industry_branch
        order by year) as previous_year_payroll
from clear_payroll
),
payroll_change as (
select
    year,
    industry_branch,
    avg_payroll,
    previous_year_payroll,
    avg_payroll - previous_year_payroll as payroll_difference
 from payroll_lag
)
select
    industry_branch,
    year,
    avg_payroll,
    previous_year_payroll,
    payroll_difference
from payroll_change
where payroll_difference <= 0
order by industry_branch, year;

--podklad pro odpověď na 2. otázku--

--v jednotlivých odvětvích--

select
	year,
	industry_branch,
	product,
	round (avg_payroll / avg_price,2) as product_per_wage
from t_liliana_chundelova_project_sql_primary_final
where year in ('2006', '2018')
and category_code in ('114201', '111301')
order by industry_branch;

--průměrem pro všechna odvětví--

with unique_wages as (
    select distinct
        year,
        industry_branch,
        avg_payroll
    from t_liliana_chundelova_project_sql_primary_final
    where year in (2006, 2018)
),
avg_wage as (
    select
        year,
        round(avg(avg_payroll), 2) as avg_payroll
    from unique_wages
    group by year
),
prices as (
    select distinct
        year,
        product,
        avg_price
    from t_liliana_chundelova_project_sql_primary_final
    where category_code in ('111301', '114201')
      and year in (2006, 2018)
)
select
    p.year,
    p.product,
    round(aw.avg_payroll / p.avg_price, 2) as product_per_wage
from prices p
join avg_wage aw
    on p.year = aw.year
order by p.year, p.product;

--podklad pro odpověď na 3.otázku--

with unique_prices as (
	select distinct
		year,
		product,
		avg_price
	from t_liliana_chundelova_project_sql_primary_final
),
price_lag as (
	select
		year,
		product,
		avg_price,
		lag(avg_price) over (partition by product
			order by year
		) as previous_price 
	from unique_prices
),
price_change as (
	select
		year,
		product,
		round(((avg_price - previous_price) / previous_price)*100,
		2) as percent_change
	from price_lag
	where previous_price is not null
)
select 
	product,
	round(avg(percent_change),2) as avg_percent_change
from price_change
group by product
order by avg_percent_change;

--podklad pro odpověď na 4.otázku--
with unique_prices as (
	select distinct
		year,
		product,
		avg_price
	from t_liliana_chundelova_project_sql_primary_final
),
price_lag as (
	select
		year,
		product,
		avg_price,
		lag(avg_price) over (partition by product
			order by year
		) as previous_price 
	from unique_prices
),
price_change as (
	select
		year,
		product,
		round(((avg_price - previous_price) / previous_price)*100,
		2) as price_percent_change
	from price_lag
	where previous_price is not null
),
avg_price_change as (
	select 
		year,
		round(avg(price_percent_change),2) as avg_price_growth
	from price_change
	group by year
),
unique_wages as (
	select distinct
		year,
		avg_payroll,
		industry_branch
	from t_liliana_chundelova_project_sql_primary_final
),
wage_lag as (
	select
		year,
		industry_branch,
		avg_payroll,
		lag(avg_payroll) over (partition by industry_branch
			order by year
		) as previous_wage
	from unique_wages
),
wage_change as (
	select
		year,
		round(((avg_payroll - previous_wage) / previous_wage)*100,
		2) as wage_percent_change
	from wage_lag
	where previous_wage is not null
),
avg_wage_change as (
	select 
		year,
		round(avg(wage_percent_change),2) as avg_wage_growth
	from wage_change
	group by year
)
select 
	awc.year,
	awc.avg_wage_growth,
	apc.avg_price_growth,
	round(apc.avg_price_growth - awc.avg_wage_growth,2) 
		as difference
from avg_wage_change awc
join avg_price_change apc
on awc.year = apc.year
where (apc.avg_price_growth - awc.avg_wage_growth) > 10
order by year;

--podklad pro odpověď na 5.otázku--
with unique_gdp as (
	select distinct
		year,
		gdp
	from t_liliana_chundelova_project_sql_primary_final
),
gdp_lag as (
	select 
		year,
		gdp,
		lag(gdp) over (order by year) as previous_gdp
	from unique_gdp
),
gdp_change as (
	select 
		year,
		round((((gdp - previous_gdp) / previous_gdp) *100)::numeric,2)
			as gdp_growth
	from gdp_lag
	where previous_gdp is not null 
),
unique_prices as (
	select distinct
		year,
		product,
		avg_price
	from t_liliana_chundelova_project_sql_primary_final
),
price_lag as (
	select
		year,
		product,
		avg_price,
		lag(avg_price) over (partition by product
			order by year
		) as previous_price 
	from unique_prices
),
price_change as (
	select
		year,
		product,
		round(((avg_price - previous_price) / previous_price)*100,
		2) as price_percent_change
	from price_lag
	where previous_price is not null
),
avg_price_change as (
	select 
		year,
		round(avg(price_percent_change),2) as avg_price_growth
	from price_change
	group by year
),
unique_wages as (
	select distinct
		year,
		avg_payroll,
		industry_branch
	from t_liliana_chundelova_project_sql_primary_final
),
wage_lag as (
	select
		year,
		industry_branch,
		avg_payroll,
		lag(avg_payroll) over (partition by industry_branch
			order by year
		) as previous_wage
	from unique_wages
),
wage_change as (
	select
		year,
		round(((avg_payroll - previous_wage) / previous_wage)*100,
		2) as wage_percent_change
	from wage_lag
	where previous_wage is not null
),
avg_wage_change as (
	select 
		year,
		round(avg(wage_percent_change),2) as avg_wage_growth
	from wage_change
	group by year
)
select
    gc.year,
    awc.avg_wage_growth,
    apc.avg_price_growth,
    gc.gdp_growth,
    lag(gc.gdp_growth) over (order by gc.year) as previous_year_gdp_growth
    from gdp_change gc
join avg_wage_change awc
    on gc.year = awc.year
join avg_price_change apc
    on gc.year = apc.year
order by gc.year;


