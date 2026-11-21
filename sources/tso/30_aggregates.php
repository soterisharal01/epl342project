<?php // MENU: Aggregates δικτύου
// =====================================================================
// tso/30_aggregates.php : aggregates σε οποιοδήποτε επίπεδο του δέντρου.
// Τα φύλλα έχουν αποθηκευμένα aggregates, τα ανώτερα επίπεδα υπολογίζονται εδώ (μήνας -> τρίμηνο -> έτος).
// Procedures: sp_tso_tree (λίστα κόμβων), sp_tso_aggregates
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('TSO');

$types = ['Day' => 'Ημέρα', 'Month' => 'Μήνας', 'Quarter' => 'Τρίμηνο', 'Year' => 'Έτος'];
$tree = call_proc('sp_tso_tree', [uid()]);

$tid   = trim($_GET['tid'] ?? '');
$ptype = $_GET['ptype'] ?? 'Day';
$from  = trim($_GET['from'] ?? '');
$to    = trim($_GET['to'] ?? '');

page_header('Aggregates δικτύου');
?>
<form method="get" class="box">
  <label>Μετασχηματιστής
    <select name="tid" required>
      <?php foreach ($tree ?: [] as $t): ?>
        <option value="<?= h($t['TransformerID']) ?>"<?= (string)$t['TransformerID'] === $tid ? ' selected' : '' ?>><?= str_repeat('&nbsp;&nbsp;', (int)$t['Level']) . h($t['Name']) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>Περίοδος
    <select name="ptype">
      <?php foreach ($types as $k => $label): ?>
        <option value="<?= h($k) ?>"<?= $k === $ptype ? ' selected' : '' ?>><?= h($label) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>Από <input type="date" name="from" required value="<?= h($from) ?>"></label>
  <label>Έως <input type="date" name="to" required value="<?= h($to) ?>"></label>
  <button type="submit">Εμφάνιση</button>
</form>
<p class="muted">Για μήνα, τρίμηνο και έτος οι περίοδοι λαμβάνονται ολόκληρες (το διάστημα επεκτείνεται στην αρχή και το τέλος τους).</p>
<?php
if ($tid !== '' && $from !== '' && $to !== '' && isset($types[$ptype])) {
    $rows = call_proc('sp_tso_aggregates', [uid(), (int)$tid, $ptype, $from, $to]);
    if ($rows === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } else {
        print_table($rows, ['PeriodStart' => 'Αρχή περιόδου', 'ImportKWh' => 'Εισαγωγή kWh (1.8.0)',
                            'ExportKWh' => 'Εξαγωγή kWh (2.8.0)', 'NetKWh' => 'Καθαρό kWh', 'LeafCount' => 'Φύλλα']);
    }
}
page_footer();
