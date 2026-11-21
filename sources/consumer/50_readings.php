<?php // MENU: Μετρήσεις
// =====================================================================
// consumer/50_readings.php : ΙΙΙ.1.2 σειρά 15λέπτου των μετρητών μου, αγορά ιστορικού
// και ιστορικό ανά ημέρα / μήνα / έτος (από τα αθροίσματα, δωρεάν).
// Procedures: sp_consumer_list_meters, sp_consumer_readings, sp_consumer_history,
//             sp_consumer_buy_history, sp_consumer_list_purchases
// Ο τρέχων μήνας είναι δωρεάν· παλιότεροι μήνες θέλουν αγορά (και να είναι μέσα στη διατήρηση).
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

// --- Αγορά ιστορικού (POST) ---
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $mf = trim((string)($_POST['month_from'] ?? ''));   // "YYYY-MM" από το <input type="month">
    $mt = trim((string)($_POST['month_to'] ?? ''));
    $r = call_proc('sp_consumer_buy_history', [
        uid(), (int)($_POST['premise'] ?? 0),
        $mf === '' ? null : $mf . '-01', $mt === '' ? null : $mt . '-01',
    ]);
    if ($r === false) {
        flash(last_error(), 'error');
    } else {
        flash('Η αγορά καταχωρήθηκε: τιμολόγιο #' . $r[0]['InvoiceID'] . ', ποσό ' . money($r[0]['Amount']) . ' €.');
    }
    redirect('consumer/50_readings.php');
}

// --- Εμφάνιση ---
page_header('Μετρήσεις');
$meters = call_proc('sp_consumer_list_meters', [uid()]) ?: [];
if (!$meters) {
    echo '<p class="muted">Δεν έχετε εγκατεστημένο μετρητή στα υποστατικά σας.</p>';
    page_footer();
    return;
}
$meterId = (int)($_GET['meter'] ?? $meters[0]['MeterID']);
$from = preg_match('/^\d{4}-\d{2}-\d{2}$/', (string)($_GET['from'] ?? '')) ? $_GET['from'] : date('Y-m-d', strtotime('-1 day'));
$to   = preg_match('/^\d{4}-\d{2}-\d{2}$/', (string)($_GET['to'] ?? '')) ? $_GET['to'] : $from;
$ptype = in_array($_GET['ptype'] ?? '', ['Day', 'Month', 'Year'], true) ? $_GET['ptype'] : 'Day';

$meterOpts = [];
foreach ($meters as $m) {
    $meterOpts[] = ['MeterID' => $m['MeterID'], 'Label' => $m['Address'] . ' — μετρητής ' . $m['SerialNumber']];
}
?>
<form method="get" class="inline-form">
  Μετρητής <select name="meter"><?= select_options($meterOpts, 'MeterID', 'Label', $meterId) ?></select>
  Από <input type="date" name="from" value="<?= h($from) ?>" required>
  Έως (και αυτή η ημέρα) <input type="date" name="to" value="<?= h($to) ?>" required>
  Ιστορικό ανά
  <select name="ptype">
    <option value="Day"<?= $ptype === 'Day' ? ' selected' : '' ?>>Ημέρα</option>
    <option value="Month"<?= $ptype === 'Month' ? ' selected' : '' ?>>Μήνα</option>
    <option value="Year"<?= $ptype === 'Year' ? ' selected' : '' ?>>Έτος</option>
  </select>
  <button type="submit">Εμφάνιση</button>
</form>
<p class="muted">Σειρά 15λέπτου: μέχρι 31 ημέρες τη φορά. Ο τρέχων μήνας είναι δωρεάν· παλιότεροι μήνες θέλουν αγορά ιστορικού.</p>

<h2>Μετρήσεις 15 λεπτών</h2>
<?php
if (isset($_GET['meter'])) {
    $toExcl = date('Y-m-d', strtotime($to . ' +1 day'));   // το procedure παίρνει το τέλος ως αποκλειόμενο
    $rows = call_proc('sp_consumer_readings', [uid(), $meterId, $from . ' 00:00:00', $toExcl . ' 00:00:00']);
    if ($rows === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } elseif (!$rows) {
        echo '<p class="muted">Δεν υπάρχουν μετρήσεις στο διάστημα.</p>';
    } else {
        $hasExport = false;
        foreach ($rows as $r) { if ($r['ExportKWh'] !== null) { $hasExport = true; break; } }
        echo '<table class="data"><tr><th>Διάστημα</th><th>Εισαγωγή kWh</th>' . ($hasExport ? '<th>Εξαγωγή kWh</th>' : '')
           . '<th>Τάση L1 V</th><th>Ποιότητα</th></tr>';
        foreach ($rows as $r) {
            echo '<tr><td>' . h($r['IntervalStart']) . '</td><td>' . h($r['ImportKWh'] ?? '')
               . '</td>' . ($hasExport ? '<td>' . h($r['ExportKWh'] ?? '') . '</td>' : '')
               . '<td>' . h($r['VoltageL1'] ?? '') . '</td><td>' . h($r['Quality']) . '</td></tr>';
        }
        echo '</table>';
    }

    echo '<h2>Ιστορικό (αθροίσματα)</h2>';
    print_table(call_proc('sp_consumer_history', [uid(), $meterId, $ptype, $from, $to]),
        ['PeriodStart' => 'Περίοδος', 'ImportKWh' => 'Εισαγωγή kWh', 'ExportKWh' => 'Εξαγωγή kWh',
         'NetKWh' => 'Καθαρό kWh', 'EstimatedCount' => 'Εκτιμώμενες']);
}
?>
<h2>Αγορά ιστορικού</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Υποστατικό
    <select name="premise"><?= select_options($meters, 'PremiseID', 'Address') ?></select></label>
  <label>Από μήνα <input type="month" name="month_from" required></label>
  <label>Έως μήνα <input type="month" name="month_to" required></label>
  <button type="submit">Αγορά</button>
  <p class="muted">Χρέωση ανά μήνα· εκδίδεται τιμολόγιο που πληρώνετε από τα «Τιμολόγια και πληρωμές».</p>
</form>

<h2>Οι αγορές μου</h2>
<?php
print_table(call_proc('sp_consumer_list_purchases', [uid()]),
    ['PurchaseID' => '#', 'PurchasedAt' => 'Ημερομηνία', 'Address' => 'Υποστατικό', 'MonthFrom' => 'Από μήνα',
     'MonthTo' => 'Έως μήνα', 'Amount' => 'Ποσό €', 'InvoiceID' => 'Τιμολόγιο', 'InvoiceStatus' => 'Κατάσταση']);
page_footer();
