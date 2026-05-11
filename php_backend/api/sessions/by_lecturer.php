<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'lecturer') fail('Only lecturers can view sessions.', 403);

$stmt = db()->prepare(
  'SELECT uuid,title,status FROM sessions WHERE lecturer_user_id=? ORDER BY starts_at DESC LIMIT 40'
);
$stmt->execute([(int)$user['id']]);
$sessions = array_map(
  static fn(array $r): array => [
    'id' => $r['uuid'],
    'title' => $r['title'],
    'status' => $r['status'],
  ],
  $stmt->fetchAll()
);
respond(['sessions' => $sessions]);

