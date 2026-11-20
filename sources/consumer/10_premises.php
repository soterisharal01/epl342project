<?php // MENU: Τα υποστατικά μου
// =====================================================================
// consumer/10_premises.php : ΙΙΙ.1.1 υποστατικά του καταναλωτή.
// Βλέπει τα υποστατικά του, προσθέτει νέο, δηλώνει ότι έπαψε να το κρατά.
// Procedures: sp_consumer_list_premises, sp_consumer_add_premise,
//             sp_consumer_end_holding, sp_ref_list_parishes, sp_ref_list_schemes
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    if (($_POST['action'] ?? '') === 'end') {
        $r = call_proc('sp_consumer_end_holding', [uid(), (int)$_POST['premise'], null]);
        $ok = 'Καταγράφηκε ότι δεν κρατάτε πια το υποστατικό.';
    } else {
        $r = call_proc('sp_consumer_add_premise', [
            uid(), trim($_POST['address'] ?? ''), trim($_POST['postal'] ?? ''),
            (float)str_replace(',', '.', $_POST['lat'] ?? ''), (float)str_replace(',', '.', $_POST['lon'] ?? ''),
            $_POST['usage'] ?? '', (int)($_POST['parish'] ?? 0), (int)($_POST['scheme'] ?? 0), post_or_null('start'),
        ]);
        $ok = 'Το υποστατικό προστέθηκε.';
    }
    $r === false ? flash(last_error(), 'error') : flash($ok);
    redirect('consumer/10_premises.php');
}

page_header('Τα υποστατικά μου');
$rows = call_proc('sp_consumer_list_premises', [uid()]);
if ($rows) {
    echo '<table class="data"><tr><th>#</th><th>Διεύθυνση</th><th>ΤΚ</th><th>Χρήση</th><th>Επαρχία / Δήμος / Ενορία</th>'
       . '<th>Σχήμα</th><th>WGS84</th><th>Μετρητής</th><th>Από</th><th>Έως</th><th></th></tr>';
    foreach ($rows as $p) {
        echo '<tr><td>' . h($p['PremiseID']) . '</td><td>' . h($p['Address']) . '</td><td>' . h($p['PostalCode'])
           . '</td><td>' . h($p['Usage']) . '</td><td>' . h($p['District'] . ' / ' . $p['Municipality'] . ' / ' . $p['Parish'])
           . '</td><td>' . h($p['Scheme']) . '</td><td>' . h($p['Latitude'] . ', ' . $p['Longitude'])
           . '</td><td>' . h($p['Meter'] ?? '—') . '</td><td>' . h($p['StartDate']) . '</td><td>' . h($p['EndDate'] ?? '') . '</td><td>';
        if ($p['EndDate'] === null) {
            echo '<form method="post" onsubmit="return confirm(\'Να καταγραφεί ότι δεν το κρατάτε πια;\')">' . csrf_field()
               . '<input type="hidden" name="action" value="end"><input type="hidden" name="premise" value="' . h($p['PremiseID']) . '">'
               . '<button class="danger">Λήξη</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($rows);
}
$parishes = call_proc('sp_ref_list_parishes');
$schemes = call_proc('sp_ref_list_schemes');
?>
<h2>Νέο υποστατικό</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="add">
  <label>Διεύθυνση <input name="address" required maxlength="200"></label>
  <label>Ταχυδρομικός κώδικας <input name="postal" required pattern="[0-9]{4}" maxlength="4"></label>
  <label>Γεωγραφικό πλάτος (π.χ. 35.1676) <input name="lat" required inputmode="decimal"></label>
  <label>Γεωγραφικό μήκος (π.χ. 33.3736) <input name="lon" required inputmode="decimal"></label>
  <label>Χρήση
    <select name="usage" required>
      <option value="Residential">Οικιακό</option><option value="Commercial">Εμπορικό</option>
      <option value="Industrial">Βιομηχανικό</option><option value="Agricultural">Γεωργικό</option>
    </select></label>
  <label>Επαρχία / Δήμος / Ενορία <select name="parish" required><?= select_options($parishes, 'ParishID', 'Label') ?></select></label>
  <label>Σχήμα προμήθειας <select name="scheme" required><?= select_options($schemes, 'SchemeID', 'Label') ?></select></label>
  <label>Από (προαιρετικό, αλλιώς σήμερα) <input name="start" type="date"></label>
  <button type="submit">Προσθήκη</button>
</form>
<?php page_footer();
