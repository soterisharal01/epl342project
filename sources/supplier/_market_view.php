<?php
// =====================================================================
// supplier/_market_view.php : κοινή εμφάνιση Day-Ahead και Intraday για Supplier και Aggregator.
// Procedures: sp_supplier_aggregates, sp_supplier_totals, sp_market_intraday (MKT-1, MKT-3).
// Δεν έχει γραμμή MENU: δεν εμφανίζεται στο μενού. Το καλούν οι σελίδες των δύο ρόλων.
// =====================================================================

function market_date(string $key, string $default): string
{
    $v = (string)($_GET[$key] ?? '');
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : $default;
}

// Οριζόντια μπάρα (CSS) για πίνακες: τιμή σε σχέση με το μέγιστο.
function market_bar($v, float $max): string
{
    $pct = $max > 0 ? max(0, min(100, (float)$v / $max * 100)) : 0;
    return '<div style="background:#cfe3f7;width:' . number_format($pct, 1, '.', '') . '%;min-width:1px;height:0.9em"></div>';
}

function market_dayahead_page(string $role): void
{
    $to   = market_date('to', gmdate('Y-m-d'));
    $from = market_date('from', gmdate('Y-m-d', strtotime($to . ' -6 days')));
    $ptype = in_array($_GET['ptype'] ?? '', ['Day', 'Month', 'Year'], true) ? $_GET['ptype'] : 'Day';

    page_header('Day-Ahead');
    ?>
<form method="get" class="inline-form">
  Περίοδος
  <select name="ptype">
    <option value="Day"<?= $ptype === 'Day' ? ' selected' : '' ?>>Ημέρα</option>
    <option value="Month"<?= $ptype === 'Month' ? ' selected' : '' ?>>Μήνας</option>
    <option value="Year"<?= $ptype === 'Year' ? ' selected' : '' ?>>Έτος</option>
  </select>
  Από <input type="date" name="from" value="<?= h($from) ?>" required>
  Έως <input type="date" name="to" value="<?= h($to) ?>" required>
  <button type="submit">Εμφάνιση</button>
</form>
<p class="muted">Τα δεδομένα είναι επικυρωμένα (VEE) και δείχνουν μόνο αθροίσματα
  <?= $role === 'Aggregator' ? 'των χαρτοφυλακίων σας' : 'των πελατών σας' ?>, ανά περίοδο και μετασχηματιστή.
  Οι τιμές είναι ενέργεια σε kWh. Για μηνιαία/ετήσια περίοδο, η «Από» ημερομηνία πρέπει να είναι η αρχή της περιόδου.</p>
<?php
    $rows = call_proc('sp_supplier_aggregates', [uid(), $ptype, $from, $to]);
    echo '<h2>Ανά περίοδο και μετασχηματιστή</h2>';
    if ($rows === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } elseif (!$rows) {
        echo '<p class="muted">Δεν υπάρχουν επικυρωμένα δεδομένα στο διάστημα.</p>';
    } else {
        $max = 0.0;
        foreach ($rows as $r) { $max = max($max, abs((float)$r['ImportKWh']), abs((float)$r['ExportKWh'])); }
        echo '<table class="data"><tr><th>Περίοδος</th><th>Μετασχηματιστής</th><th>Γεωπεριοχή</th>'
           . '<th>Εισαγωγή kWh</th><th>Εξαγωγή kWh</th><th>Καθαρό kWh</th><th>Μετρητές</th><th>Εκτιμημένες τιμές</th>'
           . '<th style="width:12em">Εισαγωγή</th></tr>';
        foreach ($rows as $r) {
            echo '<tr><td>' . h($r['PeriodStart']) . '</td><td>' . h($r['TransformerName']) . '</td><td>' . h($r['GeofenceName'])
               . '</td><td>' . h($r['ImportKWh']) . '</td><td>' . h($r['ExportKWh']) . '</td><td>' . h($r['NetKWh'])
               . '</td><td>' . h($r['MeterCount']) . '</td><td>' . h($r['EstimatedCount'])
               . '</td><td>' . market_bar($r['ImportKWh'], $max) . '</td></tr>';
        }
        echo '</table>';
    }
    echo '<h2>Σύνολα ανά περίοδο</h2>';
    print_table(call_proc('sp_supplier_totals', [uid(), $ptype, $from, $to]), [
        'PeriodStart' => 'Περίοδος', 'ImportKWh' => 'Εισαγωγή kWh', 'ExportKWh' => 'Εξαγωγή kWh',
        'NetKWh' => 'Καθαρό kWh', 'MeterCount' => 'Μετρητές', 'EstimatedCount' => 'Εκτιμημένες τιμές',
    ]);
    page_footer();
}

function market_intraday_page(string $role): void
{
    $date = market_date('date', gmdate('Y-m-d'));

    page_header('Intraday');
    ?>
<form method="get" class="inline-form">
  Ημερομηνία (UTC) <input type="date" name="date" value="<?= h($date) ?>" required>
  <button type="submit">Εμφάνιση</button>
</form>
<h2>Προσωρινά δεδομένα (πριν το VEE)</h2>
<p class="muted">Τιμές 15 λεπτών από τις πιο πρόσφατες μετρήσεις, πριν τον έλεγχο VEE: μπορεί να αλλάξουν.
  Δείχνουν μόνο αθροίσματα <?= $role === 'Aggregator' ? 'των χαρτοφυλακίων σας' : 'των πελατών σας' ?> ανά μετασχηματιστή.</p>
<?php
    $rows = call_proc('sp_market_intraday', [uid(), $date]);
    if ($rows === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } elseif (!$rows) {
        echo '<p class="muted">Δεν υπάρχουν μετρήσεις για την ημέρα.</p>';
    } else {
        echo '<table class="data"><tr><th>Διάστημα (15λεπτο)</th><th>Μετασχηματιστής</th><th>Γεωπεριοχή</th>'
           . '<th>Εισαγωγή kWh</th><th>Εξαγωγή kWh</th><th>Καθαρό kWh</th><th>Μετρητές</th><th>Κατάσταση</th></tr>';
        foreach ($rows as $r) {
            echo '<tr><td>' . h($r['IntervalStart']) . '</td><td>' . h($r['TransformerName']) . '</td><td>' . h($r['GeofenceName'])
               . '</td><td>' . h($r['ImportKWh']) . '</td><td>' . h($r['ExportKWh']) . '</td><td>' . h($r['NetKWh'])
               . '</td><td>' . h($r['MeterCount']) . '</td><td>Προσωρινά</td></tr>';
        }
        echo '</table>';
    }
    page_footer();
}
