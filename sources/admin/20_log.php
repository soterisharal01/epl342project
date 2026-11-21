<?php // MENU: Αρχείο καταγραφής
// =====================================================================
// admin/20_log.php : το αρχείο καταγραφής (AUDIT_LOG), μόνο ανάγνωση (ADM-4 για ADM-2).
// Φίλτρα: τύπος αντικειμένου και ημερομηνίες. Procedure: sp_admin_audit_log
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Admin');

$types = ['USER_ACCOUNT', 'METER_MODEL', 'SERVICE_TYPE', 'TARIFF_TYPE', 'METER_INSTALLATION', 'METER',
          'DOCUMENT', 'CONSENT', 'SUPPLY_CONTRACT', 'SERVICE_PURCHASE', 'PAYMENT'];
$type = trim((string)($_GET['type'] ?? ''));
if ($type !== '' && !preg_match('/^[A-Z_]{1,30}$/', $type)) { $type = ''; }
$date = function (string $k) {
    $v = trim((string)($_GET[$k] ?? ''));
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : null;
};
$from = $date('from');
$to = $date('to');

page_header('Αρχείο καταγραφής');
$opts = array_map(fn($t) => ['t' => $t], $types);
if ($type !== '' && !in_array($type, $types, true)) { $opts[] = ['t' => $type]; }
?>
<form method="get" class="inline-form">
  <label>Τύπος αντικειμένου
    <select name="type"><?= select_options($opts, 't', 't', $type, 'Όλοι') ?></select></label>
  <label>Από <input type="date" name="from" value="<?= h($from) ?>"></label>
  <label>Έως <input type="date" name="to" value="<?= h($to) ?>"></label>
  <button type="submit">Φίλτρο</button>
</form>
<p class="muted">Τα 500 πιο πρόσφατα γεγονότα, νεότερα πρώτα.</p>
<?php
$rows = call_proc('sp_admin_audit_log', [uid(), $type === '' ? null : $type, $from, $to]);
print_table($rows, [
    'LogID' => '#', 'LoggedAt' => 'Ώρα (UTC)', 'ObjectType' => 'Αντικείμενο', 'ObjectID' => 'Κωδικός',
    'Action' => 'Ενέργεια', 'OldState' => 'Πριν', 'NewState' => 'Μετά', 'ResultComment' => 'Σχόλιο',
    'PerformedBy' => 'UserID', 'PerformedByUsername' => 'Χρήστης', 'ActorMechanism' => 'Μηχανισμός',
]);
page_footer();
