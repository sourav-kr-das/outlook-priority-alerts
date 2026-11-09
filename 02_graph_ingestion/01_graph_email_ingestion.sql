USE SCHEMA MAIL_DB.TRIAGE;
CREATE OR REPLACE PROCEDURE TEST_GRAPH(MAILBOX STRING) RETURNS STRING
LANGUAGE PYTHON RUNTIME_VERSION='3.11' PACKAGES=('snowflake-snowpark-python','requests') HANDLER='run'
EXTERNAL_ACCESS_INTEGRATIONS=(TRIAGE_EAI) SECRETS=('graph'=GRAPH_SECRET) AS $$
import _snowflake,requests
TENANT='<MS_TENANT_ID>'; CLIENT='<MS_CLIENT_ID>'
def run(session,mailbox):
 r=requests.post(f'https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token',data={'client_id':CLIENT,'client_secret':_snowflake.get_generic_secret_string('graph'),'grant_type':'client_credentials','scope':'https://graph.microsoft.com/.default'},timeout=30)
 if not r.ok:return f'Token failed {r.status_code}: {r.text[:300]}'
 m=requests.get(f'https://graph.microsoft.com/v1.0/users/{mailbox}/messages',params={'$top':'5','$select':'subject,from'},headers={'Authorization':f"Bearer {r.json()['access_token']}"},timeout=30)
 if not m.ok:return f'Mail failed {m.status_code}: {m.text[:300]}'
 return ' | '.join(x.get('subject') or '(no subject)' for x in m.json().get('value',[])) or 'Connected; inbox empty'
$$;

CREATE OR REPLACE PROCEDURE LOAD_EMAILS(MAILBOX STRING) RETURNS STRING
LANGUAGE PYTHON RUNTIME_VERSION='3.11' PACKAGES=('snowflake-snowpark-python','requests') HANDLER='run'
EXTERNAL_ACCESS_INTEGRATIONS=(TRIAGE_EAI) SECRETS=('graph'=GRAPH_SECRET) EXECUTE AS CALLER AS $$
import _snowflake,requests,uuid
from datetime import timezone
from urllib.parse import quote
TENANT='<MS_TENANT_ID>'; CLIENT='<MS_CLIENT_ID>'; T='MAIL_DB.TRIAGE.EMAILS'; V='MAIL_DB.TRIAGE.VIP'
def get_token():
 r=requests.post(f'https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token',data={'client_id':CLIENT,'client_secret':_snowflake.get_generic_secret_string('graph'),'grant_type':'client_credentials','scope':'https://graph.microsoft.com/.default'},timeout=30);r.raise_for_status();return r.json()['access_token']
def run(session,mailbox):
 mailbox=(mailbox or '').strip().lower()
 if not mailbox:raise ValueError('MAILBOX is required')
 last=session.sql(f'SELECT COALESCE(MAX(RECEIVED),DATEADD(day,-2,CURRENT_TIMESTAMP())) FROM {T} WHERE LOWER(MAILBOX)=?',params=[mailbox]).collect()[0][0]
 since=last.astimezone(timezone.utc).isoformat(timespec='microseconds').replace('+00:00','Z')
 url=f'https://graph.microsoft.com/v1.0/users/{quote(mailbox,safe="")}/mailFolders/inbox/messages'; params={'$filter':f'receivedDateTime gt {since}','$select':'id,receivedDateTime,from,toRecipients,subject,bodyPreview,importance,webLink','$top':'50'}; headers={'Authorization':f'Bearer {get_token()}'}; rows=[];seen=set()
 while url:
  r=requests.get(url,headers=headers,params=params,timeout=30);r.raise_for_status();data=r.json()
  for m in data.get('value',[]):
   if m['id'] in seen:continue
   seen.add(m['id']); recipients=[((x.get('emailAddress') or {}).get('address') or '').lower() for x in m.get('toRecipients',[])]; sender=((((m.get('from') or {}).get('emailAddress') or {}).get('address')) or '').lower()
   rows.append((m['id'],mailbox,m['receivedDateTime'],sender,m.get('subject') or '',(m.get('bodyPreview') or '')[:1500],m.get('importance') or 'normal',mailbox in recipients,m.get('webLink') or ''))
  url=data.get('@odata.nextLink');params=None
 if not rows:return 'No new emails. Fetched: 0; inserted: 0.'
 stage='MAIL_DB.TRIAGE.EMAILS_STAGE_'+uuid.uuid4().hex.upper()
 try:
  session.create_dataframe(rows,schema=['ID','MAILBOX','RECEIVED','SENDER','SUBJECT','PREVIEW','IMPORTANCE','TO_ME','WEBLINK']).write.save_as_table(stage,mode='overwrite',table_type='temporary')
  x=session.sql(f'''MERGE INTO {T} t USING {stage} s ON t.ID=s.ID AND LOWER(t.MAILBOX)=s.MAILBOX WHEN NOT MATCHED THEN INSERT(ID,MAILBOX,RECEIVED,SENDER,SUBJECT,PREVIEW,IMPORTANCE,TO_ME,IS_VIP,WEBLINK) VALUES(s.ID,s.MAILBOX,s.RECEIVED::TIMESTAMP_TZ,s.SENDER,s.SUBJECT,s.PREVIEW,s.IMPORTANCE,s.TO_ME,EXISTS(SELECT 1 FROM {V} v WHERE LOWER(TRIM(v.VALUE))=s.SENDER),s.WEBLINK)''').collect();inserted=int(x[0][0]);return f'{inserted} inserted; {len(rows)} fetched; {len(rows)-inserted} already stored.'
 finally:session.sql(f'DROP TABLE IF EXISTS {stage}').collect()
$$;
