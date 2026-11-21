<?php // MENU: Διαθεσιμότητα
// =====================================================================
// technician/30_availability.php : ΙΙΙ.2.1 ημερήσια διαθεσιμότητα (ώρες + δήμοι).
// Procedures: sp_tech_declare_availability, sp_tech_list_availability,
//             sp_tech_remove_availability, sp_ref_list_municipalities
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Technician');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    switch ($_POST['action'] ?? '') {
        case 'declare':
            $ids = array_map('intval', (array)($_POST['mun'] ?? []));
            $r = call_proc('sp_tech_declare_availability', [
                uid(), post_or_null('date'), post_or_null('from'), post_or_null('to'), implode(',', $ids),
            ]);
            $ok = 'Η διαθεσιμότητα δηλώθηκε.';
            break;
        case 'remove':
            $r = call_proc('sp_tech_remove_availability', [uid(), post_or_null('date'), post_or_null('from')]);
            $ok = 'Η ζώνη διαγράφηκε.';
            break;
        default:
            $r = false;
            $ok = '';
            flash('Άγνωστη ενέργεια.', 'error');
    }
    if ($r === false) {
        if (last_error() !== null) { flash(last_error(), 'error'); }
    } else {
        flash($ok);
    }
    redirect('technician/30_availability.php');
}

page_header('Διαθεσιμότητα');
$munis = call_proc('sp_ref_list_municipalities');
$rows = call_proc('sp_tech_list_availability', [uid(), null, null]);
if ($rows === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$rows) {
    echo '<p class="muted">Δεν έχετε δηλώσει διαθεσιμότητα.</p>';
} else {
    echo '<table class="data"><tr><th>Ημερομηνία</th><th>Από</th><th>Έως</th><th>Δήμοι</th><th></th></tr>';
    foreach ($rows as $a) {
        echo '<tr><td>' . h($a['AvailDate']) . '</td><td>' . h(substr($a['FromTime'], 0, 5)) . '</td><td>'
           . h(substr($a['ToTime'], 0, 5)) . '</td><td>' . h($a['Municipalities']) . '</td><td>'
           . '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="remove">'
           . '<input type="hidden" name="date" value="' . h($a['AvailDate']) . '">'
           . '<input type="hidden" name="from" value="' . h(substr($a['FromTime'], 0, 8)) . '">'
           . '<button>Διαγραφή</button></form></td></tr>';
    }
    echo '</table>';
}
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="declare">
  <h2>Νέα ζώνη διαθεσιμότητας</h2>
  <label>Ημερομηνία <input type="date" name="date" required></label>
  <label>Από <input type="time" name="from" required></label>
  <label>Έως <input type="time" name="to" required></label>
  <fieldset>
    <legend>Δήμοι (τουλάχιστον ένας)</legend>
    <?php foreach ($munis ?: [] as $m): ?>
      <label><input type="checkbox" name="mun[]" value="<?= h($m['MunicipalityID']) ?>"> <?= h($m['Label']) ?></label>
    <?php endforeach; ?>
  </fieldset>
  <button type="submit">Δήλωση</button>
</form>
<?php page_footer();
