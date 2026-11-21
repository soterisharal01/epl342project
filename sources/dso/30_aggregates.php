<?php // MENU: Aggregates
// =====================================================================
// dso/30_aggregates.php : ΙΙΙ.3.2 aggregates μετά το VEE (ημέρα / μήνας / έτος).
//  1. Φόρμα: χτίσιμο aggregates για μία ημέρα (sp_dso_build_aggregates), προαιρετικά force μήνα/έτους
//  2. Κουμπί: όλες οι ημέρες που λείπουν (sp_dso_build_aggregates_pending)
//  3. Λίστες (sp_dso_list_aggregates, sp_dso_list_transformer_aggregates)
// Τα aggregates είναι τελικά: όσα υπάρχουν ήδη παραλείπονται, δεν ξαναϋπολογίζονται ποτέ.
// Όλες οι ώρες είναι UTC.
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('DSO');

function agg_date($v)
{
    $v = trim((string)$v);
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : null;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';
    if ($action === 'build') {
        $day = agg_date($_POST['day'] ?? '');
        if ($day === null) {
            flash('Δώστε έγκυρη ημέρα.', 'error');
        } else {
            $r = call_proc('sp_dso_build_aggregates', [
                uid(), $day, isset($_POST['force_month']) ? 1 : 0, isset($_POST['force_year']) ? 1 : 0,
            ]);
            if ($r === false) {
                flash(last_error(), 'error');
            } else {
                $x = $r[0];
                flash('Ημέρα ' . $day . ': νέες γραμμές μετρητών ' . (int)$x['MeterRows']
                    . ', μετασχηματιστών ' . (int)$x['TransformerRows'] . ', μήνα ' . (int)$x['MonthRows']
                    . ', έτους ' . (int)$x['YearRows'] . '.');
            }
        }
    } elseif ($action === 'pending') {
        $r = call_proc('sp_dso_build_aggregates_pending', [uid()]);
        if ($r === false) {
            flash(last_error(), 'error');
        } else {
            $x = $r[0];
            flash('Ημέρες που χτίστηκαν: ' . (int)$x['DaysBuilt'] . ', γραμμές μετρητών ' . (int)$x['MeterRows']
                . ', μετασχηματιστών ' . (int)$x['TransformerRows'] . '.');
        }
    }
    redirect('dso/30_aggregates.php');          // Post/Redirect/Get: όχι διπλό submit με F5
}

page_header('Aggregates');
$today = gmdate('Y-m-d');
$type  = in_array($_GET['type'] ?? 'Day', ['Day', 'Month', 'Year'], true) ? $_GET['type'] : 'Day';
?>
<p class="muted">Τα aggregates είναι <strong>τελικά</strong>: η δεύτερη κλήση για την ίδια ημέρα δεν γράφει τίποτα.
  Αθροίζονται μόνο οι σωρευτικοί κωδικοί 1.8.0 και 2.8.0. Μήνας/έτος χτίζονται στην τελευταία ημέρα τους ή με force.</p>
<h2>Χτίσιμο aggregates ημέρας</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="build">
  <label>Ημέρα (UTC) <input type="date" name="day" value="<?= h($today) ?>" required></label>
  <label><input type="checkbox" name="force_month" value="1"> Force μήνα</label>
  <label><input type="checkbox" name="force_year" value="1"> Force έτους</label>
  <button type="submit">Χτίσιμο</button>
</form>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="pending">
  <button type="submit">Χτίσιμο όλων των ημερών που λείπουν (έως χθες)</button>
</form>

<h2>Aggregates μετρητών</h2>
<form method="get" class="box">
  <label>Τύπος
    <select name="type">
      <?php foreach (['Day' => 'Ημέρα', 'Month' => 'Μήνας', 'Year' => 'Έτος'] as $k => $lbl) { ?>
        <option value="<?= h($k) ?>"<?= $k === $type ? ' selected' : '' ?>><?= h($lbl) ?></option>
      <?php } ?>
    </select>
  </label>
  <button type="submit">Εμφάνιση</button>
</form>
<?php
print_table(call_proc('sp_dso_list_aggregates', [uid(), null, $type]), [
    'MeterID' => 'Μετρητής', 'SerialNumber' => 'Σειριακός', 'ObisCode' => 'OBIS', 'PeriodType' => 'Τύπος',
    'PeriodStart' => 'Αρχή περιόδου', 'SumValue' => 'Άθροισμα (kWh)', 'ReadingCount' => 'Μετρήσεις',
    'EstimatedCount' => 'Εκτιμημένες', 'TransformerID' => 'Μετασχηματιστής',
]);
?>
<h2>Aggregates μετασχηματιστών (φύλλα)</h2>
<?php
print_table(call_proc('sp_dso_list_transformer_aggregates', [uid(), null, $type]), [
    'TransformerID' => 'Μετασχηματιστής', 'Name' => 'Όνομα', 'ObisCode' => 'OBIS', 'PeriodType' => 'Τύπος',
    'PeriodStart' => 'Αρχή περιόδου', 'SumValue' => 'Άθροισμα (kWh)', 'MeterCount' => 'Μετρητές', 'ComputedAt' => 'Υπολογίστηκε',
]);
page_footer();
