<?php
declare(strict_types=1);
require_once __DIR__ . '/../bootstrap.php';

$user = current_user_row();
$in = json_in();
$sessionUuid = (string)($in['sessionId'] ?? '');
if ($sessionUuid === '') fail('sessionId is required.', 422);

$pdo = db();
$stmt = $pdo->prepare('SELECT * FROM sessions WHERE uuid=? LIMIT 1');
$stmt->execute([$sessionUuid]);
$session = $stmt->fetch();
if (!$session) fail('Session not found.', 404);
if ((int)$session['lecturer_user_id'] !== (int)$user['id']) fail('You do not own this session.', 403);

$stmt = $pdo->prepare('UPDATE sessions SET status="closed", closed_at=UTC_TIMESTAMP() WHERE id=?');
$stmt->execute([(int)$session['id']]);

respond(['ok' => true]);

