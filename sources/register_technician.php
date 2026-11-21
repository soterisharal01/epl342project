<?php
// =====================================================================
// register_technician.php : self-registration τεχνικού πεδίου (ΙΙΙ.2.1).
// Ο τεχνικός δεν κάνει τίποτα μέχρι να τον εγκρίνει ο Λειτουργός Συστήματος.
// Ο κωδικός γίνεται hash ΕΔΩ (password_hash) και στη βάση πάει μόνο το hash.
// Procedures: sp_ref_list_tech_categories, sp_auth_register_technician.
// =====================================================================
require_once __DIR__ . '/layout.php';

$f = ['username' => '', 'email' => '', 'phone' => '', 'first' => '', 'last' => '', 'birth' => '', 'photo' => ''];
$cats = call_proc('sp_ref_list_tech_categories');
if ($cats === false) {
    $cats = [];
}
$chosen = [];
$err = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    foreach ($f as $k => $_) {
        $f[$k] = trim((string)($_POST[$k] ?? ''));
    }
    $pw = (string)($_POST['password'] ?? '');
    $valid = array_map(fn($c) => (string)$c['CategoryID'], $cats);
    $chosen = array_values(array_intersect($valid, array_map('strval', (array)($_POST['categories'] ?? []))));
    if (strlen($pw) < 8) {
        $err = 'Ο κωδικός θέλει τουλάχιστον 8 χαρακτήρες.';
    } elseif ($pw !== ($_POST['password2'] ?? '')) {
        $err = 'Οι δύο κωδικοί δεν είναι ίδιοι.';
    } elseif (!$chosen) {
        $err = 'Διαλέξτε τουλάχιστον μία κατηγορία.';
    } else {
        $r = call_proc('sp_auth_register_technician', [
            $f['username'], password_hash($pw, PASSWORD_DEFAULT), $f['email'], $f['phone'],
            $f['first'], $f['last'], $f['birth'], $f['photo'], implode(',', $chosen),
        ]);
        if ($r === false) {
            $err = last_error();
        } else {
            flash('Η εγγραφή καταχωρήθηκε. Θα μπορείτε να συνδεθείτε αφού την εγκρίνει ο Λειτουργός Συστήματος.');
            redirect('index.php');
        }
    }
}

page_header('Εγγραφή τεχνικού');
if ($err) {
    echo '<p class="error">' . h($err) . '</p>';
}
?>
<p>Μετά την εγγραφή ο λογαριασμός περιμένει έγκριση από τον Λειτουργό Συστήματος. Μέχρι τότε δεν μπορείτε να συνδεθείτε.</p>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Username <input name="username" value="<?= h($f['username']) ?>" required minlength="3" maxlength="50"></label>
  <label>Όνομα <input name="first" value="<?= h($f['first']) ?>" required maxlength="50"></label>
  <label>Επώνυμο <input name="last" value="<?= h($f['last']) ?>" required maxlength="50"></label>
  <label>Email <input name="email" type="email" value="<?= h($f['email']) ?>" required maxlength="254"></label>
  <label>Τηλέφωνο <input name="phone" value="<?= h($f['phone']) ?>" maxlength="20" pattern="[0-9+ ]*"></label>
  <label>Ημερομηνία γέννησης <input name="birth" type="date" value="<?= h($f['birth']) ?>" required></label>
  <label>Φωτογραφία (διαδρομή αρχείου) <input name="photo" value="<?= h($f['photo']) ?>" required maxlength="400"></label>
  <fieldset><legend>Κατηγορίες (τουλάχιστον μία)</legend>
    <?php foreach ($cats as $c): ?>
      <label class="inline"><input type="checkbox" name="categories[]" value="<?= h($c['CategoryID']) ?>"<?= in_array((string)$c['CategoryID'], $chosen, true) ? ' checked' : '' ?>> <?= h($c['Label']) ?></label>
    <?php endforeach; ?>
  </fieldset>
  <label>Κωδικός <input name="password" type="password" required minlength="8"></label>
  <label>Ξανά ο κωδικός <input name="password2" type="password" required minlength="8"></label>
  <button type="submit">Εγγραφή</button>
</form>
<p><a href="index.php">Πίσω στη σύνδεση</a></p>
<?php page_footer();
