use market_channel_db;

select count(*) as Ads_Total_Rows from dbo.ad;
select count(*) as signups_total_rows from dbo.signups;

select * From dbo.ad;

--1 Are any rows repeated in the spend table?

SELECT [date], campaign, COUNT(*) AS rows_per_day   
FROM dbo.ad                                          
GROUP BY [date], campaign                           
HAVING COUNT(*) > 1;  

--2 How much money did each ad spend, and how many views and clicks did it get?
select campaign ,CAST(sum(spend) as DECIMAL(12,2))as total_spend ,
                 sum(impressions) as total_views,
                 sum(clicks) as total_clicks
from dbo.ad 
group by campaign
order by total_spend Asc;

--3 Which ads get clicked the most, and which clicks are the cheapest?

select campaign,
      CAST(sum(clicks) *100 / sum(impressions) as DECIMAL(12,2)) as click_rate,
      CAST(sum(clicks) *100 / sum(spend) as DECIMAL(12,2)) as cost_per_click
from dbo.ad
group by campaign
order by cost_per_click;

--4 How many signups and paying customers did each ad bring?

select campaign ,
       count(*)as signups,
       count(subscription_start_date)as paying_customer,
       cast(sum(revenue_first_90_days) as decimal(12,2)) as revenue
from dbo.signups
where channel NOT IN ('organic','referral')
group by campaign 
order by signups DESC

--5 What did one signup and one paying customer cost for each ad, and how much money came back per ₹1 spent?
DROP TABLE IF EXISTS #ad_total;                     -- remove an old copy so rerunning does not give an error
DROP TABLE IF EXISTS #signup_total;                 -- same for the second table

SELECT campaign, SUM(spend) AS total_spend         -- total spend per ad
INTO #ad_total                                     -- save it as a small temporary table
FROM dbo.ad
GROUP BY campaign;

SELECT campaign,
       COUNT(*) AS signups,                         -- signups per ad
       COUNT(subscription_start_date) AS paying,    -- paying customers per ad
       SUM(revenue_first_90_days) AS revenue        -- revenue per ad
INTO #signup_total                                 -- save as a second temporary table
FROM dbo.signups
WHERE channel NOT IN ('organic', 'referral')       -- only signups that came from ads
GROUP BY campaign;

SELECT a.campaign,                                                                    -- "a" and "s" are short names for the two tables
       CAST(a.total_spend / s.signups AS DECIMAL(10,2)) AS cost_per_signup,           -- cost of one signup
       CAST(a.total_spend / s.paying AS DECIMAL(10,2)) AS cost_per_paying,            -- cost of one paying customer
       CAST(s.revenue / a.total_spend AS DECIMAL(10,2)) AS money_back_per_1           -- money back for every 1 spent
FROM #ad_total a
JOIN #signup_total s ON a.campaign = s.campaign                                      -- match rows with the same campaign
ORDER BY cost_per_paying;                                                             -- cheapest paying customer first


--6 Is the ad with the cheapest signups also the cheapest for paying customers? Rank the ads

SELECT a.campaign,
       CAST(a.total_spend / s.signups AS DECIMAL(10,2)) AS cost_per_signup   -- cost of one signup
FROM #ad_total a JOIN #signup_total s ON a.campaign = s.campaign
ORDER BY cost_per_signup;                                                    -- list 1: best to worst by signup cost

SELECT a.campaign,
       CAST(a.total_spend / s.paying AS DECIMAL(10,2)) AS cost_per_paying   -- cost of one paying customer
FROM #ad_total a JOIN #signup_total s ON a.campaign = s.campaign
ORDER BY cost_per_paying; 


--7 Out of every 100 signups, how many start paying, for each channel (ads, organic, referral)?

SELECT channel,
       COUNT(*) AS signups,                                                               -- all signups in the channel
       COUNT(subscription_start_date) AS paying,                                          -- those who paid
       CAST(COUNT(subscription_start_date) * 100.0 / COUNT(*) AS DECIMAL(10,1)) AS paying_out_of_100   -- paying divided by signups, times 100
FROM dbo.signups
GROUP BY channel                                                                          -- includes organic and referral
ORDER BY paying_out_of_100 DESC;       



--8 Do paying customers pick the monthly or the yearly plan, and which ad brings more yearly customers?
SELECT campaign,[plan],
       COUNT(*) AS paying_customers                  -- how many chose each plan
FROM dbo.signups
WHERE subscription_start_date IS NOT NULL            -- only people who paid
GROUP BY campaign,[plan]                              -- one row per ad and plan
ORDER BY campaign;




--9 How many days do people take to start paying, for each ad?
SELECT campaign,
       CAST(AVG(DATEDIFF(day, signup_date, subscription_start_date) * 1.0) AS DECIMAL(10,1)) AS avg_days_to_pay   -- days between signup and first payment
FROM dbo.signups
WHERE subscription_start_date IS NOT NULL            -- only people who paid
GROUP BY campaign
ORDER BY avg_days_to_pay;  




--10 How did spend change month by month, and did any ad stop?
SELECT campaign,
       MONTH([date]) AS month_number,                -- 1 = January ... 6 = June
       CAST(SUM(spend) AS DECIMAL(12,2)) AS spend    -- spend in that month
FROM dbo.ad
GROUP BY campaign, MONTH([date])
ORDER BY campaign, month_number; 




--11  Did the cost of a paying customer go up or down over the months?
DROP TABLE IF EXISTS #ad_month;                      -- clear old copies
DROP TABLE IF EXISTS #pay_month;
SELECT campaign, MONTH([date]) AS m, SUM(spend) AS spend           -- spend per ad per month
INTO #ad_month
FROM dbo.ad
GROUP BY campaign, MONTH([date]);

SELECT campaign, MONTH(signup_date) AS m,
       COUNT(subscription_start_date) AS paying                    -- paying customers per ad per month
INTO #pay_month
FROM dbo.signups
WHERE channel NOT IN ('organic', 'referral')
GROUP BY campaign, MONTH(signup_date);

SELECT a.campaign, a.m,
       CAST(a.spend / NULLIF(p.paying, 0) AS DECIMAL(10,2)) AS cost_per_paying   -- NULLIF turns 0 into empty, so there is no divide-by-zero error
FROM #ad_month a
LEFT JOIN #pay_month p ON a.campaign = p.campaign AND a.m = p.m                  -- LEFT JOIN keeps months with no paying customers
ORDER BY a.campaign, a.m;


SELECT SUM(revenue_first_90_days) AS total_revenue   -- all revenue, from every channel
FROM dbo.signups;

SELECT MONTH(signup_date) AS month_number,           -- 1 = January ... 6 = June
       COUNT(*) AS signups,                          -- all signups in that month
       COUNT(subscription_start_date) AS paying      -- those who paid
FROM dbo.signups
GROUP BY MONTH(signup_date)                          -- one row per month
ORDER BY month_number;                               