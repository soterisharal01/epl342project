<?php // MENU: Αιτήματα GDPR
// =====================================================================
// admin/gdp_10_decide.php : ΙΙΙ.1.4 τελική απόφαση και εφαρμογή αιτημάτων διαγραφής.
// Procedures: sp_gdpr_list, sp_gdpr_decide, sp_gdpr_apply
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Admin');

$statuses = ['Submitted', 'Under review', 'Pre-approved', 'Approved', 'Rejected', 'Applied'];
$filter = isset($_GET['status']) && in_array($_GET['status'], $statuses, true) ? $_GET['status'] : null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $id = (int)($_POST['id'] ?? 0);
    $act = (string)($_POST['action'] ?? '');
    if ($act === 'approve' || $act === 'reject') {
        $r = call_proc('sp_gdpr_decide', [uid(), $id, $act === 'approve' ? 1 : 0, post_or_null('comment')]);
        if ($r === false) {
            flash(last_error(), 'error');
        } else {
            flash($act === 'approve' ? 'Το αίτημα ' . $id . ' εγκρίθηκε.' : 'Το αίτημα ' . $id . ' απορρίφθηκε.');
        }
    } elseif ($act === 'apply') {
        if (empty($_POST['confirm'])) {
            flash('Επιβεβαιώστε την εφαρμογή με το τετραγωνάκι.', 'error');
        } else {
            $r = call_proc('sp_gdpr_apply', [uid(), $id]);
            if ($r === false) {
                flash(last_error(), 'error');
            } else {
                $x = $r[0];
                $purged = $x['RawPurged'] === null ? 'η αυτόματη εκκαθάριση δεν έτρεξε τώρα (τρέχει άλλη), πατήστε «Διατήρηση δεδομένων»'
                    : 'αυτόματη εκκαθάριση: ωμές ' . $x['RawPurged'] . ', επικυρωμένες ' . $x['ValidatedPurged'];
                if (($x['RequestType'] ?? '') === 'Retention') {
                    flash('Το αίτημα ' . $id . ' εφαρμόστηκε: η διατήρηση των ωμών μετρήσεων του χρήστη '
                        . $x['ConsumerID'] . ' είναι πλέον 1 μήνας (ο λογαριασμός μένει ενεργός); ' . $purged . '.');
                } else
                flash('Το αίτημα ' . $id . ' εφαρμόστηκε. Ανωνυμοποιήθηκε ο χρήστης ' . $x['AnonymisedUsername']
                    . '. Διαγράφηκαν: κανάλια ' . $x['ChannelsDeleted'] . ', τραπεζικοί λογαριασμοί ' . $x['BankAccountsDeleted']
                    . ' (συνδέσεις ' . $x['AccountForDeleted'] . '); απενεργοποιήθηκαν όρια ' . $x['ThresholdsDeactivated']
                    . '; αποσυνδέθηκαν πληρωμές ' . $x['PaymentsDetached'] . '. Διατηρήθηκαν: τιμολόγια ' . $x['InvoicesKept']
                    . ', πληρωμές ' . $x['PaymentsKept'] . ', κατοχές ' . $x['HoldingsKept']
                    . '. Διατήρηση ωμών μετρήσεων: ' . $x['RawRetentionMonths'] . ' μήνας; ' . $purged . '.');
            }
        }
    } else {
        flash('Άγνωστη ενέργεια.', 'error');
    }
    redirect('admin/gdp_10_decide.php' . ($filter ? '?status=' . urlencode($filter) : ''));
}

page_header('Αιτήματα GDPR');
?>
<p>Ο Admin αποφασίζει μόνο για αιτήματα που έχουν προεγκριθεί από Operator. Η εφαρμογή μιας «Διαγραφής» ανωνυμοποιεί τον χρήστη
   οριστικά και διατηρεί τιμολόγια και πληρωμές· μιας «Διατήρησης 1 μήνα» αλλάζει μόνο τη διατήρηση. Και στα δύο οι παλιές
   μετρήσεις σβήνονται αυτόματα αμέσως. Η εκκαθάριση για όλους (π.χ. τα 3 χρόνια) είναι στη σελίδα
   <a href="gdp_retention.php">Διατήρηση δεδομένων</a>.</p>
<form method="get" class="inline-form">
  Κατάσταση
  <select name="status">
    <option value="">Όλες</option>
    <?php foreach ($statuses as $s): ?>
    <option value="<?= h($s) ?>"<?= $s === $filter ? ' selected' : '' ?>><?= h($s) ?></option>
    <?php endforeach; ?>
  </select>
  <button type="submit">Φίλτρο</button>
</form>
<?php
$rows = call_proc('sp_gdpr_list', [uid(), $filter]);
if ($rows === false || !$rows) {
    print_table($rows);
} else {
    echo '<table class="data"><tr><th>#</th><th>Είδος</th><th>Υποβλήθηκε</th><th>Καταναλωτής</th><th>Κατάσταση</th><th>Προέγκριση από</th>'
       . '<th>Απόφαση</th><th>Εφαρμόστηκε</th><th>Ενέργεια</th></tr>';
    foreach ($rows as $q) {
        echo '<tr><td>' . h($q['GdprRequestID']) . '</td><td>'
           . h(($q['RequestType'] ?? 'Erasure') === 'Retention' ? 'Διατήρηση 1 μήνα' : 'Διαγραφή')
           . '</td><td>' . h($q['SubmittedAt']) . '</td><td>'
           . h($q['Username'] . ' (' . $q['FirstName'] . ' ' . $q['LastName'] . ')') . '</td><td>' . h($q['Status'])
           . '</td><td>' . h($q['PreApprovedByUsername'] ?? '') . ' ' . h($q['PreApprovedAt'] ?? '')
           . '</td><td>' . h($q['DecidedByUsername'] ?? '') . ' ' . h($q['DecidedAt'] ?? '')
           . '</td><td>' . h($q['AppliedAt'] ?? '') . '</td><td>';
        if ($q['Status'] === 'Pre-approved') {
            echo '<form method="post" class="inline-form">' . csrf_field()
               . '<input type="hidden" name="id" value="' . h($q['GdprRequestID']) . '">'
               . '<input name="comment" maxlength="500" placeholder="Σχόλιο">'
               . '<button name="action" value="approve">Έγκριση</button> '
               . '<button name="action" value="reject">Απόρριψη</button></form>';
        } elseif ($q['Status'] === 'Approved') {
            echo '<form method="post" class="inline-form">' . csrf_field()
               . '<input type="hidden" name="id" value="' . h($q['GdprRequestID']) . '">'
               . '<label><input type="checkbox" name="confirm" value="1" required> Επιβεβαιώνω: οριστική ανωνυμοποίηση</label> '
               . '<button name="action" value="apply">Εφαρμογή</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
}
page_footer();
