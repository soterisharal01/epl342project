<?php // MENU: Συμβάντα δικτύου
// =====================================================================
// dso/40_events.php : ΙΙ.Γ αναλυτικά δικτύου (υπό/υπέρταση, ανισορροπία φάσεων, ύποπτη κλοπή) και τεχνικές απώλειες.
//  1. Φόρμα ανίχνευσης για περίοδο (sp_dso_detect_events), οι κανόνες περιγράφονται στο procedure
//  2. Λίστα συμβάντων με φίλτρα (sp_dso_list_events)
//  3. Αναφορά απωλειών (sp_dso_losses_report)
// Όλες οι ώρες είναι UTC.
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('DSO');

function ev_dt($v)
{
    $v = trim((string)$v);
    if (!preg_match('/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(:\d{2})?$/', $v, $m)) {
        return null;
    }
    return $m[1] . ' ' . $m[2] . ':00';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $from = ev_dt($_POST['from'] ?? '');
    $to   = ev_dt($_POST['to'] ?? '');
    if ($from === null || $to === null) {
        flash('Δώστε έγκυρη αρχή και τέλος περιόδου.', 'error');
    } else {
        $r = call_proc('sp_dso_detect_events', [uid(), $from, $to]);
        if ($r === false) {
            flash(last_error(), 'error');
        } else {
            $x = $r[0];
            flash('Νέα συμβάντα: υπόταση ' . (int)$x['Undervoltage'] . ', υπέρταση ' . (int)$x['Overvoltage']
                . ', ανισορροπία ' . (int)$x['PhaseUnbalance'] . ', ύποπτη κλοπή ' . (int)$x['SuspectedTheft']
                . ' (σύνολο ' . (int)$x['Total'] . ').');
        }
    }
    redirect('dso/40_events.php');              // Post/Redirect/Get: όχι διπλό submit με F5
}

page_header('Συμβάντα δικτύου');
$today  = gmdate('Y-m-d');
$status = in_array($_GET['status'] ?? '', ['Open', 'In progress', 'Closed'], true) ? $_GET['status'] : null;
$types  = ['Undervoltage', 'Overvoltage', 'Phase unbalance', 'Suspected theft', 'Suspect reading', 'Unmatched packet',
           'Communication problem', 'Tamper finding'];
$type   = in_array($_GET['type'] ?? '', $types, true) ? $_GET['type'] : null;
?>
<h2>Ανίχνευση συμβάντων</h2>
<p class="muted">Κανόνες (επάνω σε επικυρωμένες μετρήσεις): τάση εκτός ζώνης VEE (207-253 V), ανισορροπία ρευμάτων φάσεων &gt; 25%,
  ύποπτη κλοπή = τουλάχιστον 8 συνεχόμενα 15λεπτα μηδενικής κατανάλωσης ενώ οι υπόλοιποι μετρητές του μετασχηματιστή καταναλώνουν.
  Δεν διπλογράφονται συμβάντα.</p>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Από (UTC) <input type="datetime-local" name="from" value="<?= h($today) ?>T00:00" required></label>
  <label>Έως (UTC, μη συμπεριλαμβανόμενο) <input type="datetime-local" name="to" value="<?= h($today) ?>T23:59" required></label>
  <button type="submit">Ανίχνευση</button>
</form>

<h2>Συμβάντα</h2>
<form method="get" class="box">
  <label>Κατάσταση
    <select name="status">
      <option value="">Όλες</option>
      <?php foreach (['Open', 'In progress', 'Closed'] as $s) { ?>
        <option value="<?= h($s) ?>"<?= $s === $status ? ' selected' : '' ?>><?= h($s) ?></option>
      <?php } ?>
    </select>
  </label>
  <label>Τύπος
    <select name="type">
      <option value="">Όλοι</option>
      <?php foreach ($types as $t) { ?>
        <option value="<?= h($t) ?>"<?= $t === $type ? ' selected' : '' ?>><?= h($t) ?></option>
      <?php } ?>
    </select>
  </label>
  <button type="submit">Εμφάνιση</button>
</form>
<?php
print_table(call_proc('sp_dso_list_events', [uid(), $status, $type]), [
    'EventID' => '#', 'EventType' => 'Τύπος', 'Severity' => 'Σοβαρότητα', 'Description' => 'Περιγραφή',
    'OccurredAt' => 'Πότε (UTC)', 'Status' => 'Κατάσταση', 'MeterID' => 'Μετρητής', 'SerialNumber' => 'Σειριακός',
    'PacketID' => 'Πακέτο', 'TaskID' => 'Εργασία',
]);
?>
<h2>Αναφορά τεχνικών απωλειών (τελευταίες 7 ημέρες)</h2>
<p class="muted">Σύγκριση του aggregate κάθε φύλλου με το άθροισμα των μετρητών του. Διαφορά ≠ 0 ή λιγότεροι μετρητές με δεδομένα από τους
  ενεργούς δείχνει ασυμφωνία δεδομένων. Το σχήμα δεν έχει ανεξάρτητη μέτρηση στον μετασχηματιστή.</p>
<?php
print_table(call_proc('sp_dso_losses_report', [uid(), gmdate('Y-m-d', time() - 7 * 86400), $today]), [
    'TransformerID' => 'Μετασχηματιστής', 'Name' => 'Όνομα', 'ObisCode' => 'OBIS', 'PeriodStart' => 'Ημέρα',
    'TransformerSum' => 'Μετασχηματιστής (kWh)', 'MetersSum' => 'Μετρητές (kWh)', 'Difference' => 'Διαφορά',
    'DifferencePct' => 'Διαφορά %', 'MeterCount' => 'Μετρητές στο aggregate', 'MetersWithData' => 'Μετρητές με δεδομένα',
    'ActiveMeters' => 'Ενεργοί μετρητές',
]);
page_footer();
