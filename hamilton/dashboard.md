

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
