# GPS Attendance App

Flutter attendance app with GPS + biometric checks.

## Backend modes

- `php` (default): calls the PHP/XAMPP backend in `php_backend/`
- `demo`: in-memory demo without remote backend

Run with PHP backend:

```bash
flutter run --dart-define=BACKEND_MODE=php --dart-define=API_BASE_URL=http://10.0.2.2/gps_attendance_api/api
```

Run demo mode:

```bash
flutter run --dart-define=BACKEND_MODE=demo
```

For full PHP setup instructions, see `php_backend/README.md`.
