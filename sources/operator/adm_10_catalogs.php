<?php // MENU: Κατάλογοι
// =====================================================================
// operator/adm_10_catalogs.php : κατάλογοι του Χειριστή (ADM-4 για ADM-3).
// Μοντέλα μετρητών, υπηρεσίες, τιμολόγια: λίστα, προσθήκη/αλλαγή, διαγραφή (μόνο αν δεν χρησιμοποιούνται).
// Procedures: sp_operator_save_meter_model, sp_operator_save_service_type, sp_operator_save_tariff_type,
//             sp_operator_delete_catalog_item, sp_ref_list_meter_models, sp_ref_list_service_types,
//             sp_ref_list_tariff_types
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Operator');

const CAT_PAGE = 'operator/adm_10_catalogs.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';
    $id = post_or_null('id');
    $id = $id === null ? null : (int)$id;
    $r = false;
    $ok = 'Αποθηκεύτηκε.';
    if ($action === 'save_model') {
        $r = call_proc('sp_operator_save_meter_model', [
            uid(), $id, trim($_POST['manufacturer'] ?? ''), trim($_POST['model'] ?? ''),
            trim($_POST['type'] ?? ''), (int)($_POST['phases'] ?? 0)]);
    } elseif ($action === 'save_service') {
        $r = call_proc('sp_operator_save_service_type', [
            uid(), $id, trim($_POST['name'] ?? ''), (float)str_replace(',', '.', $_POST['fee'] ?? '')]);
    } elseif ($action === 'save_tariff') {
        $r = call_proc('sp_operator_save_tariff_type', [uid(), $id, trim($_POST['name'] ?? '')]);
    } elseif ($action === 'delete') {
        $cat = $_POST['catalog'] ?? '';
        $r = call_proc('sp_operator_delete_catalog_item', [uid(), $cat, (int)($_POST['id'] ?? 0)]);
        $ok = 'Διαγράφηκε.';
    } else {
        flash('Άγνωστη ενέργεια.', 'error');
        redirect(CAT_PAGE);
    }
    $r === false ? flash(last_error(), 'error') : flash($ok);
    redirect(CAT_PAGE);
}

// Κουμπί διαγραφής μιας γραμμής.
function cat_delete_form(string $catalog, $id): string
{
    return '<form method="post" onsubmit="return confirm(\'Να διαγραφεί;\')">' . csrf_field()
         . '<input type="hidden" name="action" value="delete"><input type="hidden" name="catalog" value="' . h($catalog) . '">'
         . '<input type="hidden" name="id" value="' . h($id) . '"><button class="danger">Διαγραφή</button></form>';
}

page_header('Κατάλογοι');
$models = call_proc('sp_ref_list_meter_models');
$services = call_proc('sp_ref_list_service_types');
$tariffs = call_proc('sp_ref_list_tariff_types');

// Επιλεγμένη γραμμή προς αλλαγή (?edit=model:3). Μόνο ό,τι υπάρχει στη λίστα.
$edit = null;
if (preg_match('/^(model|service|tariff):(\d+)$/', (string)($_GET['edit'] ?? ''), $m)) {
    $idCol = ['model' => 'ModelID', 'service' => 'ServiceTypeID', 'tariff' => 'TariffTypeID'][$m[1]];
    $list = ['model' => $models, 'service' => $services, 'tariff' => $tariffs][$m[1]] ?: [];
    foreach ($list as $row) {
        if ((int)$row[$idCol] === (int)$m[2]) { $edit = [$m[1], $row]; break; }
    }
}
$e = fn(string $kind, string $col, $default = '') => ($edit && $edit[0] === $kind) ? $edit[1][$col] : $default;
$editId = fn(string $kind, string $col) => ($edit && $edit[0] === $kind) ? $edit[1][$col] : '';

// ---------- Μοντέλα μετρητών ----------
echo '<h2>Μοντέλα μετρητών</h2>';
if ($models) {
    echo '<table class="data"><tr><th>#</th><th>Κατασκευαστής</th><th>Μοντέλο</th><th>Τύπος</th><th>Φάσεις</th><th></th></tr>';
    foreach ($models as $x) {
        echo '<tr><td>' . h($x['ModelID']) . '</td><td>' . h($x['Manufacturer']) . '</td><td>' . h($x['ModelName'])
           . '</td><td>' . h($x['MeterType']) . '</td><td>' . h($x['PhaseCount']) . '</td><td><a href="'
           . h(url(CAT_PAGE) . '?edit=model:' . (int)$x['ModelID']) . '#f-model">Αλλαγή</a> '
           . cat_delete_form('MeterModel', $x['ModelID']) . '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($models);
}
?>
<form method="post" class="box" id="f-model">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="save_model">
  <input type="hidden" name="id" value="<?= h($editId('model', 'ModelID')) ?>">
  <strong><?= $edit && $edit[0] === 'model' ? 'Αλλαγή μοντέλου #' . h($edit[1]['ModelID']) : 'Νέο μοντέλο μετρητή' ?></strong>
  <label>Κατασκευαστής <input name="manufacturer" required maxlength="100" value="<?= h($e('model', 'Manufacturer')) ?>"></label>
  <label>Μοντέλο <input name="model" required maxlength="100" value="<?= h($e('model', 'ModelName')) ?>"></label>
  <label>Τύπος μετρητή (π.χ. Single-Phase) <input name="type" required maxlength="30" value="<?= h($e('model', 'MeterType')) ?>"></label>
  <label>Φάσεις
    <select name="phases" required>
      <?php foreach ([1, 2, 3] as $p): ?>
        <option value="<?= $p ?>"<?= (int)$e('model', 'PhaseCount', 1) === $p ? ' selected' : '' ?>><?= $p ?></option>
      <?php endforeach; ?>
    </select></label>
  <button type="submit">Αποθήκευση</button>
  <?php if ($edit && $edit[0] === 'model'): ?><a href="<?= h(url(CAT_PAGE)) ?>">Ακύρωση</a><?php endif; ?>
</form>

<?php
// ---------- Υπηρεσίες ----------
echo '<h2>Υπηρεσίες (τέλη)</h2>';
echo '<p class="muted">Η αλλαγή τέλους δεν αλλάζει παλιές αγορές: κάθε αγορά κρατά το δικό της ποσό.</p>';
if ($services) {
    echo '<table class="data"><tr><th>#</th><th>Υπηρεσία</th><th>Τέλος (€)</th><th></th></tr>';
    foreach ($services as $x) {
        echo '<tr><td>' . h($x['ServiceTypeID']) . '</td><td>' . h($x['Name']) . '</td><td>' . h(money($x['Fee']))
           . '</td><td><a href="' . h(url(CAT_PAGE) . '?edit=service:' . (int)$x['ServiceTypeID']) . '#f-service">Αλλαγή</a> '
           . cat_delete_form('ServiceType', $x['ServiceTypeID']) . '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($services);
}
?>
<form method="post" class="box" id="f-service">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="save_service">
  <input type="hidden" name="id" value="<?= h($editId('service', 'ServiceTypeID')) ?>">
  <strong><?= $edit && $edit[0] === 'service' ? 'Αλλαγή υπηρεσίας #' . h($edit[1]['ServiceTypeID']) : 'Νέα υπηρεσία' ?></strong>
  <label>Όνομα <input name="name" required maxlength="100" value="<?= h($e('service', 'Name')) ?>"></label>
  <label>Τέλος σε € (π.χ. 2,50) <input name="fee" required inputmode="decimal" value="<?= h($edit && $edit[0] === 'service' ? number_format((float)$edit[1]['Fee'], 2, ',', '') : '') ?>"></label>
  <button type="submit">Αποθήκευση</button>
  <?php if ($edit && $edit[0] === 'service'): ?><a href="<?= h(url(CAT_PAGE)) ?>">Ακύρωση</a><?php endif; ?>
</form>

<?php
// ---------- Τιμολόγια ----------
echo '<h2>Τιμολόγια</h2>';
if ($tariffs) {
    echo '<table class="data"><tr><th>#</th><th>Τιμολόγιο</th><th></th></tr>';
    foreach ($tariffs as $x) {
        echo '<tr><td>' . h($x['TariffTypeID']) . '</td><td>' . h($x['Name']) . '</td><td><a href="'
           . h(url(CAT_PAGE) . '?edit=tariff:' . (int)$x['TariffTypeID']) . '#f-tariff">Αλλαγή</a> '
           . cat_delete_form('TariffType', $x['TariffTypeID']) . '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($tariffs);
}
?>
<form method="post" class="box" id="f-tariff">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="save_tariff">
  <input type="hidden" name="id" value="<?= h($editId('tariff', 'TariffTypeID')) ?>">
  <strong><?= $edit && $edit[0] === 'tariff' ? 'Αλλαγή τιμολογίου #' . h($edit[1]['TariffTypeID']) : 'Νέο τιμολόγιο' ?></strong>
  <label>Όνομα <input name="name" required maxlength="100" value="<?= h($e('tariff', 'Name')) ?>"></label>
  <button type="submit">Αποθήκευση</button>
  <?php if ($edit && $edit[0] === 'tariff'): ?><a href="<?= h(url(CAT_PAGE)) ?>">Ακύρωση</a><?php endif; ?>
</form>
<?php page_footer();
