# Using Mustache

== Context ==
{"5y": [1,2,3,4,5]}

== Template == 
SELECT trial,
[
{{#5y}}
{ 'year': {{.}}, 'pct_used_for_current_services': pct_used_for_current_services(trial, {{.}}) },
{{/5y}}
] AS pct_used_for_current_services
FROM SELECT UNNEST(generate_series(1,10000)) AS trial)



We group the data into a format that is friendly to the spreadsheet.

```
SELECT trial, LIST(STRUCT_PACK("year":= year, "value":= value)) from (SELECT * FROM '10y-model.parquet' WHERE trial=1 ORDER BY year ASC) GROUP BY trial;
```
If we force the ordering, we can get rid of the year and rewrite the query as

SELECT trial, metric, LIST(value) AS "10y" from (SELECT * FROM '10y-model.parquet' WHERE trial=1 ORDER BY year ASC) GROUP BY trial, metric;



