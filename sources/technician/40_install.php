<?php // MENU: Εγκατάσταση μετρητή
// =====================================================================
// technician/40_install.php : ΙΙΙ.2.3 εγκατάσταση / αντικατάσταση μετρητή.
// Διαλέγω δική μου αποδεκτή εργασία Installation/Replacement, δηλώνω τον μετρητή
// (ο μετασχηματιστής βρίσκεται από τις συντεταγμένες), φωτογραφίες και τα 3 έγγραφα.
// Procedures: sp_tech_list_tasks, sp_tech_install_meter, sp_tech_add_attachment,
//             sp_tech_add_meter_document, sp_tech_list_installs,
//             sp_ref_list_meter_models, sp_ref_list_comm_types
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_approved_technician();   // FIX-2: μόνο εγκεκριμένος Τεχνικός

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    switch ($_POST['action'] ?? '') {
        case 'install':
            $phases = isset($_POST['phase']) && is_array($_POST['phase']) ? implode(',', $_POST['phase']) : '';
            $r = call_proc('sp_tech_install_meter', [
                uid(), (int)($_POST['task'] ?? 0), trim($_POST['serial'] ?? ''), trim($_POST['network'] ?? ''),
                trim($_POST['firmware'] ?? ''), trim($_POST['amps'] ?? ''), trim($_POST['lat'] ?? ''),
                trim($_POST['lon'] ?? ''), (int)($_POST['model'] ?? 0), (int)($_POST['comm'] ?? 0), $phases,
            ]);
            $ok = 'Ο μετρητής καταχωρίστηκε και περιμένει επιβεβαίωση από τον Operator.';
            break;
        case 'photo':
            $r = call_proc('sp_tech_add_attachment', [uid(), (int)($_POST['task'] ?? 0), trim($_POST['path'] ?? ''), post_or_null('caption')]);
            $ok = 'Η φωτογραφία καταχωρίστηκε.';
            break;
        case 'document':
            $r = call_proc('sp_tech_add_meter_document', [
                uid(), (int)($_POST['meter'] ?? 0), $_POST['doctype'] ?? '', trim($_POST['number'] ?? ''),
                post_or_null('issue'), post_or_null('expiry'), trim($_POST['file'] ?? ''),
            ]);
            $ok = 'Το έγγραφο καταχωρίστηκε.';
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
    redirect('technician/40_install.php');
}

page_header('Εγκατάσταση μετρητή');
$tasks = [];
foreach (call_proc('sp_tech_list_tasks', [uid(), 'Accepted']) ?: [] as $t) {
    if ($t['TaskType'] === 'Installation' || $t['TaskType'] === 'Replacement') {
        $tasks[] = ['v' => $t['TaskID'], 'l' => '#' . $t['TaskID'] . ' ' . $t['TaskType'] . ' - ' . ($t['Address'] ?? '')
            . ($t['MeterID'] ? ' (παλιός μετρητής ' . $t['SerialNumber'] . ')' : '')];
    }
}
$models = call_proc('sp_ref_list_meter_models');
$comms = call_proc('sp_ref_list_comm_types');
$installs = call_proc('sp_tech_list_installs', [uid()]);
$pending = [];
foreach ($installs ?: [] as $i) {
    if ($i['ConfirmationStatus'] === 'Pending') {
        $pending[] = ['v' => $i['MeterID'], 'l' => $i['SerialNumber'] . ' (εγκατάσταση ' . $i['InstallationID'] . ')'];
    }
}
?>
<h2>Οι εγκαταστάσεις μου</h2>
<?php
print_table($installs, ['InstallationID' => '#', 'TaskID' => 'Εργασία', 'MeterID' => 'Μετρητής', 'SerialNumber' => 'Serial',
    'MeterStatus' => 'Κατάσταση μετρητή', 'PremiseID' => 'Υποστατικό', 'InstalledAt' => 'Εγκαταστάθηκε',
    'ConfirmationStatus' => 'Επιβεβαίωση', 'ConfirmComment' => 'Σχόλιο Operator', 'DocTypesPresent' => 'Έγγραφα (από 3)']);
?>
<h2>Νέα εγκατάσταση / αντικατάσταση</h2>
<?php if (!$tasks): ?>
<p class="muted">Δεν έχετε αποδεκτή εργασία εγκατάστασης ή αντικατάστασης. Αποδεχτείτε πρώτα την εργασία στη σελίδα «Οι εργασίες μου».</p>
<?php else: ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="install">
  <label>Εργασία <select name="task" required><?= select_options($tasks, 'v', 'l') ?></select></label>
  <label>Serial <input name="serial" required maxlength="40"></label>
  <label>Network ID <input name="network" required maxlength="40"></label>
  <label>Firmware <input name="firmware" required maxlength="30"></label>
  <label>Μέγιστα Amps <input name="amps" required inputmode="decimal" pattern="[0-9]+([.][0-9])?"></label>
  <label>Πλάτος (lat) <input name="lat" required inputmode="decimal" placeholder="35.145"></label>
  <label>Μήκος (lon) <input name="lon" required inputmode="decimal" placeholder="33.39"></label>
  <label>Μοντέλο <select name="model" required><?= select_options($models, 'ModelID', 'Label') ?></select></label>
  <label>Επικοινωνία <select name="comm" required><?= select_options($comms, 'CommTypeID', 'Label') ?></select></label>
  <fieldset>
    <legend>Φάσεις (όσες το μοντέλο)</legend>
    <label><input type="checkbox" name="phase[]" value="L1"> L1</label>
    <label><input type="checkbox" name="phase[]" value="L2"> L2</label>
    <label><input type="checkbox" name="phase[]" value="L3"> L3</label>
  </fieldset>
  <button type="submit">Καταχώριση μετρητή</button>
</form>
<h3>Φωτογραφία εγκατάστασης (διαδρομή αρχείου)</h3>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="photo">
  <label>Εργασία <select name="task" required><?= select_options($tasks, 'v', 'l') ?></select></label>
  <label>Διαδρομή <input name="path" required maxlength="400"></label>
  <label>Λεζάντα <input name="caption" maxlength="200"></label>
  <button type="submit">Προσθήκη φωτογραφίας</button>
</form>
<?php endif; ?>
<h2>Έγγραφα εξοπλισμού μετρητή</h2>
<?php if (!$pending): ?>
<p class="muted">Δεν υπάρχει εγκατάσταση σε αναμονή επιβεβαίωσης.</p>
<?php else: ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="document">
  <label>Μετρητής <select name="meter" required><?= select_options($pending, 'v', 'l') ?></select></label>
  <label>Τύπος
    <select name="doctype" required>
      <option value="Calibration certificate">Πιστοποιητικό βαθμονόμησης</option>
      <option value="CE and protocol declaration">Δήλωση CE και πρωτοκόλλου</option>
      <option value="Encryption certificate">Πιστοποιητικό κρυπτογράφησης τηλεμετρίας</option>
    </select>
  </label>
  <label>Κωδικός <input name="number" required maxlength="50"></label>
  <label>Έκδοση <input type="date" name="issue" required></label>
  <label>Λήξη (προαιρετικά) <input type="date" name="expiry"></label>
  <label>Αρχείο (διαδρομή) <input name="file" required maxlength="400"></label>
  <button type="submit">Προσθήκη εγγράφου</button>
</form>
<?php endif; ?>
<?php page_footer();
