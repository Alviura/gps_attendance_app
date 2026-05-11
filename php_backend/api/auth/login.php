<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$in = json_in();
$email = strtolower(trim((string)($in['email'] ?? '')));
$password = (string)($in['password'] ?? '');

if (!str_contains($email, '@') || $password === '') {
  fail('Email and password are required.', 422);
}

$stmt = db()->prepare('SELECT * FROM users WHERE email=? LIMIT 1');
$stmt->execute([$email]);
$user = $stmt->fetch();
if (!$user || !password_verify($password, $user['password_hash'])) {
  fail('Invalid credentials.', 401);
}

$token = make_token(['uid' => $user['uuid'], 'role' => $user['role']]);
respond(['token' => $token, 'user' => user_out($user)]);

