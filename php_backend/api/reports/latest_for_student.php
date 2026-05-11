<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'student') {
  respond(['report' => null]);
}

$stmt = db()->prepare(
  'SELECT s.id AS sid, s.title AS session_title, s.created_at, c.id AS cid
   FROM class_enrollments e
   JOIN sessions s ON s.class_id=e.class_id
   JOIN classes c ON c.id=e.class_id
   WHERE e.student_user_id=?
   ORDER BY s.starts_at DESC LIMIT 1'
);
$stmt->execute([(int)$user['id']]);
$session = $stmt->fetch();
if (!$session) respond(['report' => null]);

$cnt = db()->prepare('SELECT COUNT(*) AS total FROM class_enrollments WHERE class_id=?');
$cnt->execute([(int)$session['cid']]);
$total = (int)$cnt->fetch()['total'];

$presentStmt = db()->prepare('SELECT COUNT(*) AS present FROM attendance WHERE session_id=?');
$presentStmt->execute([(int)$session['sid']]);
$present = (int)$presentStmt->fetch()['present'];

respond([
  'report' => [
    'sessionTitle' => $session['session_title'],
    'totalStudents' => $total,
    'presentCount' => $present,
    'absentCount' => max(0, $total - $present),
    'generatedAt' => (new DateTimeImmutable($session['created_at'], new DateTimeZone('UTC')))->format(DATE_ATOM),
  ],
]);

