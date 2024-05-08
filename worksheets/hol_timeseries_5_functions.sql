/*
SNOWFLAKE FUNCTIONS SCRIPT
*/

-- Set role, context, and warehouse
USE ROLE ROLE_HOL_TIMESERIES;
USE HOL_TIMESERIES.ANALYTICS;
USE WAREHOUSE HOL_ANALYTICS_WH;

-- Create Interpolate Table Function
CREATE OR REPLACE FUNCTION HOL_TIMESERIES.ANALYTICS.FUNCTION_TS_INTERPOLATE (
    V_TAGLIST VARCHAR,
    V_START_TIMESTAMP TIMESTAMP_NTZ,
    V_INTERVAL NUMBER,
    V_BUCKETS NUMBER
)
RETURNS TABLE (
    TIMESTAMP TIMESTAMP_NTZ,
    TAGNAME VARCHAR,
    INTERP_VALUE FLOAT,
    LOCF_VALUE FLOAT,
    LAST_TIMESTAMP TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
WITH
TSTAMPS AS (
    SELECT 
        DATEADD('SEC', V_INTERVAL * ROW_NUMBER() OVER (ORDER BY SEQ8()) - V_INTERVAL, V_START_TIMESTAMP) AS TIMESTAMP
    FROM TABLE(GENERATOR(ROWCOUNT => V_BUCKETS))
),
TAGLIST AS (
    SELECT
        TRIM(TAGLIST.VALUE) AS TAGNAME
    FROM
        TABLE(SPLIT_TO_TABLE(V_TAGLIST, ',')) TAGLIST
),
TIMES AS (
    SELECT
        TSTAMPS.TIMESTAMP,
        TAGLIST.TAGNAME
    FROM
        TSTAMPS
        CROSS JOIN TAGLIST
),
LAST_VALUE AS (
    SELECT
        TIMES.TIMESTAMP,
        RAW_DATA.TIMESTAMP RAW_TS,
        RAW_DATA.TAGNAME,
        RAW_DATA.VALUE_NUMERIC
    FROM
        TIMES ASOF JOIN HOL_TIMESERIES.ANALYTICS.TS_TAG_READINGS RAW_DATA
            MATCH_CONDITION(TIMES.TIMESTAMP >= RAW_DATA.TIMESTAMP)
            ON TIMES.TAGNAME = RAW_DATA.TAGNAME
),
NEXT_VALUE AS (
    SELECT
        TIMES.TIMESTAMP,
        RAW_DATA.TIMESTAMP RAW_TS,
        RAW_DATA.TAGNAME,
        RAW_DATA.VALUE_NUMERIC
    FROM
        TIMES ASOF JOIN HOL_TIMESERIES.ANALYTICS.TS_TAG_READINGS RAW_DATA
            MATCH_CONDITION(TIMES.TIMESTAMP < RAW_DATA.TIMESTAMP)
            ON TIMES.TAGNAME = RAW_DATA.TAGNAME
),
COMB_VALUES AS (
    SELECT
        TIMES.TIMESTAMP,
        TIMES.TAGNAME,
        LV.VALUE_NUMERIC LAST_VAL,
        LV.TIMESTAMP LV_TS,
        LV.RAW_TS LV_RAW_TS,
        NV.VALUE_NUMERIC NEXT_VAL,
        NV.TIMESTAMP NV_TS,
        NV.RAW_TS NV_RAW_TS
    FROM TIMES
    INNER JOIN LAST_VALUE LV ON TIMES.TIMESTAMP = LV.TIMESTAMP AND TIMES.TAGNAME = LV.TAGNAME
    INNER JOIN NEXT_VALUE NV ON TIMES.TIMESTAMP = NV.TIMESTAMP AND TIMES.TAGNAME = NV.TAGNAME
),
INTERP AS (
    SELECT
        TIMESTAMP,
        TAGNAME,
        TIMESTAMPDIFF(SECOND, LV_RAW_TS, NV_RAW_TS) TDIF_BASE,
        TIMESTAMPDIFF(SECOND, LV_RAW_TS, TIMESTAMP) TDIF,
        LV_TS,
        NV_TS,
        LV_RAW_TS,
        LAST_VAL,
        NEXT_VAL,
        DECODE(TDIF, 0, LAST_VAL, LAST_VAL + (NEXT_VAL - LAST_VAL) / TDIF_BASE * TDIF) IVAL
    FROM
        COMB_VALUES
)
SELECT
    TIMESTAMP,
    TAGNAME,
    IVAL INTERP_VALUE,
    LAST_VAL LOCF_VALUE,
    LV_RAW_TS LAST_TIMESTAMP
FROM
    INTERP
$$
;


-- Add helper precedure to accept start and end times, and return either LOCF or Linear Interpolated Values
CREATE OR REPLACE PROCEDURE HOL_TIMESERIES.ANALYTICS.PROCEDURE_TS_INTERPOLATE_LIN (
    V_TAGLIST VARCHAR,
    V_FROM_TIME TIMESTAMP_NTZ,
    V_TO_TIME TIMESTAMP_NTZ,
    V_INTERVAL NUMBER,
    V_INTERP_TYPE VARCHAR
)
RETURNS TABLE (
    TIMESTAMP TIMESTAMP_NTZ,
    TAGNAME VARCHAR,
    VALUE FLOAT
)
LANGUAGE SQL
AS
$$
DECLARE
TIME_BUCKETS NUMBER;
RES RESULTSET;
BEGIN
    TIME_BUCKETS := (TIMESTAMPDIFF('SEC', :V_FROM_TIME, :V_TO_TIME) / :V_INTERVAL);

    IF (:V_INTERP_TYPE = 'LOCF') THEN
        RES := (SELECT TIMESTAMP, TAGNAME, LOCF_VALUE AS VALUE FROM TABLE(HOL_TIMESERIES.ANALYTICS.FUNCTION_TS_INTERPOLATE(:V_TAGLIST, :V_FROM_TIME, :V_INTERVAL, :TIME_BUCKETS)) ORDER BY TAGNAME, TIMESTAMP);
    ELSE
        RES := (SELECT TIMESTAMP, TAGNAME, INTERP_VALUE AS VALUE FROM TABLE(HOL_TIMESERIES.ANALYTICS.FUNCTION_TS_INTERPOLATE(:V_TAGLIST, :V_FROM_TIME, :V_INTERVAL, :TIME_BUCKETS)) ORDER BY TAGNAME, TIMESTAMP);
    END IF;

    RETURN TABLE(RES);
END;
$$
;

-- LTTB Downsampling Table Function
CREATE OR REPLACE FUNCTION HOL_TIMESERIES.ANALYTICS.FUNCTION_TS_LTTB (
    TIMESTAMP NUMBER,
    VALUE FLOAT,
    SIZE NUMBER
) 
RETURNS TABLE (
    TIMESTAMP NUMBER,
    VALUE FLOAT
)
LANGUAGE PYTHON
RUNTIME_VERSION = 3.11
PACKAGES = ('pandas', 'plotly-resampler')
HANDLER = 'lttb_run'
AS $$
from _snowflake import vectorized
import pandas as pd
from plotly_resampler.aggregation.algorithms.lttb_py import LTTB_core_py

class lttb_run:
    @vectorized(input=pd.DataFrame)

    def end_partition(self, df):
        if df.SIZE.iat[0] >= len(df.index):
            return df[['TIMESTAMP','VALUE']]
        else:
            idx = LTTB_core_py.downsample(
                df.TIMESTAMP.to_numpy(),
                df.VALUE.to_numpy(),
                n_out=df.SIZE.iat[0]
            )
            return df[['TIMESTAMP','VALUE']].iloc[idx]
$$;

/*
FUNCTIONS SCRIPT COMPLETED
*/