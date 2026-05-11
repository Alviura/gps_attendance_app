<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$in = json_in();
$name = trim((string)($in['name'] ?? ''));
$email = strtolower(trim((string)($in['email'] ?? '')));
$password = (string)($in['password'] ?? '');
$role = (string)($in['role'] ?? 'student');
$matric = trim((string)($in['matricNumber'] ?? ''));
$lecturerReg = normalize_lecturer_reg($in['lecturerRegNo'] ?? null);

if ($name === '' || !str_contains($email, '@') || strlen($password) < 6) {
  fail('Invalid registration payload.', 422);
}
if (!in_array($role, ['student', 'lecturer'], true)) {
  fail('Unsupported role.', 422);
}
if ($role === 'lecturer' && !$lecturerReg) {
  fail('Invalid lecturer registration number.', 422);
}

$pdo = db();
$stmt = $pdo->prepare('SELECT id FROM users WHERE email=? LIMIT 1');
$stmt->execute([$email]);
if ($stmt->fetch()) {
  fail('Email already in use.', 409);
}
if ($role === 'lecturer') {
  $stmt = $pdo->prepare('SELECT id FROM users WHERE lecturer_reg_no=? LIMIT 1');
  $stmt->execute([$lecturerReg]);
  if ($stmt->fetch()) fail('This lecturer registration number is already taken.', 409);
}

$uuid = uuidv4();
$hash = password_hash($password, PASSWORD_DEFAULT);
$lecturerStatus = $role === 'lecturer' ? 'active' : null;
$stmt = $pdo->prepare(
  'INSERT INTO users (uuid,name,email,password_hash,role,matric_number,lecturer_reg_no,lecturer_status)
   VALUES (?,?,?,?,?,?,?,?)'
);
$stmt->execute([
  $uuid,
  $name,
  $email,
  $hash,
  $role,
  $role === 'student' && $matric !== '' ? $matric : null,
  $role === 'lecturer' ? $lecturerReg : null,
  $lecturerStatus,
]);

$stmt = $pdo->prepare('SELECT * FROM users WHERE uuid=? LIMIT 1');
$stmt->execute([$uuid]);
$user = $stmt->fetch();
$token = make_token(['uid' => $uuid, 'role' => $role]);
respond(['token' => $token, 'user' => user_out($user)]);

