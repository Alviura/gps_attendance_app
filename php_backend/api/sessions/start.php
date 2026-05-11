<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'lecturer' || $user['lecturer_status'] === 'rejected') {
  fail('Only lecturers can start sessions.', 403);
}

$in = json_in();
$classUuid = (string)($in['classId'] ?? '');
$titleInput = trim((string)($in['title'] ?? ''));
$duration = max(1, (int)($in['durationMinutes'] ?? 120));
if ($classUuid === '') fail('classId is required.', 422);

$pdo = db();
$stmt = $pdo->prepare('SELECT * FROM classes WHERE uuid=? LIMIT 1');
$stmt->execute([$classUuid]);
$class = $stmt->fetch();
if (!$class) fail('Class not found.', 404);
if ((int)$class['lecturer_user_id'] !== (int)$user['id']) fail('You do not own this class.', 403);

$uuid = uuidv4();
$starts = new DateTimeImmutable('now', new DateTimeZone('UTC'));
$ends = $starts->modify("+{$duration} minutes");
$title = $titleInput !== '' ? $titleInput : (($class['title'] ?? 'Session') . ' attendance');

$stmt = $pdo->prepare(
  'INSERT INTO sessions (uuid,class_id,lecturer_user_id,title,status,starts_at,ends_at)
   VALUES (?,?,?,?,?,?,?)'
);
$stmt->execute([
  $uuid,
  (int)$class['id'],
  (int)$user['id'],
  $title,
  'active',
  $starts->format('Y-m-d H:i:s'),
  $ends->format('Y-m-d H:i:s'),
]);

respond(['sessionId' => $uuid]);

