<?php // MENU: Τρέχουσα κατάσταση
// =====================================================================
// tso/20_state.php : ΙΙΙ.4.2 τρέχουσα κατάσταση ανά μετασχηματιστή.
// Το κουμπί υπολογίζει ξανά τα φύλλα (κοινό 15λεπτο αναφοράς = το τελευταίο με επικυρωμένες μετρήσεις).
// Οι κόμβοι πάνω από τα φύλλα υπολογίζονται κάθε φορά ως άθροισμα των φύλλων από κάτω.
// Procedures: sp_tso_refresh_current_state, sp_tso_current_state
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('TSO');

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'refresh') {
    check_csrf();
    $r = call_proc('sp_tso_refresh_current_state', [uid()]);
    if ($r === false) {
        flash(last_error(), 'error');
    } else {
        flash('Η κατάσταση ανανεώθηκε για το διάστημα ' . ($r[0]['RefInterval'] ?? '') . ' (' . ($r[0]['LeafCount'] ?? 0) . ' φύλλα).');
    }
    redirect('tso/20_state.php');
}

page_header('Τρέχουσα κατάσταση');
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="refresh">
  <p>Ο υπολογισμός γίνεται μόνο όταν πατήσεις το κουμπί. Μετρητές χωρίς μέτρηση στο διάστημα αναφοράς δεν μετράνε.</p>
  <button type="submit">Ανανέωση τρέχουσας κατάστασης</button>
</form>
<?php
$rows = call_proc('sp_tso_current_state', [uid()]);
if ($rows === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$rows) {
    echo '<p class="muted">Δεν υπάρχουν μετασχηματιστές.</p>';
} else {
    echo '<table class="data"><tr><th>Μετασχηματιστής</th><th>Διάστημα αναφοράς (UTC)</th><th>Εισαγωγή kWh (1.8.0)</th>'
       . '<th>Εξαγωγή kWh (2.8.0)</th><th>Καθαρό kWh</th><th>Μετρητές</th></tr>';
    foreach ($rows as $t) {
        $pad = str_repeat('&nbsp;&nbsp;&nbsp;&nbsp;', (int)$t['Level']);
        echo '<tr><td>' . $pad . h($t['Name']) . '</td><td>' . h($t['RefInterval'] ?? '—') . '</td><td>' . h($t['ImportKWh'])
           . '</td><td>' . h($t['ExportKWh']) . '</td><td>' . h($t['NetKWh']) . '</td><td>' . h($t['MeterCount']) . '</td></tr>';
    }
    echo '</table>';
}
page_footer();
