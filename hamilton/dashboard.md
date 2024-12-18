

## Generating the budget surplus

For each year, we use a triangular distribution with min, max and mode defined in the top-level model.

The 10y is generated as follows:
* trialId
* min=-__, max=__, mode=__ from the key assumptions.
* varId = 6000 + year
* entity = 1


We define a new macro to compute the surplus.
```
CREATE OR REPLACE MACRO surplus(trial, year, min_val, max_val, med_val) AS
    TRI(CAST(HDR2(trial, varId:= 6000+year, entity:=1) AS DOUBLE), min_val, max_val, med_val);
```

We can now generate for each trial the 10y surplus projection as follows (trial 1..16 in this examaple):
```
SELECT trial,
list_transform(
[
    { 'year': 1, 'min': -1.9, 'max': 7.9, 'med': 1.2 },
    { 'year': 2, 'min': -1.5, 'max': 6, 'med': 1.2 },
], x -> { 'year': x.year, 'surplus': surplus(trial, x.year, x.min, x.max, x.med)} )
AS surplus
FROM (SELECT UNNEST(generate_series(1,16)) AS trial);
```

We then need to unnest all of this into the schema we use across all our simulations (assuming T is the table we just computed)
```
SELECT trial, surplus.year AS year, 'surplus' AS metric, surplus.surplus AS value FROM (SELECT trial, UNNEST(surplus) AS surplus FROM T);
```


## Computing the BOY and EOY reserves
This computation is a bit trickier because we need to propagate computation from year N to year N+1. 

We start from the initial reserve (input from the user).
We 


-- We insert the start-of-year (SOY) reserve for year 1

INSERT INTO SURPLUS_BY_Y
SELECT trial, year, 'SOY Reserve' AS metric, 53.8 AS value FROM SURPLUS_BY_Y WHERE year = 1;

-- We insert the start-of-year (SOY) reserve for year 2
INSERT INTO SURPLUS_BY_Y
SELECT DISTINCT S.trial, S.year+1 AS year, 'SOY Reserve' AS metric, (SELECT SUM(value) FROM SURPLUS_BY_Y WHERE trial = S.trial AND year = S.year AND metric IN ('surplus', 'SOY Reserve') LIMIT 1) AS value
FROM SURPLUS_BY_Y AS S WHERE year = 1
ORDER BY trial, year, metric

-- We insert the start-of-year (SOY) reserve for year 3
INSERT INTO SURPLUS_BY_Y
SELECT DISTINCT S.trial, S.year+1 AS year, 'SOY Reserve' AS metric, (SELECT SUM(value) FROM SURPLUS_BY_Y WHERE trial = S.trial AND year = S.year AND metric IN ('surplus', 'SOY Reserve') LIMIT 1) AS value
FROM SURPLUS_BY_Y AS S WHERE year = 2
ORDER BY trial, year, metric


## Simulating recession

Recessions are simulated along the following dimensions:
- property tax
- sales tax
- etc.
as a percentage decline for each year. We then translate into $$ by looking at the percent of the budget each tax represents.

For each dimension, we use a Metalog SPT distribution with n=3, for which we need to provide 4 variables:
- α, that indicates the percentile we use (here, α = 0.1)
- q_α, the value for the α percentile
- q_1_α, the value of the 1-α percentile
- q_0.5, the value of the median

The random generation uses `counter = trial id` (aka `PM_index` in the sheet) and `varId = 2100 + year`.

For each year, the customer provides `low`, `median` and `high` decline value (signed %).

Here is a SQL query to generate the property tax 10y simulations (we only generate 16 trials)

```
SELECT trial, UNNEST(property_tax_decline)
FROM
(SELECT trial,
list_transform(
[
    { 'year': 1, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 2, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 3, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 4, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 5, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 6, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 7, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 8, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 9, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
    { 'year': 10, 'low': -11.2/100, 'median': -6.44/100, 'high': -1.68/100 },
], x -> { 'year': x.year, 'property_tax': Metalog_SPT_Quantile_3_(0.1, x.low, x.median, x.high, hdr2(trial, varId:=2100 + x.year ))} )
AS property_tax_decline
FROM (SELECT UNNEST(generate_series(1,16)) AS trial))
WHERE trial=5;
```