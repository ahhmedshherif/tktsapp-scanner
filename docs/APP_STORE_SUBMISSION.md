# TKTSAPP Scanner — App Store submission notes

## Public links

- Privacy Policy: `https://tktsapp.com/scanner/privacy-policy`
- Terms of Use: `https://tktsapp.com/scanner/terms-conditions`
- Support: `https://tktsapp.com/contact-us`
- Support email: `hello@tktsapp.com`

These are public HTTPS pages and are also reachable from the Scanner login screen and Account & Terminal Settings.

## App Review notes

TKTSAPP Scanner is a business/event-operations application for authorized organizers, managers and event staff. It validates QR tickets for real, in-person events at physical venues. It is not a consumer ticket marketplace and it does not sell digital goods or provide in-app purchasing.

Test access must be provided to App Review through an approved staff account or a time-limited event-login QR created from the TKTS APP web dashboard. The account should be restricted to a test event.

## Camera permission explanation

Camera access is requested only when an authorized user opens the scanner or scans a temporary event-login QR. The camera is used to decode QR codes; the app does not intentionally capture, retain, upload or record photos, video or audio.

## App Privacy answers — review before submission

Enter the final answers in App Store Connect based on the production build and enabled services:

| Data type | Purpose | Linked to identity | Tracking |
| --- | --- | --- | --- |
| Name and work email | Account authentication and app functionality | Yes | No |
| User ID / organizer role / event assignment | Account management and app functionality | Yes | No |
| Camera / QR scan input | App functionality and security | No camera media is retained | No |
| Ticket validation result and scan timestamp | App functionality, fraud prevention and operations | Associated with staff/event operations | No |
| Device/app diagnostics and security signals | Security, fraud prevention and service reliability | May be linked while a staff session is active | No |

Do not declare the application as tracking users unless a future build adds cross-app or cross-site advertising tracking. Re-check this table whenever analytics, crash reporting, advertising, payment or other SDKs change.

## Account deletion

Scanner accounts are organization-managed. Staff can contact their organizer owner or `hello@tktsapp.com` to request account deletion. Security, scan and financial/audit records may be retained where legally required or necessary to prevent fraud, resolve disputes and protect event operations.
