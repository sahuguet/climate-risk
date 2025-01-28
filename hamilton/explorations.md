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
