# Operations

## Start and stop

```sql
ALTER TASK MAIL_DB.TRIAGE.SMS_PIPELINE_TASK RESUME;
ALTER TASK MAIL_DB.TRIAGE.SMS_PIPELINE_TASK SUSPEND;
```

## Manual run

```sql
CALL MAIL_DB.TRIAGE.RUN_SMS_PIPELINE('<MAILBOX_UPN>','<DESTINATION_PHONE_E164>',80);
```

## Recent results

```sql
SELECT RECEIVED,SENDER,SUBJECT,SCORE,AI_RESULT:category::STRING CATEGORY,
       AI_RESULT:summary::STRING SUMMARY,SMS_SID,SMS_SUBMITTED_AT
FROM MAIL_DB.TRIAGE.EMAILS ORDER BY RECEIVED DESC LIMIT 50;
```

## Task history

```sql
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME=>'SMS_PIPELINE_TASK',RESULT_LIMIT=>20))
ORDER BY SCHEDULED_TIME DESC;
```

## Troubleshooting

- Graph 401: tenant ID, client ID, or client secret is wrong/expired.
- Graph 403: `Mail.Read` application permission lacks admin consent or mailbox policy blocks the app.
- Twilio 401: Account SID/Auth Token mismatch.
- Twilio 21608/trial restriction: destination is not verified.
- Sender error: number is not SMS-capable or permitted for that destination.
- Snowflake external access error: host or secret is not allowed by `TRIAGE_EAI`.
- Task not running: it is suspended, warehouse is unavailable, or owner lacks privileges.
