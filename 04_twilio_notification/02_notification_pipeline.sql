USE SCHEMA MAIL_DB.TRIAGE;
CREATE OR REPLACE PROCEDURE NOTIFY_PRIORITY_SMS(MAILBOX STRING,PHONE STRING,MIN_SCORE INTEGER) RETURNS STRING
LANGUAGE PYTHON RUNTIME_VERSION='3.11' PACKAGES=('snowflake-snowpark-python') HANDLER='run' EXECUTE AS CALLER AS $$
def run(session,mailbox,phone,min_score):
 mailbox=(mailbox or '').strip().lower()
 if not mailbox:raise ValueError('MAILBOX is required')
 if min_score is None or not 0<=min_score<=100:raise ValueError('MIN_SCORE must be 0-100')
 rows=session.sql('SELECT ID,MAILBOX,SCORE FROM MAIL_DB.TRIAGE.EMAILS WHERE LOWER(MAILBOX)=? AND SCORE>=? AND AI_RESULT IS NOT NULL AND SMS_SID IS NULL ORDER BY SCORE DESC,RECEIVED DESC',params=[mailbox,min_score]).collect()
 if not rows:return 'No pending emails meet threshold.'
 highest=max(int(x['SCORE']) for x in rows);sid=session.call('MAIL_DB.TRIAGE.SEND_SMS',phone,f'Priority email alert: {len(rows)} email(s) require attention. Highest score: {highest}. Open Outlook to review.')
 if not sid or not str(sid).startswith('SM'):raise RuntimeError('Invalid Twilio Message SID')
 session.sql('BEGIN TRANSACTION').collect()
 try:
  for x in rows:session.sql('UPDATE MAIL_DB.TRIAGE.EMAILS SET SMS_SID=?,SMS_SUBMITTED_AT=CURRENT_TIMESTAMP(),NOTIFIED=TRUE WHERE ID=? AND MAILBOX=? AND SMS_SID IS NULL',params=[str(sid),x['ID'],x['MAILBOX']]).collect()
  session.sql('COMMIT').collect()
 except Exception:session.sql('ROLLBACK').collect();raise
 return f'One SMS submitted for {len(rows)} emails. SID: {sid}'
$$;
CREATE OR REPLACE PROCEDURE RUN_SMS_PIPELINE(MAILBOX STRING,PHONE STRING,MIN_SCORE INTEGER) RETURNS STRING LANGUAGE SQL EXECUTE AS CALLER AS $$
DECLARE a STRING;b STRING;c STRING;
BEGIN CALL LOAD_EMAILS(:MAILBOX) INTO :a;CALL SCORE_EMAILS() INTO :b;CALL NOTIFY_PRIORITY_SMS(:MAILBOX,:PHONE,:MIN_SCORE) INTO :c;RETURN a||' | '||b||' | '||c;END;$$;
