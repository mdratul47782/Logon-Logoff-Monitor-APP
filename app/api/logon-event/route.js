import nodemailer from 'nodemailer';
import { NextResponse } from 'next/server';

// Human-readable labels for the Windows event IDs we care about
const EVENT_LABELS = {
  4625: 'Failed Logon Attempt',
  4624: 'Successful Logon',
  4634: 'Logoff',
  4647: 'User Initiated Logoff',
};

// Gmail SMTP transporter — uses an App Password, not your normal password
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

export async function POST(request) {
  // 1. Authenticate the request — every PC agent must send the shared secret
  const incomingSecret = request.headers.get('x-api-secret');
  if (incomingSecret !== process.env.EVENT_API_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // 2. Parse the event payload sent by the PowerShell agent
  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const {
    computerName,
    eventId,
    account,        // the account name that failed/succeeded to log on
    sourceIp,        // IP address the attempt came from, if available
    timestamp,        // when the event occurred on the PC
    failureReason,     // optional extra detail from the event log
  } = body;

  if (!computerName || !eventId) {
    return NextResponse.json(
      { error: 'computerName and eventId are required' },
      { status: 400 }
    );
  }

  const label = EVENT_LABELS[eventId] || `Event ${eventId}`;

  // 3. Build and send the alert email
  try {
    await transporter.sendMail({
      from: `"Logon Monitor - ${computerName}" | Alert: 3 failed login attempts detected <${process.env.EMAIL_USER}>`,
      to: process.env.ALERT_EMAIL_TO || 'pclock.k2@hkdbd.com',
      subject: `[${label}] ${computerName}`,
      html: `
        <h2>${label}</h2>
        <table cellpadding="6" style="border-collapse:collapse">
          <tr><td><strong>Computer</strong></td><td>${computerName}</td></tr>
          <tr><td><strong>Event ID</strong></td><td>${eventId}</td></tr>
          <tr><td><strong>Account</strong></td><td>${account || 'Unknown'}</td></tr>
          <tr><td><strong>Source IP</strong></td><td>${sourceIp || 'N/A'}</td></tr>
          <tr><td><strong>Time</strong></td><td>${timestamp || new Date().toISOString()}</td></tr>
          <tr><td><strong>Details</strong></td><td>${failureReason || '—'}</td></tr>
        </table>
      `,
    });

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (err) {
    console.error('Error sending email:', err);
    return NextResponse.json({ error: 'Email failed to send' }, { status: 502 });
  }
}

// Reject any other HTTP method
export async function GET() {
  return NextResponse.json({ error: 'Method not allowed' }, { status: 405 });
}
