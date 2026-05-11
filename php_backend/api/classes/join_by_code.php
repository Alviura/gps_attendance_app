<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
if ($user['role'] !== 'student') fail('Only student accounts can join classes.', 403);

$in = json_in();
$joinCode = strtoupper(trim((string)($in['joinCode'] ?? '')));
if ($joinCode === '') fail('joinCode is required.', 422);

$pdo = db();
$stmt = $pdo->prepare('SELECT id,uuid,title FROM classes WHERE join_code=? LIMIT 1');
$stmt->execute([$joinCode]);
$class = $stmt->fetch();
if (!$class) fail('No class matches this join code.', 404);

$ins = $pdo->prepare('INSERT IGNORE INTO class_enrollments (class_id,student_user_id) VALUES (?,?)');
$ins->execute([(int)$class['id'], (int)$user['id']]);

respond(['classId' => $class['uuid'], 'title' => $class['title']]);

