<?php
// =====================================================================
// auth.php : ποιος είναι συνδεδεμένος και τι ρόλο έχει.
//
//   require_login()            -> αν δεν έχει κάνει login, πίσω στο index.php
//   require_role('Consumer')   -> επιτρέπει τη σελίδα ΜΟΝΟ σε αυτόν τον ρόλο
//   current_user()             -> ['UserID'=>…, 'Username'=>…, 'Role'=>…, …]
//   uid()                      -> το UserID (το δίνουμε ΠΑΝΤΑ πρώτο στα procedures)
//   url('consumer/x.php')      -> σωστό link είτε είμαστε στη ρίζα είτε σε φάκελο ρόλου
//   csrf_field() / check_csrf()-> προστασία φορμών (κάθε POST φόρμα τα χρειάζεται)
//
// Κανόνας καθηγητή: ένα username = ΕΝΑΣ ρόλος. Ο ρόλος έρχεται από τη στήλη
// USER_ACCOUNT.Role κατά το login και μένει στο session.
// =====================================================================

require_once __DIR__ . '/db.php';

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_set_cookie_params(['httponly' => true, 'samesite' => 'Lax']);
    session_start();
}

// Ρόλος -> φάκελος με τις σελίδες του και ελληνικό όνομα.
const ROLES = [
    'Admin'      => ['admin',      'Διαχειριστής Συστήματος'],
    'Operator'   => ['operator',   'Λειτουργός Συστήματος'],
    'Consumer'   => ['consumer',   'Καταναλωτής'],
    'Technician' => ['technician', 'Τεχνικός Πεδίου'],
    'DSO'        => ['dso',        'Διαχειριστής Δικτύου Διανομής (DSO)'],
    'TSO'        => ['tso',        'Διαχειριστής Συστήματος Μεταφοράς (TSO)'],
    'Supplier'   => ['supplier',   'Προμηθευτής'],
    'Aggregator' => ['aggregator', 'Aggregator'],
];

function current_user(): ?array
{
    return $_SESSION['user'] ?? null;
}

function uid(): int
{
    return (int)(current_user()['UserID'] ?? 0);
}

// Πόσα επίπεδα πιο μέσα από τη ρίζα της εφαρμογής είναι η σελίδα (0 ή 1).
function url(string $path): string
{
    $here = realpath(dirname($_SERVER['SCRIPT_FILENAME']));
    $root = realpath(__DIR__);
    return ($here === $root ? '' : '../') . $path;
}

function redirect(string $path): void
{
    header('Location: ' . url($path));
    exit;
}

function require_login(): void
{
    if (!current_user()) {
        redirect('index.php');
    }
}

function require_role(string ...$roles): void
{
    require_login();
    if (!in_array(current_user()['Role'], $roles, true)) {
        http_response_code(403);
        require_once __DIR__ . '/layout.php';
        page_header('Δεν επιτρέπεται');
        echo '<p class="error">Αυτή η σελίδα δεν είναι για τον ρόλο σας.</p>';
        page_footer();
        exit;
    }
}

// FIX-2: ο Τεχνικός που περιμένει έγκριση (Pending) ή είναι σε αναστολή (Suspended) μπαίνει, αλλά βλέπει
// ΜΟΝΟ τα έγγραφά του: πρέπει να ανεβάσει Ταυτότητα, Άδεια και Πιστοποιητικό για να τον εγκρίνει ο Operator
// (sp_tech_add_document δέχεται και Pending, sp_tech_assert_any). Η κατάσταση διαβάζεται ΦΡΕΣΚΙΑ από τη βάση,
// ώστε μετά την έγκριση να ανοίξουν οι υπόλοιπες σελίδες χωρίς νέο login.
const TECH_LIMITED_PAGES = ['technician/10_documents.php'];

function technician_limited(): bool
{
    $u = current_user();
    if (!$u || $u['Role'] !== 'Technician') {
        return false;
    }
    static $status = null;
    if ($status === null) {
        $rows = call_proc('sp_user_get_profile', [uid()]);
        $status = ($rows && isset($rows[0]['ApprovalStatus'])) ? (string)$rows[0]['ApprovalStatus'] : 'Pending';
        $_SESSION['user']['ApprovalStatus'] = $status;
    }
    return $status !== 'Approved';
}

// Σελίδες εργασιών του Τεχνικού: μόνο αφού εγκριθεί. Αλλιώς πίσω στα έγγραφα με εξήγηση.
function require_approved_technician(): void
{
    require_role('Technician');
    if (technician_limited()) {
        flash('Η εγγραφή σας δεν έχει εγκριθεί ακόμη (ή είναι σε αναστολή). Ανεβάστε τα έγγραφά σας· οι εργασίες ανοίγουν μετά την έγκριση από τον Λειτουργό Συστήματος.', 'error');
        redirect('technician/10_documents.php');
    }
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
    }
    return $_SESSION['csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="csrf" value="' . csrf_token() . '">';
}

// Καλείται στην αρχή κάθε χειρισμού POST.
function check_csrf(): void
{
    if (!hash_equals(csrf_token(), (string)($_POST['csrf'] ?? ''))) {
        http_response_code(400);
        die('Η φόρμα έληξε. Γύρισε πίσω και δοκίμασε ξανά.');
    }
}

// Μήνυμα που εμφανίζεται μία φορά στην επόμενη σελίδα (π.χ. «Αποθηκεύτηκε»).
function flash(?string $msg = null, string $kind = 'ok'): ?array
{
    if ($msg !== null) {
        $_SESSION['flash'] = [$kind, $msg];
        return null;
    }
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f;
}
