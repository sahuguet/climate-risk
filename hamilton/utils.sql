

-- random number generator
CREATE OR REPLACE MACRO MOD(a,b) AS ( a % b);
CREATE OR REPLACE MACRO hdr2(counter, varId:=0, entity:=0, seed3:=0, seed4:=0) AS
( MOD(( MOD( MOD( 999999999999989::BIGINT, MOD( counter*2499997::BIGINT + (varId)*1800451::BIGINT + (entity)*2000371::BIGINT + (seed3)*1796777::BIGINT + (seed4)*2299603::BIGINT, 7450589::BIGINT ) * 4658::BIGINT + 7450581::BIGINT ) * 383::BIGINT, 99991::BIGINT ) * 7440893::BIGINT + MOD( MOD( 999999999999989::BIGINT, MOD( counter*2246527::BIGINT + (varId)*2399993::BIGINT + (entity)*2100869::BIGINT + (seed3)*1918303::BIGINT + (seed4)*1624729::BIGINT, 7450987::BIGINT ) * 7580::BIGINT + 7560584::BIGINT ) * 17669::BIGINT, 7440893::BIGINT )) * 1343::BIGINT, 4294967296::BIGINT ) + 0.5 ) / 4294967296::BIGINT;


-- triangular distribution
CREATE OR REPLACE MACRO TRI(p, a, b, c) AS
  CASE
    WHEN p < 0 OR p >1 THEN error('p must be between 0 and 1')
    WHEN a > b THEN error('b must be greater than a')
    WHEN (c<a OR c>b) THEN error('c must be between a and b')
    ELSE
      CASE
        WHEN p <= ((c - a) / (b - a)) THEN a + SQRT(p * (b - a) * (c - a))
        ELSE b - SQRT((1 - p) * (b - a) * (b - c))
      END
    END


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
    END

-- Metalog SPT

CREATE OR REPLACE MACRO Metalog_SPT_Quantile_3(a1, a2, a3, y) AS
    CASE
        WHEN y = 0 THEN -1 * CAST('Infinity' AS DOUBLE)
        WHEN y = 1 THEN      CAST('Infinity' AS DOUBLE)
        ELSE a1 + a2 * LN(y/(1-y)) + a3 * (y-0.5) * LN(y/(1-y))
    END

CREATE OR REPLACE MACRO Metalog_SPT_constants(α, q_α, q_05, q_1_α) AS 
    {'a1': q_05,                                                               
    'a2': 0.5 * LN((1-α)/α) ^  (-1) * (q_1_α - q_α),            
    'a3': ( 1 - 2 * α) * LN((1-α)/α) ^ (-1) * (1 - 2 * (q_05 - q_α) / (q_1_α - q_α)) * (q_1_α - q_α)
    }

CREATE OR REPLACE MACRO Metalog_SPT_Quantile_3_(α, q_α, q_05, q_1_α, y) AS
    Metalog_SPT_Quantile_3(Metalog_SPT_constants(α, q_α, q_05, q_1_α)['a1'], Metalog_SPT_constants(α, q_α, q_05, q_1_α)['a2'], Metalog_SPT_constants(α, q_α, q_05, q_1_α)['a3'], y)

-- Testing
SELECT Metalog_SPT_Quantile_3_(0.1, -11.20/100, -6.44/100, -1.68/100, 0.932333959499374);