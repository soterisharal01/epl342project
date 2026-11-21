<?php // MENU: Όρια και ειδοποιήσεις
// =====================================================================
// consumer/60_settings.php : ΙΙΙ.1.2 όρια κατανάλωσης (ανά ημέρα / μήνα) και κανάλια ειδοποίησης.
// Procedures: sp_consumer_list_premises, sp_consumer_set_threshold, sp_consumer_remove_threshold,
//             sp_consumer_list_thresholds, sp_consumer_set_channels, sp_consumer_list_channels
// Η αποστολή email/SMS γίνεται εκτός βάσης· εδώ φαίνεται αν το όριο ξεπεράστηκε.
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

// --- Χειρισμός φορμών (POST) ---
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = (string)($_POST['action'] ?? '');
    if ($action === 'set_threshold') {
        $limit = str_replace(',', '.', trim((string)($_POST['limit'] ?? '')));
        $r = call_proc('sp_consumer_set_threshold', [
            uid(), (int)($_POST['premise'] ?? 0), (string)($_POST['period'] ?? ''),
            is_numeric($limit) ? $limit : 0,
        ]);
        if ($r === false) { flash(last_error(), 'error'); } else { flash('Το όριο αποθηκεύτηκε.'); }
    } elseif ($action === 'remove_threshold') {
        $r = call_proc('sp_consumer_remove_threshold', [uid(), (int)($_POST['threshold'] ?? 0)]);
        if ($r === false) { flash(last_error(), 'error'); } else { flash('Το όριο αφαιρέθηκε.'); }
    } elseif ($action === 'set_channels') {
        $picked = [];
        if (!empty($_POST['ch_email'])) { $picked[] = 'Email'; }
        if (!empty($_POST['ch_sms']))   { $picked[] = 'SMS'; }
        $r = call_proc('sp_consumer_set_channels', [uid(), implode(',', $picked)]);
        if ($r === false) { flash(last_error(), 'error'); } else { flash('Τα κανάλια ειδοποίησης αποθηκεύτηκαν.'); }
    }
    redirect('consumer/60_settings.php');
}

// --- Εμφάνιση ---
page_header('Όρια και ειδοποιήσεις');

echo '<h2>Κανάλια ειδοποίησης</h2>';
$chRows = call_proc('sp_consumer_list_channels', [uid()]) ?: [];
$chosen = array_column($chRows, 'NotificationChannel');
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="set_channels">
  <label><input type="checkbox" name="ch_email" value="1"<?= in_array('Email', $chosen, true) ? ' checked' : '' ?>> Email</label>
  <label><input type="checkbox" name="ch_sms" value="1"<?= in_array('SMS', $chosen, true) ? ' checked' : '' ?>> SMS (χρειάζεται τηλέφωνο στο προφίλ)</label>
  <button type="submit">Αποθήκευση</button>
</form>

<h2>Όρια κατανάλωσης</h2>
<p class="muted">Ένα ενεργό όριο ανά υποστατικό και περίοδο. Αν ορίσετε ξανά το ίδιο υποστατικό και περίοδο, αλλάζει το υπάρχον. Η αποστολή ειδοποίησης γίνεται εκτός της βάσης.</p>
<?php
$thr = call_proc('sp_consumer_list_thresholds', [uid()]);
if ($thr === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$thr) {
    echo '<p class="muted">Δεν έχετε ορίσει όρια.</p>';
} else {
    echo '<table class="data"><tr><th>Υποστατικό</th><th>Περίοδος</th><th>Όριο kWh</th><th>Τρέχουσα κατανάλωση kWh</th><th>Κατάσταση</th><th></th></tr>';
    foreach ($thr as $t) {
        $exceeded = !empty($t['Exceeded']);
        echo '<tr><td>' . h($t['Address']) . '</td><td>' . ($t['PeriodType'] === 'Day' ? 'Ημέρα (σήμερα)' : 'Μήνας (τρέχων)')
           . '</td><td>' . h($t['LimitKWh']) . '</td><td>' . h($t['CurrentKWh']) . '</td><td>'
           . ($exceeded ? '<strong class="error">Ξεπεράστηκε</strong>' : 'Εντός ορίου') . '</td><td>'
           . '<form method="post" class="inline-form">' . csrf_field()
           . '<input type="hidden" name="action" value="remove_threshold">'
           . '<input type="hidden" name="threshold" value="' . h($t['ThresholdID']) . '">'
           . '<button type="submit">Αφαίρεση</button></form></td></tr>';
    }
    echo '</table>';
}
$premises = array_values(array_filter(call_proc('sp_consumer_list_premises', [uid()]) ?: [],
    fn($p) => $p['EndDate'] === null || $p['EndDate'] === ''));
?>
<h3>Νέο / αλλαγή ορίου</h3>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="set_threshold">
  <label>Υποστατικό
    <select name="premise"><?= select_options($premises, 'PremiseID', 'Address') ?></select></label>
  <label>Περίοδος
    <select name="period"><option value="Day">Ημέρα</option><option value="Month">Μήνας</option></select></label>
  <label>Όριο (kWh) <input name="limit" inputmode="decimal" required></label>
  <button type="submit">Αποθήκευση</button>
</form>
<?php page_footer();
