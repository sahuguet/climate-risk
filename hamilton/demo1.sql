.read rr_lib.sql

-- function for surplus
CREATE OR REPLACE MACRO simulated_surplus(trial, year) AS 0.01 * TRI(CAST(HDR2(trial, varId:= 6000+year, entity:=1) AS DOUBLE), 1.2, 7.9, 2.6);

-- function for wild fire
CREATE OR REPLACE MACRO simulated_wild_fire(trial, year) AS TRI(CAST(HDR2(trial, varId:= 7000+year, entity:=1) AS DOUBLE), 0, 25000, 2500);



CREATE OR REPLACE TABLE simulation (
    trial SMALLINT,
    year SMALLINT,
    metric STRING,
    value DOUBLE
);


CREATE OR REPLACE TABLE trials AS SELECT UNNEST(generate_series(1,1000)::SMALLINT[]) AS trial;


-- Set average budget to 50M (50_000K).

INSERT INTO simulation 
SELECT trial, surplus.year AS year, 'surplus' AS metric, ROUND(150_000 * surplus.surplus, 3) AS value
FROM
(
SELECT trial,
       UNNEST(list_transform([1,2,3,4,5,6,7,8,9,10], x -> { 'year': x, 'surplus': simulated_surplus(trial, x) })) AS surplus
FROM trials
);


INSERT INTO simulation 
SELECT trial, wildfire.year AS year, 'wildfire' AS metric, ROUND(wildfire.wildfire, 3) AS value
FROM
(
SELECT trial,
       UNNEST(list_transform([1,2,3,4,5,6,7,8,9,10], x -> { 'year': x, 'wildfire': simulated_wild_fire(trial, x) })) AS wildfire
FROM trials
);

-- We insert the initial reserve, e.g. 22M for the first year.

INSERT INTO simulation 
SELECT trial, 1 as year, 'reserve_SOY' AS metric, 22_000 AS value FROM trials;

-- We calculate the reserve at the end of the year; for the real thing, the formula will be more complex.
INSERT INTO simulation
WITH T AS (PIVOT simulation ON metric USING SUM(value))
SELECT trial, 1 as year, 'reserve_EOY' AS metric, (reserve_SOY + surplus - wildfire) AS value FROM T WHERE year = 1;

-- We move the EOY reserve for year 1 to SOY reserve for year 2.
INSERT INTO simulation
SELECT trial, 2 as year, 'reserve_SOY' AS metric, (SELECT value from simulation S WHERE S.trial = T.trial and year = 1 and metric = 'reserve_EOY')
FROM trials T;

-- We need to repeat for all years.