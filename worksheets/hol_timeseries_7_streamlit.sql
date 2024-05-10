/*
SNOWFLAKE STREAMLIT SCRIPT
*/

-- Set role, context, and warehouse
USE ROLE ROLE_HOL_TIMESERIES;
USE HOL_TIMESERIES.ANALYTICS;
USE WAREHOUSE HOL_ANALYTICS_WH;

-- CREATE STAGE FOR STREAMLIT FILES
CREATE OR REPLACE STAGE HOL_TIMESERIES.ANALYTICS.STAGE_TS_STREAMLIT
DIRECTORY = (ENABLE = TRUE, REFRESH_ON_CREATE = TRUE)
ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

/* EXTERNAL ACTIVITY

Use Snowflake CLI to upload Streamlit app

*/

/*
STREAMLIT SCRIPT COMPLETED
*/