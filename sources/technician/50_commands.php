<?php // MENU: Εντολές
// =====================================================================
// technician/50_commands.php : ΙΙΙ.2.4 εντολές εξ αποστάσεως (απόφαση B15).
// Ζητώ εντολή για μετρητή όπου έχω αποδεκτή εργασία. Ο Operator την εγκρίνει, και μετά
// καταγράφονται προσπάθειες (προσομοίωση συσκευής) μέχρι ACK.
// Procedures: sp_tech_list_command_targets, sp_tech_request_command, sp_command_list,
//             sp_command_record_attempt, sp_command_list_attempts
// Εδώ και ο έλεγχος anti-tamper (sp_tech_record_tamper_check, sp_tech_list_tasks).
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_approved_technician();   // FIX-2: μόνο εγκεκριμένος Τεχνικός

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    switch ($_POST['action'] ?? '') {
        case 'request':
            $r = call_proc('sp_tech_request_command', [uid(), (int)($_POST['meter'] ?? 0), $_POST['type'] ?? '', post_or_null('params')]);
            $ok = 'Η εντολή υποβλήθηκε και περιμένει έγκριση.';
            break;
        case 'tamper':
            $r = call_proc('sp_tech_record_tamper_check', [uid(), (int)($_POST['task'] ?? 0), trim($_POST['findings'] ?? ''),
                isset($_POST['critical']) ? 1 : 0, post_or_null('notify')]);
            $ok = 'Ο έλεγχος καταγράφηκε.';
            break;
        case 'attempt':
            $r = call_proc('sp_command_record_attempt', [uid(), (int)($_POST['command'] ?? 0), $_POST['outcome'] ?? '']);
            $ok = 'Η προσπάθεια καταγράφηκε.';
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
    redirect('technician/50_commands.php');
}

page_header('Εντολές');
$targets = call_proc('sp_tech_list_command_targets', [uid()]);
$targetOptions = [];
foreach ($targets ?: [] as $t) {
    $targetOptions[] = ['v' => $t['MeterID'], 'l' => $t['SerialNumber'] . ' (' . $t['Status'] . ')'];
}
$cmds = call_proc('sp_command_list', [uid(), null]);
$tamperTasks = [];
foreach (call_proc('sp_tech_list_tasks', [uid(), 'Accepted']) ?: [] as $t) {
    if ($t['TaskType'] === 'Anti-tamper check') {
        $tamperTasks[] = ['v' => $t['TaskID'], 'l' => '#' . $t['TaskID'] . ' ' . ($t['SerialNumber'] ?? '') . ' ' . ($t['Address'] ?? '')];
    }
}
?>
<h2>Νέα εντολή</h2>
<?php if (!$targetOptions): ?>
<p class="muted">Δεν έχετε αποδεκτή εργασία για κάποιον μετρητή, άρα δεν μπορείτε να ζητήσετε εντολή.</p>
<?php else: ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="request">
  <label>Μετρητής <select name="meter" required><?= select_options($targetOptions, 'v', 'l') ?></select></label>
  <label>Εντολή
    <select name="type" required>
      <option value="Disconnect">Disconnect (αποσύνδεση)</option>
      <option value="Reconnect">Reconnect (επανασύνδεση)</option>
      <option value="Firmware upgrade">Firmware upgrade</option>
    </select>
  </label>
  <label>Παράμετροι (JSON, προαιρετικά) <input name="params" maxlength="1000" placeholder='{"version":"3.2"}'></label>
  <button type="submit">Αίτηση εντολής</button>
</form>
<?php endif; ?>
<h2>Οι εντολές μου</h2>
<?php
if ($cmds === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$cmds) {
    echo '<p class="muted">Δεν έχετε ζητήσει εντολές.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Εντολή</th><th>Μετρητής</th><th>Παράμετροι</th><th>Ζητήθηκε</th>'
       . '<th>Κατάσταση</th><th>Προσπάθειες</th><th>Τελευταίο</th><th></th></tr>';
    foreach ($cmds as $c) {
        echo '<tr><td>' . h($c['CommandID']) . '</td><td>' . h($c['CommandType']) . '</td><td>' . h($c['SerialNumber'])
           . '</td><td>' . h($c['Parameters'] ?? '') . '</td><td>' . h($c['RequestedAt']) . '</td><td>' . h($c['Status'])
           . '</td><td>' . h($c['Attempts']) . '</td><td>' . h($c['LastOutcome'] ?? '—') . '</td><td>'
           . '<a href="?cmd=' . h($c['CommandID']) . '">Προσπάθειες</a>';
        if ($c['Status'] === 'Sent') {
            echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="attempt">'
               . '<input type="hidden" name="command" value="' . h($c['CommandID']) . '">'
               . '<select name="outcome"><option>ACK</option><option>NAK</option><option>Timeout</option></select>'
               . '<button>Καταγραφή προσπάθειας</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
}
$sel = (int)($_GET['cmd'] ?? 0);
if ($sel > 0) {
    echo '<h3>Προσπάθειες εντολής ' . h($sel) . '</h3>';
    print_table(call_proc('sp_command_list_attempts', [uid(), $sel]),
        ['AttemptNo' => 'Α/Α', 'AttemptAt' => 'Στάλθηκε', 'RespondedAt' => 'Απάντηση', 'Outcome' => 'Αποτέλεσμα']);
}
?>
<h2>Έλεγχος anti-tamper</h2>
<?php if (!$tamperTasks): ?>
<p class="muted">Δεν έχετε αποδεκτή εργασία anti-tamper.</p>
<?php else: ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="tamper">
  <label>Εργασία <select name="task" required><?= select_options($tamperTasks, 'v', 'l') ?></select></label>
  <label>Ευρήματα <textarea name="findings" required maxlength="2000"></textarea></label>
  <label><input type="checkbox" name="critical" value="1"> Κρίσιμο εύρημα (δημιουργεί συμβάν για τον Operator)</label>
  <label>Ειδοποίηση χρηστών (ID χωρισμένα με κόμμα) <input name="notify" maxlength="200"></label>
  <button type="submit">Καταγραφή ελέγχου</button>
</form>
<?php endif; ?>
<?php page_footer();
