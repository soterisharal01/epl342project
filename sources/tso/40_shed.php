<?php // MENU: Load shedding
// =====================================================================
// tso/40_shed.php : εντολή αποκοπής φορτίου σε όλους τους ενεργούς μετρητές κάτω από έναν μετασχηματιστή.
// Η εντολή και οι εντολές προς τους μετρητές γράφονται σε μία συναλλαγή (ή καθόλου).
// Procedures: sp_tso_tree (επιλογή κόμβου), sp_tso_load_shed, sp_tso_list_shed_orders
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('TSO');

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'shed') {
    check_csrf();
    if (($_POST['confirm'] ?? '') !== '1') {
        flash('Επιβεβαίωσε την αποκοπή για να συνεχίσεις.', 'error');
    } else {
        $r = call_proc('sp_tso_load_shed', [uid(), (int)($_POST['tid'] ?? 0), trim($_POST['reason'] ?? '')]);
        if ($r === false) {
            flash(last_error(), 'error');
        } else {
            flash('Εντολή #' . ($r[0]['ShedOrderID'] ?? '') . ': στάλθηκαν ' . ($r[0]['CommandCount'] ?? 0) . ' εντολές αποκοπής.');
        }
    }
    redirect('tso/40_shed.php');
}

page_header('Load shedding');
$tree = call_proc('sp_tso_tree', [uid()]);
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="shed">
  <p><strong>Προσοχή:</strong> η εντολή στέλνεται σε ΟΛΟΥΣ τους ενεργούς μετρητές κάτω από τον επιλεγμένο μετασχηματιστή.</p>
  <label>Μετασχηματιστής
    <select name="tid" required>
      <?php foreach ($tree ?: [] as $t): ?>
        <option value="<?= h($t['TransformerID']) ?>"><?= str_repeat('&nbsp;&nbsp;', (int)$t['Level']) . h($t['Name']) ?> (μετρητές: <?= h($t['TotalMeters']) ?>)</option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>Αιτιολογία <textarea name="reason" required maxlength="500" rows="3"></textarea></label>
  <label><input type="checkbox" name="confirm" value="1"> Επιβεβαιώνω την αποκοπή φορτίου</label>
  <button type="submit">Αποστολή εντολής</button>
</form>

<h2>Εντολές αποκοπής</h2>
<?php
$orders = call_proc('sp_tso_list_shed_orders', [uid()]);
print_table($orders, [
    'ShedOrderID' => '#', 'CreatedAt' => 'Δημιουργία (UTC)', 'Status' => 'Κατάσταση', 'Reason' => 'Αιτιολογία',
    'TransformerID' => 'Κωδ. μετασχ.', 'TransformerName' => 'Μετασχηματιστής', 'OrderedByName' => 'Από',
    'Commands' => 'Εντολές', 'AwaitingApproval' => 'Αναμονή έγκρισης', 'Sent' => 'Στάλθηκαν',
    'Acknowledged' => 'Επιβεβαιώθηκαν', 'Failed' => 'Απέτυχαν', 'Cancelled' => 'Ακυρώθηκαν',
]);
page_footer();
