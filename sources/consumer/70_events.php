<?php // MENU: Συμβάντα ποιότητας
// =====================================================================
// consumer/70_events.php : ΙΙΙ.1.2 συμβάντα (π.χ. υπόταση/υπέρταση) στους μετρητές μου.
// Procedure: sp_consumer_quality_events
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

page_header('Συμβάντα ποιότητας');
$dateOk = fn($v) => preg_match('/^\d{4}-\d{2}-\d{2}$/', (string)$v) === 1;
$from = $dateOk($_GET['from'] ?? '') ? $_GET['from'] : '';
$to   = $dateOk($_GET['to'] ?? '') ? $_GET['to'] : '';
?>
<form method="get" class="inline-form">
  Από <input type="date" name="from" value="<?= h($from) ?>">
  Έως (και αυτή η ημέρα) <input type="date" name="to" value="<?= h($to) ?>">
  <button type="submit">Εμφάνιση</button>
</form>
<p class="muted">Συμβάντα των μετρητών σας, τα νεότερα πρώτα. Ώρες σε UTC.</p>
<?php
$rows = call_proc('sp_consumer_quality_events', [
    uid(),
    $from === '' ? null : $from . ' 00:00:00',
    $to === '' ? null : date('Y-m-d', strtotime($to . ' +1 day')) . ' 00:00:00',
]);
print_table($rows, ['EventID' => '#', 'EventType' => 'Τύπος', 'Severity' => 'Σοβαρότητα', 'Description' => 'Περιγραφή',
    'OccurredAt' => 'Πότε', 'Status' => 'Κατάσταση', 'MeterID' => 'Μετρητής #', 'SerialNumber' => 'Σειριακός',
    'PremiseID' => 'Υποστατικό #', 'Address' => 'Διεύθυνση']);
page_footer();
