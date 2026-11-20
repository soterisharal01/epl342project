<?php
// =====================================================================
// profile.php : τα στοιχεία μου + αλλαγή κωδικού (κάθε ρόλος).
// Procedures: sp_user_get_profile, sp_auth_get_login (για τον παλιό κωδικό),
//             sp_user_change_password.
// =====================================================================
require_once __DIR__ . '/layout.php';
require_login();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $old = (string)($_POST['old'] ?? '');
    $new = (string)($_POST['new'] ?? '');
    $rows = call_proc('sp_auth_get_login', [current_user()['Username']]);
    if (!$rows || !password_verify($old, $rows[0]['PasswordHash'])) {
        flash('Ο τρέχων κωδικός δεν είναι σωστός.', 'error');
    } elseif (strlen($new) < 8) {
        flash('Ο νέος κωδικός θέλει τουλάχιστον 8 χαρακτήρες.', 'error');
    } elseif (call_proc('sp_user_change_password', [uid(), password_hash($new, PASSWORD_DEFAULT)]) === false) {
        flash(last_error(), 'error');
    } else {
        flash('Ο κωδικός άλλαξε.');
    }
    redirect('profile.php');
}

page_header('Το προφίλ μου');
$p = call_proc('sp_user_get_profile', [uid()]);
if ($p) {
    echo '<table class="data kv">';
    $labels = ['Username' => 'Username', 'Role' => 'Ρόλος', 'FirstName' => 'Όνομα', 'LastName' => 'Επώνυμο',
               'Email' => 'Email', 'Phone' => 'Τηλέφωνο', 'AccountStatus' => 'Κατάσταση', 'CreatedAt' => 'Δημιουργία',
               'ApprovalStatus' => 'Έγκριση', 'Supplier' => 'Προμηθευτής', 'Aggregator' => 'Aggregator',
               'NotificationChannels' => 'Ειδοποιήσεις'];
    foreach ($p[0] as $k => $v) {
        if ($v !== null && $v !== '') {
            echo '<tr><th>' . h($labels[$k] ?? $k) . '</th><td>' . h($v) . '</td></tr>';
        }
    }
    echo '</table>';
} else {
    print_table($p);
}
?>
<h2>Αλλαγή κωδικού</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Τρέχων κωδικός <input type="password" name="old" required></label>
  <label>Νέος κωδικός <input type="password" name="new" required minlength="8"></label>
  <button type="submit">Αλλαγή</button>
</form>
<?php page_footer();
