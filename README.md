# Logon Monitor — Real-time Windows Event 4625 Email Alerts

Central Next.js server that receives real-time alerts from any number of
Windows PCs whenever Event ID **4625** (failed logon) fires, and emails
`pclock.k2@hkdbd.com` via Resend.

## How it works

```
[PC #1] --4625 event--> Task Scheduler --> Send-LogonAlert.ps1 --POST--> [Next.js API] --> Resend --> email
[PC #2] --4625 event--> Task Scheduler --> Send-LogonAlert.ps1 --POST-->        ^
[PC #N] ...                                                                    |
                                                              shared secret auth
```

- `app/api/logon-event/route.js` — the API endpoint. Verifies a shared
  secret, then sends the alert email.
- `agent/Send-LogonAlert.ps1` — runs on each monitored PC, reads the
  event, and POSTs it to your server.
- `agent/Register-LogonAlertTask.ps1` — one-time setup script that wires
  the PowerShell script to a Task Scheduler trigger on Event ID 4625.

## 1. Deploy the server

```bash
npm install
cp .env.local.example .env.local
```

Edit `.env.local`:

```
EMAIL_USER=amanmbsl568@gmail.com
EMAIL_PASS=gndabtrpgdzexots
ALERT_EMAIL_TO=pclock.k2@hkdbd.com
EVENT_API_SECRET=<generate with: openssl rand -hex 32>
```

`EMAIL_PASS` is a Gmail **App Password**, not your normal Gmail login
password. Generate one at https://myaccount.google.com/apppasswords
(requires 2-Step Verification enabled on the Google account). Google
shows it with spaces for readability (`gnda btrp gdze xots`) — you can
paste it with or without the spaces, Nodemailer strips them either way.

Then run locally to test:

```bash
npm run dev
```

For production, deploy to any Node host (Vercel, Railway, your own VPS,
etc.) and set the same environment variables there — Gmail SMTP works
the same regardless of host, and unlike Resend there's no domain
verification step, so you can send to any recipient (like
`pclock.k2@hkdbd.com`) right away.

**Gmail sending limits:** a personal Gmail account can send roughly
500 emails/day via SMTP. Fine for logon alerts on a handful of PCs;
if you're monitoring many machines with frequent failed logons, keep
an eye on volume.

## 2. Set up each monitored PC

Copy the `agent/` folder to each Windows PC, e.g. `C:\LogonMonitor\`.

Edit `Send-LogonAlert.ps1` and set:
- `$ApiUrl` → your deployed server's URL, e.g. `https://your-server.com/api/logon-event`
- `$ApiSecret` → the same value you put in `EVENT_API_SECRET` on the server

Then, in an **Administrator** PowerShell prompt on that PC, run once:

```powershell
cd C:\LogonMonitor
.\Register-LogonAlertTask.ps1 -ScriptPath "C:\LogonMonitor\Send-LogonAlert.ps1"
```

This creates a Scheduled Task that fires **immediately** whenever Windows
logs Event ID 4625, running as SYSTEM (needed to read the Security log).

### Notes on 4625 auditing
Event 4625 is only logged if **Audit Logon Events** (failure auditing) is
enabled on that PC. Check/enable via:
```
secpol.msc → Local Policies → Audit Policy → Audit logon events → Failure
```
or via Group Policy if the PCs are domain-joined.

## 3. Test end-to-end

On a monitored PC, deliberately fail a login (wrong password) to trigger
a 4625 event, or run the script manually to test the POST/email path:

```powershell
.\Send-LogonAlert.ps1 -ApiUrl "https://your-server.com/api/logon-event" -ApiSecret "your-secret"
```

You should receive an email at `pclock.k2@hkdbd.com` within seconds.

## Security notes
- The `EVENT_API_SECRET` prevents random internet traffic from triggering
  emails through your public API — keep it private and unique per deployment.
- Consider putting the API behind HTTPS only (default on Vercel) and,
  if PCs are on a known network, restricting inbound access further
  (firewall/allow-list) at your hosting provider.
- Rotate your Gmail App Password (generate a new one, revoke the old) if
  it's ever shared or committed to a public repo — revoking is instant
  and free at https://myaccount.google.com/apppasswords.
