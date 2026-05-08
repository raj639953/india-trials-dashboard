# Nightmare Clinical Analytics

Local clinical trials intelligence website and BI-style explorer for the India active trials dataset.

## Run Locally

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-NightmareClinicalAnalytics.ps1"
```

Open:

```text
http://localhost:4321
```

Stop:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Stop-NightmareClinicalAnalytics.ps1"
```

## Contact Form

The browser posts contact form submissions to:

```text
POST /api/contact
```

The recipient email is stored server-side in `.env` as `CONTACT_TO_EMAIL`; it is not exposed in `index.html` or frontend JavaScript.

Submissions are always saved locally to:

```text
data/contact-submissions.jsonl
```

Direct email delivery requires a server-side email provider key:

```text
RESEND_API_KEY=...
```

For Vercel later, set these as environment variables:

```text
CONTACT_TO_EMAIL
CONTACT_FROM_EMAIL
RESEND_API_KEY
```
