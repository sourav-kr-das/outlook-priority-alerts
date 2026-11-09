# START HERE

Run the project in this exact order for the first setup.

1. `01_setup/01_setup_snowflake.sql`
2. `01_setup/02_create_tables.sql`
3. `02_graph_ingestion/01_graph_email_ingestion.sql`
4. `03_ai_prioritization/01_cortex_ai_scoring.sql`
5. `04_twilio_notification/01_twilio_sms.sql`
6. `04_twilio_notification/02_notification_pipeline.sql`
7. `05_automation/01_create_15_minute_task.sql`
8. `06_testing/01_smoke_tests.sql`
9. When every test succeeds, run:
   `ALTER TASK MAIL_DB.TRIAGE.SMS_PIPELINE_TASK RESUME;`

After step 9, Snowflake runs the pipeline automatically every 15 minutes.

Credential instructions: `docs/CREDENTIALS.md`
Troubleshooting: `docs/OPERATIONS.md`
Cleanup: `cleanup/cleanup_objects.sql`

Never commit real secrets to GitHub.
