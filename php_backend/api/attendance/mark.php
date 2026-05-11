<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'student') fail('Only students can mark attendance.', 403);

$in = json_in();
$sessionUuid = (string)($in['sessionId'] ?? '');
$lat = (float)($in['latitude'] ?? 0);
$lng = (float)($in['longitude'] ?? 0);
$verification = (string)($in['verificationMethod'] ?? '');
if ($sessionUuid === '' || $verification !== 'biometric') {
  fail('Session ID and biometric verification are required.', 422);
}

$pdo = db();
$stmt = $pdo->prepare(
  'SELECT s.id AS sid, s.status, s.starts_at, s.ends_at, c.id AS cid, c.title, c.latitude, c.longitude, c.radius_meters
   FROM sessions s JOIN classes c ON c.id=s.class_id WHERE s.uuid=? LIMIT 1'
);
$stmt->execute([$sessionUuid]);
$session = $stmt->fetch();
if (!$session) fail('Class session was not found.', 404);
if ($session['status'] !== 'active') fail('Attendance is not open for this session.', 412);

$now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
if ($now < new DateTimeImmutable($session['starts_at'], new DateTimeZone('UTC'))) {
  fail('Attendance has not started yet.', 412);
}
if ($now > new DateTimeImmutable($session['ends_at'], new DateTimeZone('UTC'))) {
  fail('Attendance has already closed.', 412);
}

$en = $pdo->prepare('SELECT 1 FROM class_enrollments WHERE class_id=? AND student_user_id=? LIMIT 1');
$en->execute([(int)$session['cid'], (int)$user['id']]);
if (!$en->fetch()) fail('Student is not enrolled in this class.', 403);

$distance = meters_between($lat, $lng, (float)$session['latitude'], (float)$session['longitude']);
$radius = (float)$session['radius_meters'];
if ($distance > $radius) {
  respond([
    'accepted' => false,
    'distanceMeters' => round($distance, 1),
    'message' => 'Attendance rejected. You are ' . round($distance, 1) . 'm away, outside the ' . round($radius) . 'm classroom radius.',
  ]);
}

$chk = $pdo->prepare('SELECT id FROM attendance WHERE session_id=? AND student_user_id=? LIMIT 1');
$chk->execute([(int)$session['sid'], (int)$user['id']]);
if ($chk->fetch()) fail('Attendance has already been marked.', 409);

$ins = $pdo->prepare(
  'INSERT INTO attendance (session_id,class_id,student_user_id,latitude,longitude,distance_meters,verification_method,status,marked_at)
   VALUES (?,?,?,?,?,?,?,?,?)'
);
$ins->execute([
  (int)$session['sid'],
  (int)$session['cid'],
  (int)$user['id'],
  $lat,
  $lng,
  round($distance, 2),
  'biometric',
  'present',
  $now->format('Y-m-d H:i:s'),
]);

respond([
  'accepted' => true,
  'distanceMeters' => round($distance, 1),
  'message' => 'Attendance accepted. You are ' . round($distance, 1) . 'm from the classroom.',
]);

