<?php // MENU: Επιβεβαίωση μετρητών
// =====================================================================
// operator/tec_30_meters.php : ΙΙΙ.2.3 ο Operator ελέγχει και επιβεβαιώνει νέους/αντικατασταθέντες μετρητές.
// Μόνο μετά την επιβεβαίωση (και τα 3 έγγραφα) ο μετρητής γίνεται Active.
// Procedures: sp_operator_list_pending_meters, sp_operator_list_meter_documents, sp_operator_confirm_meter
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Operator');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $approve = ($_POST['decision'] ?? '') === 'approve' ? 1 : 0;
    $r = call_proc('sp_operator_confirm_meter', [uid(), (int)($_POST['installation'] ?? 0), $approve, post_or_null('comment')]);
    if ($r === false) {
        if (last_error() !== null) { flash(last_error(), 'error'); }
    } else {
        flash($approve ? 'Ο μετρητής επιβεβαιώθηκε και είναι Active.' : 'Η εγκατάσταση απορρίφθηκε.');
    }
    redirect('operator/tec_30_meters.php');
}

page_header('Επιβεβαίωση μετρητών');
$rows = call_proc('sp_operator_list_pending_meters', [uid()]);
if ($rows === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$rows) {
    echo '<p class="muted">Δεν υπάρχουν εγκαταστάσεις σε αναμονή.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Serial</th><th>Network ID</th><th>Firmware</th><th>Amps</th><th>Θέση</th>'
       . '<th>Μετασχηματιστής</th><th>Υποστατικό</th><th>Εργασία</th><th>Τεχνικός</th><th>Εγκαταστάθηκε</th>'
       . '<th>Έγγραφα (από 3)</th><th>Φωτογραφίες</th><th></th></tr>';
    foreach ($rows as $m) {
        echo '<tr><td>' . h($m['InstallationID']) . '</td><td>' . h($m['SerialNumber']) . '</td><td>' . h($m['NetworkID'])
           . '</td><td>' . h($m['Firmware']) . '</td><td>' . h($m['MaxLoadAmps'])
           . '</td><td>' . h($m['Latitude'] . ', ' . $m['Longitude']) . '</td><td>' . h($m['TransformerID'])
           . '</td><td>' . h($m['PremiseID'] . ' ' . $m['Address']) . '</td><td>' . h($m['TaskType'])
           . '</td><td>' . h($m['TechnicianUsername']) . '</td><td>' . h($m['InstalledAt'])
           . '</td><td>' . h($m['DocTypesPresent']) . '</td><td>' . h($m['Photos']) . '</td><td>'
           . '<a href="?meter=' . h($m['MeterID']) . '">Έγγραφα</a>'
           . '<form method="post">' . csrf_field()
           . '<input type="hidden" name="installation" value="' . h($m['InstallationID']) . '">'
           . '<input name="comment" placeholder="Σχόλιο (υποχρεωτικό στην απόρριψη)" maxlength="500">'
           . '<button name="decision" value="approve">Επιβεβαίωση</button>'
           . '<button name="decision" value="reject" class="danger">Απόρριψη</button></form></td></tr>';
    }
    echo '</table>';
}
$sel = (int)($_GET['meter'] ?? 0);
if ($sel > 0) {
    echo '<h3>Έγγραφα του μετρητή ' . h($sel) . '</h3>';
    print_table(call_proc('sp_operator_list_meter_documents', [uid(), $sel]),
        ['DocumentID' => '#', 'DocType' => 'Τύπος', 'DocNumber' => 'Κωδικός', 'IssueDate' => 'Έκδοση', 'ExpiryDate' => 'Λήξη',
         'FilePath' => 'Αρχείο', 'ReviewStatus' => 'Έλεγχος', 'ReviewComment' => 'Σχόλιο', 'ReviewedAt' => 'Πότε']);
}
page_footer();
