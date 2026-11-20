<?php
// =====================================================================
// index.php : η πρώτη σελίδα. Φόρμα login με το username του MDMS-Cy
// (ΟΧΙ το SQL login του τμήματος, αυτό είναι κρυμμένο στο config.php).
// Η φόρμα στέλνει στο login.php.
// =====================================================================
require_once __DIR__ . '/layout.php';
if (current_user()) {
    redirect('home.php');
}
page_header('Σύνδεση');
?>
<form method="post" action="login.php" class="box">
  <?= csrf_field() ?>
  <label>Username <input name="username" required autofocus maxlength="50"></label>
  <label>Κωδικός <input name="password" type="password" required></label>
  <button type="submit">Σύνδεση</button>
</form>
<p>Δεν έχετε λογαριασμό;
  <a href="register_consumer.php">Εγγραφή καταναλωτή</a>
  <?php if (is_file(__DIR__ . '/register_technician.php')): ?>
    · <a href="register_technician.php">Εγγραφή τεχνικού</a>
  <?php endif; ?>
</p>
<?php page_footer();
