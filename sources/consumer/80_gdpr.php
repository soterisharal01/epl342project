<?php // MENU: Δικαίωμα στη λήθη
// =====================================================================
// consumer/80_gdpr.php : ΙΙΙ.1.4 αίτημα διαγραφής προσωπικών δεδομένων (GDPR).
// Procedures: sp_gdpr_submit, sp_gdpr_list
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    if (empty($_POST['confirm'])) {
        flash('Επιβεβαιώστε με το τετραγωνάκι ότι κατανοείτε τις συνέπειες.', 'error');
    } else {
        $r = call_proc('sp_gdpr_submit', [uid()]);
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
<p>Μπορείτε να ζητήσετε τη διαγραφή των προσωπικών σας δεδομένων. Το αίτημα δεν εκτελείται αμέσως: το εξετάζει και το
   προεγκρίνει ένας Operator, το εγκρίνει ο Admin και μετά εφαρμόζεται.</p>
<p>Διαγράφονται ή ανωνυμοποιούνται: το όνομα, το email, το τηλέφωνο, οι τραπεζικοί λογαριασμοί, τα κανάλια ειδοποίησης
   και τα όρια κατανάλωσης. Τα τιμολόγια και οι πληρωμές <strong>διατηρούνται</strong> βάσει νόμου. Οι ωμές μετρήσεις
   σας κρατιούνται πλέον μόνο 1 μήνα (αντί για 36) και μετά διαγράφονται αυτόματα.</p>
<p><strong>Όταν το αίτημα εφαρμοστεί, ο λογαριασμός απενεργοποιείται και δεν θα μπορείτε πλέον να συνδεθείτε.</strong></p>
<?php if ($open): ?>
<p class="muted">Έχετε ήδη ανοιχτό αίτημα. Δείτε την πορεία του παρακάτω.</p>
<?php else: ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label><input type="checkbox" name="confirm" value="1" required>
    Κατανοώ ότι μετά την εφαρμογή δεν θα μπορώ να συνδεθώ και ότι τα δεδομένα δεν επανέρχονται.</label>
  <button type="submit">Υποβολή αιτήματος διαγραφής</button>
</form>
<?php endif; ?>
<h2>Τα αιτήματά μου</h2>
<?php
$cols = [
    'GdprRequestID' => '#', 'SubmittedAt' => 'Υποβλήθηκε', 'Status' => 'Κατάσταση', 'PreApprovedAt' => 'Εξετάστηκε (Operator)',
    'DecidedAt' => 'Απόφαση Admin', 'AppliedAt' => 'Εφαρμόστηκε',
];
print_table($rows === false ? false : array_map(fn($q) => array_intersect_key(array_replace($cols, $q), $cols), $rows), $cols);
page_footer();
