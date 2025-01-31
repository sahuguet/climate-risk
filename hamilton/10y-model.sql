
-- random number generator
CREATE OR REPLACE MACRO MOD(a,b) AS ( a % b);
CREATE OR REPLACE MACRO hdr2(counter, varId:=0, entity:=0, seed3:=0, seed4:=0) AS
( MOD(( MOD( MOD( 999999999999989::BIGINT, MOD( counter*2499997::BIGINT + (varId)*1800451::BIGINT + (entity)*2000371::BIGINT + (seed3)*1796777::BIGINT + (seed4)*2299603::BIGINT, 7450589::BIGINT ) * 4658::BIGINT + 7450581::BIGINT ) * 383::BIGINT, 99991::BIGINT ) * 7440893::BIGINT + MOD( MOD( 999999999999989::BIGINT, MOD( counter*2246527::BIGINT + (varId)*2399993::BIGINT + (entity)*2100869::BIGINT + (seed3)*1918303::BIGINT + (seed4)*1624729::BIGINT, 7450987::BIGINT ) * 7580::BIGINT + 7560584::BIGINT ) * 17669::BIGINT, 7440893::BIGINT )) * 1343::BIGINT, 4294967296::BIGINT ) + 0.5 ) / 4294967296::BIGINT;

-- Uniform distribution
CREATE OR REPLACE MACRO UNIFORM(p, min_val, max_val) AS
    CASE
        WHEN p < 0 OR p >1 THEN error('p must be between 0 and 1')
        WHEN min_val > max_val THEN error('max_val must be greater than min_val')
        ELSE min_val + p * (max_val - min_val)
    END;

-- triangular distribution
CREATE OR REPLACE MACRO TRI(p, min_val, max_val, med_val) AS
  CASE
    WHEN p < 0 OR p >1 THEN error('p must be between 0 and 1')
    WHEN min_val > max_val THEN error('max_val must be greater than min_val')
    WHEN (med_val<min_val OR med_val>max_val) THEN error('med_val must be between min_val and max_val')
    ELSE
      CASE
        WHEN p <= (med_val - min_val) / (max_val - min_val) THEN min_val + SQRT(p * (max_val - min_val) * (med_val - min_val))
        ELSE max_val - SQRT((1 - p) * (max_val - min_val) * (max_val - med_val))
      END
    END;

CREATE OR REPLACE MACRO simulated_surplus(trial, year) AS 0.01 * TRI(CAST(HDR2(trial, varId:= 6000+year, entity:=1) AS DOUBLE), 1.2, 7.9, 2.6);

WITH T AS (                       
SELECT trial,
[
    { 'year': 1, 'simulated_surplus': simulated_surplus(trial, 1) },
    { 'year': 2, 'simulated_surplus': simulated_surplus(trial, 2) },
    { 'year': 3, 'simulated_surplus': simulated_surplus(trial, 3) },
    { 'year': 4, 'simulated_surplus': simulated_surplus(trial, 4) },
    { 'year': 5, 'simulated_surplus': simulated_surplus(trial, 5) },
] AS simulated_surplus
FROM (SELECT UNNEST(generate_series(1,10000)) AS trial)
)
SELECT trial, simulated_surplus.year AS year, 'simulated_surplus' AS metric, simulated_surplus.simulated_surplus AS value
FROM (SELECT trial, UNNEST(simulated_surplus) AS simulated_surplus FROM T);

CREATE OR REPLACE MACRO is_used_for_current_services(trial, year) AS UNIFORM(CAST(HDR2(trial, varId:= 6010+year, entity:=1) AS DOUBLE), 0, 1);

WITH T AS (                       
SELECT trial,
[
    { 'year': 1, 'is_used_for_current_services': is_used_for_current_services(trial, 1) },
    { 'year': 2, 'is_used_for_current_services': is_used_for_current_services(trial, 2) },
    { 'year': 3, 'is_used_for_current_services': is_used_for_current_services(trial, 3) },
    { 'year': 4, 'is_used_for_current_services': is_used_for_current_services(trial, 4) },
    { 'year': 5, 'is_used_for_current_services': is_used_for_current_services(trial, 5) },
] AS is_used_for_current_services
FROM (SELECT UNNEST(generate_series(1,10000)) AS trial)
)
SELECT trial, is_used_for_current_services.year AS year, 'is_used_for_current_services' AS metric, is_used_for_current_services.is_used_for_current_services AS value
FROM (SELECT trial, UNNEST(is_used_for_current_services) AS is_used_for_current_services FROM T);

CREATE OR REPLACE MACRO pct_used_for_current_services(trial, year) AS UNIFORM(CAST(HDR2(trial, varId:= 6040+year, entity:=1) AS DOUBLE), 0, 1);

COPY (
WITH T AS (                       
SELECT trial,
[
    { 'year': 1, 'pct_used_for_current_services': pct_used_for_current_services(trial, 1) },
    { 'year': 2, 'pct_used_for_current_services': pct_used_for_current_services(trial, 2) },
    { 'year': 3, 'pct_used_for_current_services': pct_used_for_current_services(trial, 3) },
    { 'year': 4, 'pct_used_for_current_services': pct_used_for_current_services(trial, 4) },
    { 'year': 5, 'pct_used_for_current_services': pct_used_for_current_services(trial, 5) },
] AS pct_used_for_current_services
FROM (SELECT UNNEST(generate_series(1,10000)) AS trial)
)
SELECT CAST(trial AS SMALLINT) AS trial, CAST(pct_used_for_current_services.year AS SMALLINT) AS year, 'pct_used_for_current_services' AS metric, pct_used_for_current_services.pct_used_for_current_services AS value
FROM (SELECT trial, UNNEST(pct_used_for_current_services) AS pct_used_for_current_services FROM T))
TO '10y-model.parquet' (FORMAT PARQUET);

