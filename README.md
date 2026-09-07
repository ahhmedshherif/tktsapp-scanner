# TKTSAPP Scanner

Separate Flutter application for TKTSAPP organizers, administrators, managers, analysts, and scanner staff.

## Security model

- Email/password staff sign-in with Laravel two-factor verification when enabled.
- Staff access token is stored only in platform secure storage.
- Laravel scopes every request through staff membership, role and event assignment checks.
- Scanner users can scan only their assigned events.
- The app uses a staff-authorized scan endpoint; it never stores a device API key or provisioning token.
- Scan results omit buyer phone, email, ticket serial, transfer details, and payment data.

## Role experience

| Role | Workspace |
| --- | --- |
| Scanner | Assigned events, scanner station selection, entry/exit/validate QR scanning, account |
| Organizer owner | Overview, own events, scanning, create/pause team accounts with event assignments |
| Manager | Assigned events, permitted analytics and scanning |
| Analyst | Assigned events and read-only analytics |
| Admin / Super admin | Global operational overview, events, authorized scanning, account |

## Run and build

```powershell
flutter pub get
flutter test
flutter analyze
flutter run
flutter build apk --debug
```

The default API base URL is `https://tktsapp.com/api/v1`. Use `--dart-define=API_BASE_URL=...` for non-production builds. Release signing remains in secure CI settings; no secret belongs in source code.
