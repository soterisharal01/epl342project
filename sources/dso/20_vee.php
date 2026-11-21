<?php // MENU: VEE
// =====================================================================
// dso/20_vee.php : ΙΙΙ.3.2 έλεγχος και εκτίμηση μετρήσεων (VEE).
//  1. Φόρμα εκτέλεσης VEE για περίοδο (sp_dso_run_vee)
//  2. Λίστα τρεξιμάτων (sp_dso_list_runs)
//  3. Ύποπτες μετρήσεις με γείτονες και λόγο, και φόρμα διόρθωσης (sp_dso_list_suspect, sp_dso_edit_reading)
// Όλες οι ώρες είναι UTC. Η διόρθωση δεν σβήνει το παλιό: μένει στο READING_EDIT.
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('DSO');

// Η τιμή ενός <input type="datetime-local"> ("2026-11-20T00:00") -> "2026-11-20 00:00:00" (UTC).
function vee_dt($v)
{
    $v = trim((string)$v);
    if (!preg_match('/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(:\d{2})?$/', $v, $m)) {
        return null;
    }
    return $m[1] . ' ' . $m[2] . ':00';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';
    if ($action === 'run') {
        $from = vee_dt($_POST['from'] ?? '');
        $to   = vee_dt($_POST['to'] ?? '');
        if ($from === null || $to === null) {
            flash('Δώστε έγκυρη αρχή και τέλος περιόδου.', 'error');
        } else {
            $r = call_proc('sp_dso_run_vee', [uid(), $from, $to]);
            if ($r === false) {
                flash(last_error(), 'error');
            } else {
                $x = $r[0];
                flash('VEE #' . (int)$x['RunID'] . ': επικυρωμένες ' . (int)$x['Validated']
                    . ', εκτιμημένες ' . (int)$x['Estimated'] . ', ύποπτες ' . (int)$x['Suspect']
                    . ', συμβάντα ' . (int)$x['Events'] . '.');
            }
        }
    } elseif ($action === 'edit') {
        $newValue = str_replace(',', '.', trim((string)($_POST['new_value'] ?? '')));
        if (!is_numeric($newValue)) {
            flash('Η νέα τιμή πρέπει να είναι αριθμός.', 'error');
        } else {
            $r = call_proc('sp_dso_edit_reading', [
                uid(), (int)($_POST['meter_id'] ?? 0), (string)($_POST['obis'] ?? ''),
                (string)($_POST['interval'] ?? ''), $newValue, (string)($_POST['reason'] ?? ''),
            ]);
            if ($r === false) {
                flash(last_error(), 'error');
            } else {
                flash('Η μέτρηση διορθώθηκε (νέα τιμή ' . $newValue . ').');
            }
        }
    }
    redirect('dso/20_vee.php');                 // Post/Redirect/Get: όχι διπλό submit με F5
}

page_header('Έλεγχος VEE');
$today = gmdate('Y-m-d');
?>
<h2>Εκτέλεση VEE</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="run">
  <label>Από (UTC) <input type="datetime-local" name="from" value="<?= h($today) ?>T00:00" required></label>
  <label>Έως (UTC, μη συμπεριλαμβανόμενο) <input type="datetime-local" name="to" value="<?= h($today) ?>T23:59" required></label>
  <button type="submit">Εκτέλεση VEE</button>
</form>

<h2>Τρεξίματα VEE</h2>
<?php
print_table(call_proc('sp_dso_list_runs', [uid()]), [
    'RunID' => 'Run', 'PeriodFrom' => 'Από', 'PeriodTo' => 'Έως', 'StartedAt' => 'Έναρξη', 'FinishedAt' => 'Λήξη',
    'Validated' => 'Επικυρωμένες', 'Estimated' => 'Εκτιμημένες', 'Edited' => 'Διορθωμένες', 'SuspectNow' => 'Ύποπτες τώρα',
]);
?>

<h2>Ύποπτες μετρήσεις</h2>
<?php
$sus = call_proc('sp_dso_list_suspect', [uid()]);
if ($sus === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (count($sus) === 0) {
    echo '<p class="muted">Δεν υπάρχουν ύποπτες μετρήσεις.</p>';
} else { ?>
<p class="muted">Η τιμή που υπολογίστηκε είναι η ενέργεια του 15λέπτου (για σωρευτικούς κωδικούς: μετρητής μείον προηγούμενος μετρητής).</p>
<table class="data">
  <tr><th>Μετρητής</th><th>OBIS</th><th>Διάστημα (UTC)</th><th>Μετρητής/τιμή</th><th>Υπολογισμένη τιμή</th>
      <th>Προηγούμενη</th><th>Επόμενη</th><th>Λόγος</th><th>Διόρθωση</th></tr>
<?php foreach ($sus as $s) { ?>
  <tr>
    <td><?= h($s['SerialNumber']) ?></td>
    <td><?= h($s['ObisCode']) ?></td>
    <td><?= h($s['IntervalStart']) ?></td>
    <td><?= h($s['ReceivedValue']) ?></td>
    <td><?= h($s['ComputedValue']) ?></td>
    <td><?= h($s['PrevIntervalStart']) ?><br><?= h($s['PrevReceived']) ?> (επικυρ. <?= h($s['PrevValidatedValue']) ?>)</td>
    <td><?= h($s['NextIntervalStart']) ?><br><?= h($s['NextReceived']) ?></td>
    <td><?= h($s['Reason']) ?></td>
    <td>
      <form method="post">
        <?= csrf_field() ?>
        <input type="hidden" name="action" value="edit">
        <input type="hidden" name="meter_id" value="<?= h($s['MeterID']) ?>">
        <input type="hidden" name="obis" value="<?= h($s['ObisCode']) ?>">
        <input type="hidden" name="interval" value="<?= h($s['IntervalStart']) ?>">
        <label>Νέα τιμή <input name="new_value" size="8" required></label>
        <label>Λόγος <input name="reason" size="24" maxlength="500" required></label>
        <button type="submit">Διόρθωση</button>
      </form>
    </td>
  </tr>
<?php } ?>
</table>
<?php }
page_footer();
