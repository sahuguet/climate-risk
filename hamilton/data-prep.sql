
--  
-- Utility functions for random number generation
--
CREATE MACRO MOD(a,b) AS ( a % b);
CREATE MACRO hdr2(counter, varId:=0, entity:=0, seed3:=0, seed4:=0) AS
( MOD(( MOD( MOD( 999999999999989::BIGINT, MOD( counter*2499997::BIGINT + (varId)*1800451::BIGINT + (entity)*2000371::BIGINT + (seed3)*1796777::BIGINT + (seed4)*2299603::BIGINT, 7450589::BIGINT ) * 4658::BIGINT + 7450581::BIGINT ) * 383::BIGINT, 99991::BIGINT ) * 7440893::BIGINT + MOD( MOD( 999999999999989::BIGINT, MOD( counter*2246527::BIGINT + (varId)*2399993::BIGINT + (entity)*2100869::BIGINT + (seed3)*1918303::BIGINT + (seed4)*1624729::BIGINT, 7450987::BIGINT ) * 7580::BIGINT + 7560584::BIGINT ) * 17669::BIGINT, 7440893::BIGINT )) * 1343::BIGINT, 4294967296::BIGINT ) + 0.5 ) / 4294967296::BIGINT;

--
-- Specific random gnerator based on HDR2 for permutation of the quake table.
-- 
CREATE MACRO permute_quakes(counter, year) AS hdr2(counter, varId:=year);

-- 
-- We create the quake table:
-- - 1 row per trial
-- - events nested into a list with the following fields:
--   - event_id: the event id
--   - metadata: a json object with the magnitude
--   - economic_loss: the economic loss
--   - insured_loss: the insured loss
--   - pa_loss: the public assistance loss
-- 
-- We complete the table with the missing trials using the `UNION` operator.
-- We generate 10_000 trials using `generate_series(1, 10000` and we remove the trials that are already in the table.
-- The missing trials have an empty list of events.
DROP table if exists table_quakes;
CREATE TABLE table_quakes AS
(
WITH _table_quakes AS (
    SELECT
    trial,
    'quake' AS peril,
    LIST(STRUCT_PACK(
        event_id := event_id,
        metadata := ('{"magnitude":' || CAST(magnitude AS STRING) || '}')::JSON,
        economic_loss := economic_loss,
        insured_loss := insured_loss,
        pa_loss := pa_loss
    )) AS event_summary
FROM 'quakes.csv'
GROUP BY trial)
(SELECT * FROM _table_quakes)
UNION
(SELECT trial, 'quake' AS peril, []::struct(event_id bigint, metadata json, economic_loss double, insured_loss double, pa_loss double)[] AS event_summary
FROM (SELECT UNNEST(generate_series(1, 10000)) AS trial) WHERE trial NOT IN (SELECT trial from _table_quakes))
ORDER BY trial ASC
);

--
-- Macro to shuffle the quake table for a given year, using HDR2 as a random number generator.
-- The inner query does the shuffle, the outer query adds the trial id (1..10_000) and the year.
--
CREATE MACRO shuffle_table_quakes_for_year(year) AS TABLE
SELECT (row_number() OVER ()) AS trial, year AS year, peril, event_summary
FROM (SELECT peril, event_summary from table_quakes ORDER BY permute_quakes(trial, year));

--
-- We create the table for the 10 years of the simulation.
-- Year 1 is the original table;
-- the other years are shuffled versions of the original table using year = 2..10 as the seed for the random number generator.
-- 
-- The schema of the table is:
-- * trial id
-- * year (1..10)
-- * peril, e.g. "earthquake", "flood"
-- * event_summary,  a list of {event_id bigint, metadata json, economic_loss double, insured_loss double, pa_loss double}
--
DROP TABLE IF EXISTS table_quakes_10Y;
CREATE TABLE table_quakes_10Y AS
(
SELECT trial, 1 AS year, peril, event_summary FROM table_quakes
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(2)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(3)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(4)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(5)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(6)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(7)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(8)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(9)
UNION
SELECT trial, year, peril, event_summary FROM shuffle_table_quakes_for_year(10)
) ORDER BY trial ASC, year ASC;


--
-- We save the table as CSV.
-- Note that `event_summary` is serialized as a string.
--
COPY table_quakes_10Y TO 'table_quakes_10Y.csv';

--
-- We (re)load the table.
-- We need to tell DuckDB how to reconstruct the `event_summary` field.
--
SELECT * FROM read_csv('table_quakes_10Y.csv', columns = { 'trial': 'BIGINT', 'year': 'BIGINT', 'peril': 'STRING', 'event_summary': 'struct(event_id bigint, metadata json, economic_loss double, insured_loss double, pa_loss double)[]'});