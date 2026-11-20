<?php
// =====================================================================
// login.php : ελέγχει username + κωδικό και βάζει τον χρήστη στο session.
//
// Βήματα:
//  1. sp_auth_get_login(username) -> hash κωδικού, ρόλος, κατάσταση
//  2. password_verify(κωδικός, hash)   (η βάση ΔΕΝ κρατά ποτέ τον ίδιο τον κωδικό)
//  3. Λογαριασμός Suspended -> όχι είσοδος. Τεχνικός Pending/Rejected -> όχι είσοδος.
//  4. Κάθε προσπάθεια γράφεται στο AUDIT_LOG (sp_auth_log_login).
//  5. Επιτυχία -> session με UserID και Role -> home.php (το μενού του ρόλου).
// =====================================================================
require_once __DIR__ . '/auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    redirect('index.php');
}
check_csrf();

$username = trim((string)($_POST['username'] ?? ''));
$password = (string)($_POST['password'] ?? '');
$ip = $_SERVER['REMOTE_ADDR'] ?? null;

$rows = call_proc('sp_auth_get_login', [$username]);
if ($rows === false) {
    flash(last_error(), 'error');
    redirect('index.php');
}
$u = $rows[0] ?? null;

// Ίδιο μήνυμα για «δεν υπάρχει χρήστης» και «λάθος κωδικός»: δεν μαρτυράμε ποια usernames υπάρχουν.
if (!$u || !password_verify($password, $u['PasswordHash'])) {
    call_proc('sp_auth_log_login', [$username, 0, $ip]);
    flash('Λάθος username ή κωδικός.', 'error');
    redirect('index.php');
}
if ($u['AccountStatus'] !== 'Active') {
    call_proc('sp_auth_log_login', [$username, 0, $ip]);
    flash('Ο λογαριασμός σας είναι σε αναστολή. Επικοινωνήστε με τον Λειτουργό Συστήματος.', 'error');
    redirect('index.php');
}
if ($u['Role'] === 'Technician' && $u['ApprovalStatus'] !== 'Approved') {
    call_proc('sp_auth_log_login', [$username, 0, $ip]);
    $why = [
        'Pending'   => 'Η εγγραφή σας περιμένει έγκριση από τον Λειτουργό Συστήματος.',
        'Rejected'  => 'Η εγγραφή σας απορρίφθηκε από τον Λειτουργό Συστήματος.',
        'Suspended' => 'Ο λογαριασμός τεχνικού είναι σε αναστολή.',
    ];
    flash($why[$u['ApprovalStatus']] ?? 'Ο λογαριασμός δεν είναι ενεργός.', 'error');
    redirect('index.php');
}

call_proc('sp_auth_log_login', [$username, 1, $ip]);
session_regenerate_id(true);           // νέο session id μετά το login (κατά του session fixation)
unset($u['PasswordHash']);             // το hash δεν μένει στο session
$_SESSION['user'] = $u;
redirect('home.php');
