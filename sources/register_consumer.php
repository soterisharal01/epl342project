<?php
// =====================================================================
// register_consumer.php : self-registration καταναλωτή (ΙΙΙ.1.1).
// Χωρίς έγκριση: μετά την εγγραφή μπορεί αμέσως να κάνει login.
// Ο κωδικός γίνεται hash ΕΔΩ (password_hash) και στη βάση πάει μόνο το hash.
// Procedure: sp_auth_register_consumer.
// =====================================================================
require_once __DIR__ . '/layout.php';

$f = ['username' => '', 'email' => '', 'phone' => '', 'first' => '', 'last' => ''];
$err = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    foreach ($f as $k => $_) {
        $f[$k] = trim((string)($_POST[$k] ?? ''));
    }
    $pw = (string)($_POST['password'] ?? '');
    $channels = implode(',', array_intersect(['Email', 'SMS'], (array)($_POST['channels'] ?? [])));
    if (strlen($pw) < 8) {
        $err = 'Ο κωδικός θέλει τουλάχιστον 8 χαρακτήρες.';
    } elseif ($pw !== ($_POST['password2'] ?? '')) {
        $err = 'Οι δύο κωδικοί δεν είναι ίδιοι.';
    } elseif ($channels === '') {
        $err = 'Διαλέξτε τουλάχιστον ένα κανάλι ειδοποιήσεων.';
    } else {
        $r = call_proc('sp_auth_register_consumer', [
            $f['username'], password_hash($pw, PASSWORD_DEFAULT), $f['email'],
            $f['phone'], $f['first'], $f['last'], $channels,
        ]);
        if ($r === false) {
            $err = last_error();
        } else {
            flash('Η εγγραφή έγινε. Μπορείτε να συνδεθείτε.');
            redirect('index.php');
        }
    }
}

page_header('Εγγραφή καταναλωτή');
if ($err) {
    echo '<p class="error">' . h($err) . '</p>';
}
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Username <input name="username" value="<?= h($f['username']) ?>" required minlength="3" maxlength="50"></label>
  <label>Όνομα <input name="first" value="<?= h($f['first']) ?>" required maxlength="50"></label>
  <label>Επώνυμο <input name="last" value="<?= h($f['last']) ?>" required maxlength="50"></label>
  <label>Email <input name="email" type="email" value="<?= h($f['email']) ?>" required maxlength="254"></label>
  <label>Τηλέφωνο <input name="phone" value="<?= h($f['phone']) ?>" maxlength="20" pattern="[0-9+ ]*"></label>
  <fieldset><legend>Ειδοποιήσεις με</legend>
    <label class="inline"><input type="checkbox" name="channels[]" value="Email" checked> Email</label>
    <label class="inline"><input type="checkbox" name="channels[]" value="SMS"> SMS</label>
  </fieldset>
  <label>Κωδικός <input name="password" type="password" required minlength="8"></label>
  <label>Ξανά ο κωδικός <input name="password2" type="password" required minlength="8"></label>
  <button type="submit">Εγγραφή</button>
</form>
<p><a href="index.php">Πίσω στη σύνδεση</a></p>
<?php page_footer();
