<?php // MENU: Αιτήματα ελέγχου / βλάβης
// =====================================================================
// consumer/30_requests.php : ΙΙΙ.1.3 αίτημα ελέγχου μετρητή ή αναφορά βλάβης,
// με την κατάσταση και το ιστορικό του (και την επίσκεψη τεχνικού, αν ανατέθηκε).
// Procedures: sp_consumer_list_requests, sp_consumer_submit_request,
//             sp_consumer_cancel_request, sp_consumer_list_meters, sp_consumer_list_premises
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    if (($_POST['action'] ?? '') === 'cancel') {
        $r = call_proc('sp_consumer_cancel_request', [uid(), (int)$_POST['request']]);
        $ok = 'Το αίτημα ακυρώθηκε.';
    } else {
        // Η επιλογή έρχεται ως "PremiseID:MeterID" (ο μετρητής είναι προαιρετικός).
        [$premise, $meter] = array_pad(explode(':', (string)($_POST['target'] ?? '')), 2, '');
        $r = call_proc('sp_consumer_submit_request', [
            uid(), (int)$premise, $meter === '' ? null : (int)$meter,
            $_POST['type'] ?? '', trim($_POST['description'] ?? ''),
        ]);
        $ok = 'Το αίτημα υποβλήθηκε. Θα ενημερωθείτε όταν ανατεθεί σε τεχνικό.';
    }
    $r === false ? flash(last_error(), 'error') : flash($ok);
    redirect('consumer/30_requests.php');
}

page_header('Αιτήματα ελέγχου / βλάβης');
$rows = call_proc('sp_consumer_list_requests', [uid()]);
if ($rows) {
    echo '<table class="data"><tr><th>#</th><th>Υποβολή</th><th>Είδος</th><th>Υποστατικό</th><th>Μετρητής</th>'
       . '<th>Περιγραφή</th><th>Κατάσταση</th><th>Επίσκεψη</th><th>Αποτέλεσμα</th><th></th></tr>';
    foreach ($rows as $r) {
        $visit = $r['VisitFrom'] ? $r['VisitFrom'] . ' – ' . substr((string)$r['VisitTo'], 11, 5) : '';
        echo '<tr><td>' . h($r['RequestID']) . '</td><td>' . h($r['SubmittedAt']) . '</td><td>' . h($r['RequestType'])
           . '</td><td>' . h($r['Address']) . '</td><td>' . h($r['Meter'] ?? '') . '</td><td>' . h($r['Description'])
           . '</td><td>' . h($r['Status']) . '</td><td>' . h($visit) . '</td><td>' . h($r['Result'] ?? '') . '</td><td>';
        if ($r['Status'] === 'Υποβλήθηκε') {
            echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="cancel">'
               . '<input type="hidden" name="request" value="' . h($r['RequestID']) . '"><button class="danger">Ακύρωση</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($rows);
}

// Λίστα επιλογής: κάθε μετρητής των υποστατικών μου, και κάθε υποστατικό χωρίς συγκεκριμένο μετρητή.
$targets = [];
foreach (call_proc('sp_consumer_list_meters', [uid()]) ?: [] as $m) {
    $targets[] = ['v' => $m['PremiseID'] . ':' . $m['MeterID'], 'l' => $m['Address'] . ' — μετρητής ' . $m['SerialNumber']];
}
foreach (call_proc('sp_consumer_list_premises', [uid()]) ?: [] as $p) {
    if ($p['EndDate'] === null) {
        $targets[] = ['v' => $p['PremiseID'] . ':', 'l' => $p['Address'] . ' — γενικά (χωρίς μετρητή)'];
    }
}
?>
<h2>Νέο αίτημα</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="submit">
  <label>Είδος
    <select name="type" required>
      <option value="Meter check">Έλεγχος μετρητή</option>
      <option value="Fault report">Αναφορά βλάβης</option>
    </select></label>
  <label>Για <select name="target" required><?= select_options($targets, 'v', 'l') ?></select></label>
  <label>Περιγραφή <textarea name="description" required minlength="5" maxlength="1000" rows="4"></textarea></label>
  <button type="submit">Υποβολή</button>
</form>
<?php page_footer();
