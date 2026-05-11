<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'lecturer') fail('Only lecturers can view reports.', 403);

$stmt = db()->prepare(
  'SELECT s.id AS sid, s.title AS session_title, s.created_at, s.class_id
   FROM sessions s
   WHERE s.lecturer_user_id=?
   ORDER BY s.starts_at DESC
   LIMIT 20'
);
$stmt->execute([(int)$user['id']]);
$rows = $stmt->fetchAll();

$reports = [];
foreach ($rows as $row) {
  $cnt = db()->prepare('SELECT COUNT(*) AS total FROM class_enrollments WHERE class_id=?');
  $cnt->execute([(int)$row['class_id']]);
  $total = (int)$cnt->fetch()['total'];

  $presentStmt = db()->prepare('SELECT COUNT(*) AS present FROM attendance WHERE session_id=?');
  $presentStmt->execute([(int)$row['sid']]);
  $present = (int)$presentStmt->fetch()['present'];

  $reports[] = [
    'sessionTitle' => $row['session_title'],
    'totalStudents' => $total,
    'presentCount' => $present,
    'absentCount' => max(0, $total - $present),
    'generatedAt' => (new DateTimeImmutable($row['created_at'], new DateTimeZone('UTC')))->format(DATE_ATOM),
  ];
}

respond(['reports' => $reports]);

