USE SCHEMA MAIL_DB.TRIAGE;
CREATE OR REPLACE PROCEDURE SEND_SMS(PHONE STRING,MESSAGE_TEXT STRING) RETURNS STRING
LANGUAGE PYTHON RUNTIME_VERSION='3.11' PACKAGES=('snowflake-snowpark-python','requests') HANDLER='run'
EXTERNAL_ACCESS_INTEGRATIONS=(TRIAGE_EAI) SECRETS=('twilio'=TWILIO_SECRET) EXECUTE AS CALLER AS $$
import _snowflake,requests,re
TWILIO_FROM='<TWILIO_FROM_NUMBER>'
def run(session,phone,message_text):
 phone=(phone or '').strip();text=(message_text or '').strip()
 if not re.fullmatch(r'\+[1-9]\d{7,14}',phone):raise ValueError('Use E.164 format')
 if not text:raise ValueError('MESSAGE_TEXT is required')
 c=_snowflake.get_username_password('twilio');url=f'https://api.twilio.com/2010-04-01/Accounts/{c.username}/Messages.json';r=requests.post(url,auth=(c.username,c.password),data={'To':phone,'From':TWILIO_FROM,'Body':text[:1500]},timeout=30)
 if not r.ok:
  try:e=r.json();code=e.get('code',r.status_code);message=e.get('message','SMS rejected')
  except ValueError:code=r.status_code;message='SMS rejected'
  raise RuntimeError(f'Twilio error {code}: {message}')
 return r.json()['sid']
$$;
