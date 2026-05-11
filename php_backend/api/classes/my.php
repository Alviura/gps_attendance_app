<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'lecturer') fail('Only lecturers can view classes.', 403);

$stmt = db()->prepare(
  'SELECT uuid,title,join_code FROM classes WHERE lecturer_user_id=? ORDER BY created_at DESC'
);
$stmt->execute([(int)$user['id']]);
$classes = array_map(
  static fn(array $r): array => [
    'id' => $r['uuid'],
    'title' => $r['title'],
    'joinCode' => $r['join_code'],
  ],
  $stmt->fetchAll()
);
respond(['classes' => $classes]);

