# PHP Backend (XAMPP)

This folder contains a complete PHP + MySQL backend for the Flutter app.

## Quick setup

1. Copy `php_backend` into your XAMPP `htdocs`:
   - Example: `C:\xampp\htdocs\gps_attendance_api`
2. Create a MySQL database named `gps_attendance`.
3. Import `sql/schema.sql`.
4. Update DB credentials in `api/config.php`.
5. Start Apache + MySQL in XAMPP.
6. Run Flutter with:

```bash
flutter run --dart-define=BACKEND_MODE=php --dart-define=API_BASE_URL=http://<YOUR_PC_LAN_IP>/gps_attendance_api/api
```

For Android emulator, use:

```bash
flutter run --dart-define=BACKEND_MODE=php --dart-define=API_BASE_URL=http://10.0.2.2/gps_attendance_api/api
```

