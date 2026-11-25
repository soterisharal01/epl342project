<?php // MENU: Δικαίωμα στη λήθη
// =====================================================================
// consumer/80_gdpr.php : ΙΙΙ.1.4 αίτημα GDPR: διαγραφή (δικαίωμα στη λήθη) ή μείωση διατήρησης σε 1 μήνα.
// Procedures: sp_gdpr_submit, sp_gdpr_list
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $type = ($_POST['type'] ?? '') === 'Retention' ? 'Retention' : 'Erasure';
    if (empty($_POST['confirm'])) {
        flash('Επιβεβαιώστε με το τετραγωνάκι ότι κατανοείτε τις συνέπειες.', 'error');
    } else {
        $r = call_proc('sp_gdpr_submit', [uid(), $type]);
        if ($r === false) {
            flash(last_error(), 'error');
        } else {
            flash('Το αίτημά σας υποβλήθηκε (αριθμός ' . (int)$r[0]['GdprRequestID'] . ').');
        }
    }
    redirect('consumer/80_gdpr.php');
}

page_header('Δικαίωμα στη λήθη');
$rows = call_proc('sp_gdpr_list', [uid(), null]);
$open = false;
foreach ($rows ?: [] as $q) {
    if (in_array($q['Status'], ['Submitted', 'Under review', 'Pre-approved', 'Approved'], true)) {
        $open = true;
    }
}
?>
<p>Υπάρχουν δύο είδη αιτήματος. Κανένα δεν εκτελείται αμέσως: το εξετάζει και το προεγκρίνει ένας Operator,
   το εγκρίνει ο Admin και μετά εφαρμόζεται.</p>
<ul>
  <li><strong>Μείωση διατήρησης σε 1 μήνα:</strong> ο λογαριασμός σας μένει ενεργός. Οι αναλυτικές 15λεπτες μετρήσεις σας
      κρατιούνται μόνο 1 μήνα (αντί για 36) και οι παλαιότερες διαγράφονται αυτόματα. Τα ημερήσια/μηνιαία αθροίσματα μένουν.</li>
  <li><strong>Διαγραφή (δικαίωμα στη λήθη):</strong> διαγράφονται ή ανωνυμοποιούνται το όνομα, το email, το τηλέφωνο,
      οι τραπεζικοί λογαριασμοί, τα κανάλια ειδοποίησης και τα όρια κατανάλωσης. Οι ωμές μετρήσεις κρατιούνται 1 μήνα.
      Τα τιμολόγια και οι πληρωμές <strong>διατηρούνται</strong> βάσει νόμου.
      <strong>Ο λογαριασμός απενεργοποιείται και δεν θα μπορείτε πλέον να συνδεθείτε.</strong></li>
</ul>
<?php if ($open): ?>
<p class="muted">Έχετε ήδη ανοιχτό αίτημα. Δείτε την πορεία του παρακάτω.</p>
<?php else: ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label><input type="radio" name="type" value="Retention" checked> Μείωση διατήρησης σε 1 μήνα (κρατώ τον λογαριασμό)</label>
  <label><input type="radio" name="type" value="Erasure"> Διαγραφή (δικαίωμα στη λήθη, ο λογαριασμός κλείνει)</label>
  <label><input type="checkbox" name="confirm" value="1" required>
    Κατανοώ ότι οι μετρήσεις που θα σβηστούν δεν επανέρχονται (και, για διαγραφή, ότι δεν θα μπορώ να συνδεθώ).</label>
  <button type="submit">Υποβολή αιτήματος</button>
</form>
<?php endif; ?>
<h2>Τα αιτήματά μου</h2>
<?php
$cols = [
    'GdprRequestID' => '#', 'RequestType' => 'Είδος', 'SubmittedAt' => 'Υποβλήθηκε', 'Status' => 'Κατάσταση', 'PreApprovedAt' => 'Εξετάστηκε (Operator)',
    'DecidedAt' => 'Απόφαση Admin', 'AppliedAt' => 'Εφαρμόστηκε',
];
print_table($rows === false ? false : array_map(fn($q) => array_intersect_key(array_replace($cols, $q), $cols), $rows), $cols);
page_footer();
