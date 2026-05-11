<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'lecturer' || $user['lecturer_status'] === 'rejected') {
  fail('Only lecturers can create classes.', 403);
}

$in = json_in();
$title = trim((string)($in['title'] ?? ''));
$room = trim((string)($in['roomName'] ?? ''));
$lat = (float)($in['latitude'] ?? 0);
$lng = (float)($in['longitude'] ?? 0);
$radius = (int)($in['radiusMeters'] ?? 50);
if ($title === '' || $room === '') fail('title and roomName are required.', 422);

$pdo = db();
do {
  $joinCode = random_join_code();
  $chk = $pdo->prepare('SELECT id FROM classes WHERE join_code=? LIMIT 1');
  $chk->execute([$joinCode]);
  $exists = (bool)$chk->fetch();
} while ($exists);

$uuid = uuidv4();
$stmt = $pdo->prepare(
  'INSERT INTO classes (uuid,title,room_name,lecturer_user_id,join_code,latitude,longitude,radius_meters)
   VALUES (?,?,?,?,?,?,?,?)'
);
$stmt->execute([$uuid, $title, $room, $user['id'], $joinCode, $lat, $lng, $radius]);

respond(['classId' => $uuid, 'joinCode' => $joinCode]);

