<?php
// =====================================================================
// login.php : ελέγχει username + κωδικό και βάζει τον χρήστη στο session.
//
// Βήματα:
//  1. sp_auth_get_login(username) -> hash κωδικού, ρόλος, κατάσταση
//  2. password_verify(κωδικός, hash)   (η βάση ΔΕΝ κρατά ποτέ τον ίδιο τον κωδικό)
//  3. Λογαριασμός Suspended -> όχι είσοδος. Τεχνικός Rejected -> όχι είσοδος.
//     Τεχνικός Pending/Suspended -> είσοδος ΜΟΝΟ στα έγγραφά του (FIX-2, auth.php technician_limited()).
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
if ($u['Role'] === 'Technician' && !in_array($u['ApprovalStatus'], ['Approved', 'Pending', 'Suspended'], true)) {
    call_proc('sp_auth_log_login', [$username, 0, $ip]);
    flash($u['ApprovalStatus'] === 'Rejected' ? 'Η εγγραφή σας απορρίφθηκε από τον Λειτουργό Συστήματος.'
                                              : 'Ο λογαριασμός δεν είναι ενεργός.', 'error');
    redirect('index.php');
}

call_proc('sp_auth_log_login', [$username, 1, $ip]);
session_regenerate_id(true);           // νέο session id μετά το login (κατά του session fixation)
unset($u['PasswordHash']);             // το hash δεν μένει στο session
$_SESSION['user'] = $u;
if ($u['Role'] === 'Technician' && $u['ApprovalStatus'] !== 'Approved') {
    flash($u['ApprovalStatus'] === 'Pending'
        ? 'Η εγγραφή σας περιμένει έγκριση. Ανεβάστε Ταυτότητα, Άδεια Εγκαταστάτη και Πιστοποιητικό Κατάρτισης για να εξεταστεί.'
        : 'Ο λογαριασμός τεχνικού είναι σε αναστολή. Μπορείτε να ανανεώσετε τα έγγραφά σας.');
    redirect('technician/10_documents.php');
}
redirect('home.php');
