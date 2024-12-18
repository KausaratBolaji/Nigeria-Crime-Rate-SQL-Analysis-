CREATE TABLE police_case LIKE `nigeria-crime-rate-dataset`;
SELECT *  FROM `nigeria-crime-rate-dataset`;


INSERT INTO police_case
SELECT * FROM `nigeria-crime-rate-dataset`;

-- Removes decimal from Suspect Age 
SELECT CASE
WHEN Suspect_Age <> '' THEN FLOOR(TRIM(Suspect_Age))
ELSE Suspect_Age
END AS Suspect_Age_Rounded
FROM police_case;

SET SQL_SAFE_UPDATES = 0;
UPDATE police_case
SET Suspect_Age = FLOOR(TRIM(Suspect_Age))
WHERE Suspect_Age <> '';

-- Fills empty spaces with random numbers 
SET SQL_SAFE_UPDATES= 0;
UPDATE police_case
SET Suspect_Age =FLOOR(18 + (RAND() * (80-18)))
WHERE Suspect_Age = '' ;

-- change blank spaces of Suspect_Gender to 'Others'
SET SQL_SAFE_UPDATES = 0;
UPDATE police_case
SET Suspect_Gender = 'Others'
WHERE Suspect_Gender = '';

-- 1.The average response time by crime type, and how does it compare across states


SELECT State, Crime_Type,ROUND(AVG(Response_Time)) AS AverageResponseTime
FROM police_case
GROUP BY State,Crime_Type
ORDER BY State, Crime_Type;

-- 2.Which cities have the highest rates of specific crime and how do they rank within each states
WITH CityCrimeCounts AS (SELECT State,City,Crime_Type, COUNT(*) AS NumIncidents
FROM police_case
GROUP BY City, State, Crime_Type
)
SELECT State, City, Crime_Type, NumIncidents, 
RANK() OVER(PARTITION BY State,Crime_Type ORDER BY Numincidents DESC) AS Ranks
FROM
CityCrimeCounts
ORDER BY  Ranks;

-- 3. what is the trend of crime severity over time, especially in major cities 

SELECT City,
count(*) AS CityCounts
FROM police_case
GROUP BY City
ORDER BY CityCounts DESC
Limit 5;

SELECT EXTRACT(Year FROM Date_Reported)AS Year, City, ROUND(AVG(Severity),1)AS AverageSeverity
FROM police_case
WHERE City IN ('Ungogo', 'Asaba','Port harcourt','Abeokuta','Nsukka')-- major_cities
GROUP BY EXTRACT(Year FROM Date_Reported),City;


-- 4. Identify the Top 5 states with the highest percentage of unsolved cases 
SELECT State,count(*)*100/(select count(*) from police_case) as Percentage_of_unsolved FROM police_case
 where Outcome IN ('Open','In Court') 
GROUP BY State
ORDER BY Percentage_of_unsolved DESC
limit 5;

-- 5.What is the monthly trend in the number of arrests by crime type
SELECT month(Date_Reported) as MonthNumber, monthname(Date_Reported)  AS Month,
Crime_Type, COUNT(*) AS NumArrests
FROM police_case
GROUP BY Crime_Type, MonthNumber,Month
ORDER BY NumArrests,MonthNumber;

-- 6. Which officer have handled the most severe cases, and what is the average severity rating they deal with
SELECT Officer_ID, ROUND(AVG(Severity)) AS AvgSeverity, COUNT(CRIME_ID) AS Numseverecases
FROM police_case
WHERE Severity = 5
GROUP BY Officer_ID
ORDER BY NumSevereCases DESC, AvgSeverity DESC
limit 5;

-- 7.Calculate the average age difference between victims and suspects by Crime type and City
SELECT Crime_Type, City,
ROUND(AVG( CASE WHEN Suspect_Age > Victim_Age THEN Suspect_Age - Victim_Age ELSE Victim_Age - Suspect_Age END))
AS AvgAgeDifference 
FROM police_case
GROUP BY Crime_Type, City
ORDER BY Crime_Type, City;


-- 8.What percentage of crimes are reported by citizens versus authorities and does it vary by regions
SELECT City ,count(Reported_By)*100 /(select COUNT(*) from police_case) AS P_CITIZEN,
ROUND(SUM(CASE WHEN Reported_By = 'Police' THEN 1 ELSE 0 END ),0)*100/(select COUNT(*) from police_case) as p_AuthorityReports
FROM police_case
GROUP BY City
ORDER BY City;



-- 9. Find the top 3 cities with the highest response times and analyze the average severity of cases in these cities
SELECT City,MAX(Response_Time) AS MaxResponseTime,
ROUND(AVG(Severity), 2) AS AvgSeverity
FROM police_case
GROUP BY CITY
ORDER BY MaxResponseTime DESC
LIMIT 3;

-- 10. What is the average case resolution time by crime type, and how does it vary between states
SELECT Crime_Type, State, ROUND(AVG( DATEDIFF(CURDATE(),Date_Reported)/365),2) AS AvgResolutionTime
FROM police_case
WHERE Outcome = 'Closed'
GROUP BY Crime_Type, State
ORDER BY AvgResolutionTime;



-- 11.Identify the state and city combinations with the highest rate of violent cases
SELECT State, City, COUNT(Crime_Type) AS ViolentCrimeCount
FROM police_case
WHERE Crime_Type IN ('Homicide','Assault','Robbery')
GROUP BY State, City
ORDER BY ViolentCrimeCount DESC
LIMIT 10;

-- 12. What is the distribution of crime type among different age groups of victims.
SELECT MIN(Victim_Age) AS MinAge,
Max(Victim_Age) AS MaxAge
FROM police_case;

ALTER TABLE police_case
ADD AgeGroup VARCHAR(50);

SET SQL_SAFE_UPDATES= 0;
UPDATE police_case
SET AgeGroup = CASE
WHEN Victim_Age < 18 THEN 'Under 18'
WHEN  Victim_Age >= 18 AND Victim_Age < 25 THEN '18-25'
WHEN Victim_Age >= 25 AND Victim_Age < 35 THEN '25-34'
WHEN Victim_Age >= 35 AND Victim_Age < 45 THEN '35-44'
WHEN Victim_Age >= 45 AND Victim_Age < 55 THEN '45-54'
WHEN Victim_Age >= 55 AND Victim_Age  < 65 THEN '55-64'
WHEN Victim_Age >= 65 AND Victim_Age < 65 THEN  '55-64'
WHEN Victim_Age >= 65 THEN '65 and Over'
END;

SELECT AgeGroup, Crime_Type, COUNT(*) AS Count From police_case
GROUP BY AgeGroup, Crime_Type
Order BY AgeGroup, COUNT DESC;

-- 13. Identify the top 5 officers based on case closure rates and thier average response times
with cte as (SELECT Outcome, Officer_ID,count(Outcome)as closure_rate,
 (select count(Outcome) from police_case) as Total_outcome,round(avg(Response_Time)) as Avg_Response_time  FROM police_case
where Outcome = "closed"
GROUP BY Officer_ID
order by closure_rate desc)
select Officer_ID,closure_rate, Avg_Response_time from cte
group by Officer_ID
order by closure_rate desc
limit 5;

-- 14. Calculate the monthly increase or decrease in crime rates per state and rank
WITH MonthlyCrimeRates AS (SELECT State, Extract(Month FROM Date_Reported) AS Month,
count(*) AS TotalCrimes
FROM police_case
GROUP BY State, Extract(Month FROM Date_Reported)),
MonthlyChanges AS (SELECT State, Month,TotalCrimes,(TotalCrimes-LAG(TotalCrimes,1,0)
OVER (PARTITION BY STATE ORDER BY Month))/ LAG(TotalCrimes,1,0)
OVER(PARTITION BY STATE ORDER BY Month)*100 AS MonthlyChange
FROM MonthlyCrimeRates)
SELECT State,Month,TotalCrimes,MonthlyChange,
RANK()OVER(ORDER BY ABS(MonthlyChange)DESC) AS Ranks
FROM MonthlyChanges
WHERE MonthlyChange IS NOT NULL
ORDER BY ranks;

-- 15.Find the average severity of crimes over time for each state and determine if there is significant upward or downward trends

SELECT State,
Extract(YEAR FROM Date_Reported) AS Year, ROUND(AVG(Severity),2)AS AverageSeverity FROM police_case
GROUP BY State, Extract(YEAR FROM Date_Reported)
ORDER BY State, Year;

















