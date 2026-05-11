<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
  http_response_code(204);
  exit;
}

function db(): PDO {
  static $pdo = null;
  if ($pdo instanceof PDO) {
    return $pdo;
  }
  $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, DB_NAME);
  $pdo = new PDO($dsn, DB_USER, DB_PASS, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
  return $pdo;
}

function json_in(): array {
  $raw = file_get_contents('php://input');
  if (!$raw) return [];
  $decoded = json_decode($raw, true);
  return is_array($decoded) ? $decoded : [];
}

function respond(array $payload, int $status = 200): void {
  http_response_code($status);
  echo json_encode($payload);
  exit;
}

function fail(string $message, int $status = 400): void {
  respond(['error' => $message], $status);
}

function uuidv4(): string {
  $data = random_bytes(16);
  $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
  $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
  return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function random_join_code(int $len = 6): string {
  $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  $out = '';
  for ($i = 0; $i < $len; $i++) {
    $out .= $chars[random_int(0, strlen($chars) - 1)];
  }
  return $out;
}

function b64url_encode(string $data): string {
  return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function b64url_decode(string $data): string {
  $pad = 4 - (strlen($data) % 4);
  if ($pad < 4) $data .= str_repeat('=', $pad);
  return base64_decode(strtr($data, '-_', '+/')) ?: '';
}

function make_token(array $claims): string {
  $header = ['alg' => 'HS256', 'typ' => 'JWT'];
  $now = time();
  $payload = array_merge($claims, ['iat' => $now, 'exp' => $now + JWT_TTL_SECONDS]);
  $h = b64url_encode(json_encode($header));
  $p = b64url_encode(json_encode($payload));
  $sig = hash_hmac('sha256', "$h.$p", JWT_SECRET, true);
  return "$h.$p." . b64url_encode($sig);
}

function parse_token(string $token): ?array {
  $parts = explode('.', $token);
  if (count($parts) !== 3) return null;
  [$h, $p, $s] = $parts;
  $calc = b64url_encode(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));
  if (!hash_equals($calc, $s)) return null;
  $payload = json_decode(b64url_decode($p), true);
  if (!is_array($payload)) return null;
  if (($payload['exp'] ?? 0) < time()) return null;
  return $payload;
}

function auth_payload(): array {
  $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
  if (!preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
    fail('Unauthenticated.', 401);
  }
  $payload = parse_token($m[1]);
  if (!$payload) fail('Invalid token.', 401);
  return $payload;
}

function current_user_row(): array {
  $payload = auth_payload();
  $uuid = (string)($payload['uid'] ?? '');
  $stmt = db()->prepare('SELECT * FROM users WHERE uuid = ? LIMIT 1');
  $stmt->execute([$uuid]);
  $row = $stmt->fetch();
  if (!$row) fail('User not found.', 401);
  return $row;
}

function user_out(array $row): array {
  return [
    'id' => $row['uuid'],
    'name' => $row['name'],
    'email' => $row['email'],
    'role' => $row['role'],
    'matricNumber' => $row['matric_number'],
    'lecturerRegNo' => $row['lecturer_reg_no'],
    'lecturerStatus' => $row['lecturer_status'],
    'enrolledClassIds' => enrolled_class_uuids((int)$row['id']),
  ];
}

function enrolled_class_uuids(int $userId): array {
  $stmt = db()->prepare(
    'SELECT c.uuid FROM class_enrollments e JOIN classes c ON c.id=e.class_id WHERE e.student_user_id=?'
  );
  $stmt->execute([$userId]);
  return array_map(static fn($r) => $r['uuid'], $stmt->fetchAll());
}

function normalize_lecturer_reg(?string $raw): ?string {
  if ($raw === null) return null;
  $n = strtoupper(preg_replace('/\s+/', '', trim($raw)));
  if (strlen($n) < 4 || strlen($n) > 24) return null;
  if (!preg_match('/^[A-Z0-9\-]+$/', $n)) return null;
  return $n;
}

function meters_between(float $lat1, float $lng1, float $lat2, float $lng2): float {
  $r = 6371000.0;
  $dLat = deg2rad($lat2 - $lat1);
  $dLng = deg2rad($lng2 - $lng1);
  $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
  return $r * 2 * atan2(sqrt($a), sqrt(1 - $a));
}

