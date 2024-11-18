/* DATA EXPLORATION ON COVID-19 DEATHS & VACCINATIONS

Summary: A semi-guided data exploration project using MSSQL to demonstrate intermediate to advanced SQL concepts using 
Covid-19 dataset from ourworldindata.org

Objectives:
1. Demonstrate various SQL concepts
	a. Converting data types
	b. Joins
	c. CTEs
	d. Temp Tables
	e. Windows functions
	f. Aggregate functions
	g. Creating views
	h. Subqueries
2. Make inferences from the dataset based on continents and countries
3. Prepare data for visualization on Tableau

[This project is done under the assumption that the data is clean]

*/

---------------------------------------
-- Prelimenary Glance on the dataset -- 
---------------------------------------

-- Overview
SELECT *
FROM Portfolio_Projects..[covid-deaths]
ORDER BY 3, 4

-- Continents
SELECT DISTINCT continent
FROM Portfolio_Projects..[covid-deaths]

-- Countries
SELECT DISTINCT location
FROM Portfolio_Projects..[covid-deaths]
ORDER BY location

-----------------------------------------------
-- Running simple queries to gain inferences --
-----------------------------------------------

-- Select Data to start with
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM Portfolio_Projects..[covid-deaths]
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Total Cases vs Total Deaths [death_percentage]
SELECT location, date, total_cases, new_cases, total_deaths, (total_deaths/ NULLIF(total_cases,0))*100 as death_percentage
FROM Portfolio_Projects..[covid-deaths]
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Likelihood of dying in Malaysia
SELECT location, date, total_cases, new_cases, total_deaths, (total_deaths/ NULLIF(total_cases,0))*100 as death_percentage
FROM Portfolio_Projects..[covid-deaths]
WHERE location like 'Malaysia'
AND (total_deaths/ NULLIF(total_cases,0))*100 IS NOT NULL
AND continent IS NOT NULL
ORDER BY 1, 2

-- Total Cases vs Population [Show percentage of infected population in Malaysia]
SELECT location, date, total_cases, population, (total_cases/population)*100 as infected_percentage
FROM Portfolio_Projects..[covid-deaths]
WHERE location like 'Malaysia'
AND (total_cases/population)*100 IS NOT NULL
AND continent IS NOT NULL
ORDER BY 1, 2

-- Countries with the highest infected population
SELECT location, MAX(total_cases) as highest_infection_count, population, MAX((total_cases/population))*100 as infected_population_percentage
FROM Portfolio_Projects..[covid-deaths]
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY infected_population_percentage desc

-- Countries with the highest death count per population
SELECT location, population, MAX(total_deaths) as highest_death_count
FROM Portfolio_Projects..[covid-deaths]
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY highest_death_count desc

-- Continents with the highest death count per population
SELECT continent, MAX(total_deaths) as highest_death_count
FROM Portfolio_Projects..[covid-deaths]
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY highest_death_count desc

-----------------------
-- Global Statistics --
-----------------------

-- Global total cases over time --
/* [Using Subqueries] */
SELECT date, SUM(total_cases) OVER (ORDER BY date) as total_cases
FROM (
	SELECT date, SUM(new_cases) as total_cases
	FROM Portfolio_Projects..[covid-deaths]
	WHERE continent IS NOT NULL
	GROUP BY date
	) AS aggregate_data
ORDER BY date


/* [Using CTE] */
WITH aggregate_data AS (
	SELECT date, SUM(new_cases) as total_cases
	FROM Portfolio_Projects..[covid-deaths]
	WHERE continent IS NOT NULL
	GROUP BY date
	)

SELECT date, SUM(total_cases) OVER (ORDER BY date) as total_cases
FROM aggregate_data
ORDER BY date


/* [Using Temp Tables] */
CREATE TABLE aggregate_data ( date DATE, total_new_cases INT)

INSERT INTO aggregate_data (date, total_new_cases)
SELECT date, SUM(new_cases) as total_new_cases
FROM Portfolio_Projects..[covid-deaths]
WHERE continent IS NOT NULL
GROUP BY date

SELECT date, SUM(total_new_cases) OVER (ORDER BY date) as total_cases
FROM aggregate_data
ORDER BY date

DROP TABLE aggregate_data


/* From this point onwards, CTE is used in the subsequent calculations/queries */

-- Global infected percentage
WITH aggregate_data AS (
	SELECT date, SUM(new_cases) as total_cases, MAX(population) as population
	FROM Portfolio_Projects..[covid-deaths]
	WHERE continent IS NOT NULL
	GROUP BY date
	)

SELECT date, SUM(total_cases) OVER (ORDER BY date) as cumulative_total_cases, population,
	(SUM(total_cases) OVER (ORDER BY date)/population)*100 as infected_population
FROM aggregate_data
ORDER BY date

-- Global death rate
WITH aggregate_data AS (
	SELECT date, SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths
	FROM Portfolio_Projects..[covid-deaths]
	WHERE continent IS NOT NULL
	GROUP BY date
	)

SELECT date, SUM(total_cases) OVER (ORDER BY date) as cumulative_total_cases, 
	SUM(total_deaths) OVER (ORDER BY date) as cumulative_total_deaths,
	(SUM(total_deaths) OVER (ORDER BY date)/SUM(total_cases) OVER (ORDER BY date))*100 as death_percentage
FROM aggregate_data
ORDER BY date


--------------------------------------------------------------------
-- Using Joins to see correlation between deaths and vaccinations --
--------------------------------------------------------------------

/* Joining dbo.covid-deaths and dbo.covid-vaccinations */
SELECT *
FROM Portfolio_Projects..[covid-deaths] dea
JOIN Portfolio_Projects..[covid-vaccinations] vac
	ON dea.location = vac.location
	AND dea.date = vac.date

-- Total Population vs Vaccination [Observing the growth of percentage of vaccinated people in the population]
WITH vaccinated_population AS (
	SELECT 
		dea.continent, 
		dea.location, 
		dea.date, 
		dea.population, 
		vac.new_vaccinations,
		SUM(CONVERT(BIGINT,vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location) as total_vaccinated
	FROM Portfolio_Projects..[covid-deaths] dea
	JOIN Portfolio_Projects..[covid-vaccinations] vac
		ON dea.location = vac.location
		AND dea.date = vac.date
)

SELECT *, (total_vaccinated/population)*100 as vaccinated_percentage
FROM vaccinated_population
WHERE new_vaccinations IS NOT NULL
AND continent IS NOT NULL
ORDER BY 2, 3


------------------------------------------------------------------------
-- Create a new table for visualization on Tableau with [Create View] --
------------------------------------------------------------------------

CREATE VIEW VaccinatedPopulation AS
	SELECT 
		dea.continent, 
		dea.location, 
		dea.date, 
		dea.population, 
		vac.new_vaccinations,
		SUM(CONVERT(BIGINT,vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location) as total_vaccinated
	FROM Portfolio_Projects..[covid-deaths] dea
	JOIN Portfolio_Projects..[covid-vaccinations] vac
		ON dea.location = vac.location
		AND dea.date = vac.date

/* Unfortunately, due the limitations of Tableau Public, the intention on visualizing the data from this query will not be moved forward. */
