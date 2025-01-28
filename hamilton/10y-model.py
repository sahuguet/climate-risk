import yaml
import logging

logging.basicConfig(level=logging.INFO)

MAX_TRIALS = 10_000

PREAMBLE = """
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
"""

SQL = []
SQL.append(PREAMBLE)

config = yaml.load(open("10y-model.yaml"), Loader=yaml.FullLoader)
      
for section in config:
    logging.info(f"Processing section: {section}.")
    if config[section] is None:
        logging.info(f"No simulations for section: {section}.")
        continue
    for k, sim in config[section].items():
        logging.info(f"Generating data for simulation: {k}.")

        if sim['type'].startswith('uniform'):
            (min_val, max_val) = sim['type'].split(' ')[1:]
            scale = sim.get('scale', 1.0)
            sid = sim.get('seed')
            fn_name = k.replace("-", "_")
            SQL.append(f"CREATE OR REPLACE MACRO {fn_name}(trial, year) AS UNIFORM(CAST(HDR2(trial, varId:= {sid}+year, entity:=1) AS DOUBLE), {min_val}, {max_val});")

        if sim['type'].startswith('triangular'):
            (min_val, med_val, max_val) = sim['type'].split(' ')[1:]
            scale = sim.get('scale', 1.0)
            sid = sim.get('seed')
            fn_name = k.replace("-", "_")
            SQL.append(f"CREATE OR REPLACE MACRO {fn_name}(trial, year) AS {scale} * TRI(CAST(HDR2(trial, varId:= {sid}+year, entity:=1) AS DOUBLE), {min_val}, {max_val}, {med_val});")

        field_name = k.replace("-", "_")
        SQL.append(f"""
WITH T AS (                       
SELECT trial,
[
    {{ 'year': 1, '{field_name}': {fn_name}(trial, 1) }},
    {{ 'year': 2, '{field_name}': {fn_name}(trial, 2) }},
    {{ 'year': 3, '{field_name}': {fn_name}(trial, 3) }},
    {{ 'year': 4, '{field_name}': {fn_name}(trial, 4) }},
    {{ 'year': 5, '{field_name}': {fn_name}(trial, 5) }},
] AS {field_name}
FROM (SELECT UNNEST(generate_series(1,{MAX_TRIALS})) AS trial)
)
SELECT trial, {field_name}.year AS year, '{field_name}' AS metric, {field_name}.{field_name} AS value
FROM (SELECT trial, UNNEST({field_name}) AS {field_name} FROM T);
""")
        logging.info(f"Generated data for simulation: {k}.")


print("\n".join(SQL))
