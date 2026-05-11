<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'student') {
  respond(['session' => null]);
}

$stmt = db()->prepare(
  'SELECT s.uuid AS session_uuid, s.starts_at, s.ends_at, c.uuid AS class_uuid, c.title, c.room_name,
          c.latitude, c.longitude, c.radius_meters, u.name AS lecturer_name
   FROM class_enrollments e
   JOIN sessions s ON s.class_id=e.class_id
   JOIN classes c ON c.id=e.class_id
   JOIN users u ON u.id=c.lecturer_user_id
   WHERE e.student_user_id=? AND s.status="active"
   ORDER BY s.starts_at DESC LIMIT 1'
);
$stmt->execute([(int)$user['id']]);
$row = $stmt->fetch();
if (!$row) {
  respond(['session' => null]);
}

$session = [
  'id' => $row['session_uuid'],
  'classId' => $row['class_uuid'],
  'classTitle' => $row['title'],
  'roomName' => $row['room_name'],
  'lecturerName' => $row['lecturer_name'],
  'startsAt' => (new DateTimeImmutable($row['starts_at'], new DateTimeZone('UTC')))->format(DATE_ATOM),
  'endsAt' => (new DateTimeImmutable($row['ends_at'], new DateTimeZone('UTC')))->format(DATE_ATOM),
  'latitude' => (float)$row['latitude'],
  'longitude' => (float)$row['longitude'],
  'radiusMeters' => (float)$row['radius_meters'],
];
respond(['session' => $session]);

