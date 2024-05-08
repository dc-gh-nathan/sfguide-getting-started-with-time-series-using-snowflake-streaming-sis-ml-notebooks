/*
SNOWFLAKE FUNCTION QUERIES SCRIPT
*/

-- Directly Call Table Function
SELECT * FROM TABLE(HOL_TIMESERIES.ANALYTICS.FUNCTION_TS_INTERPOLATE('/IOT/SENSOR/TAG401', '2024-01-01 01:05:23'::TIMESTAMP_NTZ, 5, 100)) ORDER BY TAGNAME, TIMESTAMP;

-- Call Interpolate Procedure with Taglist, Start Time, End Time, and Intervals - LOCF Interpolate
CALL HOL_TIMESERIES.ANALYTICS.PROCEDURE_TS_INTERPOLATE_LIN(
    -- V_TAGLIST
    '/IOT/SENSOR/TAG401',
    -- V_FROM_TIME
    '2024-01-01 01:05:00',
    -- V_TO_TIME
    '2024-01-01 03:05:00',
    -- V_INTERVAL
    10,
    -- V_INTERP_TYPE
    'LOCF'
);

-- Call Interpolate Procedure with Taglist, Start Time, End Time, and Intervals - LINEAR Interpolate
CALL HOL_TIMESERIES.ANALYTICS.PROCEDURE_TS_INTERPOLATE_LIN(
    -- V_TAGLIST
    '/IOT/SENSOR/TAG401',
    -- V_FROM_TIME
    '2024-01-01 01:05:00',
    -- V_TO_TIME
    '2024-01-01 03:05:00',
    -- V_INTERVAL
    10,
    -- V_INTERP_TYPE
    'INTERP'
);

-- LTTB - RAW
SELECT data.tagname, lttb.timestamp::varchar::timestamp_ntz AS timestamp, lttb.value 
FROM (
SELECT TAGNAME, TIMESTAMP, VALUE_NUMERIC as VALUE
FROM HOL_TIMESERIES.ANALYTICS.TS_TAG_READINGS
WHERE TIMESTAMP > '2024-01-01 00:00:00'
AND TIMESTAMP <= '2024-02-01 00:00:30'
AND TAGNAME = '/IOT/SENSOR/TAG301'
) AS data 
CROSS JOIN TABLE(HOL_TIMESERIES.ANALYTICS.function_ts_lttb(date_part(epoch_nanosecond, data.timestamp), data.value, 500) OVER (PARTITION BY data.tagname ORDER BY data.timestamp)) AS lttb
ORDER BY tagname, timestamp
;

/*
FUNCTION QUERIES SCRIPT COMPLETED
*/