<?php // MENU: Εργασίες πεδίου
// =====================================================================
// operator/tec_20_tasks.php : ΙΙΙ.2.2 εργασίες πεδίου (Operator).
// Λίστα όλων των εργασιών, δημιουργία/ανάθεση (και από αίτημα καταναλωτή), αλλαγή τεχνικού, ακύρωση.
// Procedures: sp_task_list, sp_task_create, sp_task_reassign, sp_task_cancel,
//             sp_task_list_requests, sp_task_list_technicians
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Operator');

// Τιμή datetime-local (2027-06-15T09:00) -> 'Y-m-d H:i:s' για το SQL Server.
function task_dt(string $v): ?string
{
    $v = trim(str_replace('T', ' ', $v));
    if ($v === '') { return null; }
    return strlen($v) === 16 ? $v . ':00' : $v;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    switch ($_POST['action'] ?? '') {
        case 'create':
            $r = call_proc('sp_task_create', [
                uid(), $_POST['type'] ?? '', task_dt($_POST['from'] ?? ''), task_dt($_POST['to'] ?? ''),
                (int)($_POST['tech'] ?? 0), post_or_null('premise'), post_or_null('meter'),
                post_or_null('request'), post_or_null('notify'),
            ]);
            $ok = 'Η εργασία δημιουργήθηκε.';
            break;
        case 'reassign':
            $r = call_proc('sp_task_reassign', [uid(), (int)($_POST['task'] ?? 0), (int)($_POST['tech'] ?? 0)]);
            $ok = 'Ο τεχνικός άλλαξε.';
            break;
        case 'cancel':
            $r = call_proc('sp_task_cancel', [uid(), (int)($_POST['task'] ?? 0), trim($_POST['reason'] ?? '')]);
            $ok = 'Η εργασία ακυρώθηκε.';
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
    redirect('operator/tec_20_tasks.php');
}

page_header('Εργασίες πεδίου');
$filter = $_GET['status'] ?? '';
$techs = call_proc('sp_task_list_technicians', [uid()]);
$requests = call_proc('sp_task_list_requests', [uid()]);
$tasks = call_proc('sp_task_list', [uid(), $filter === '' ? null : $filter]);
$statuses = [
    ['v' => 'Assigned', 'l' => 'Assigned'], ['v' => 'Accepted', 'l' => 'Accepted'],
    ['v' => 'Done', 'l' => 'Done'], ['v' => 'Cancelled', 'l' => 'Cancelled'],
];
$techOptions = [];
foreach ($techs ?: [] as $t) {
    $techOptions[] = ['v' => $t['UserID'], 'l' => $t['Username'] . ' (' . $t['FirstName'] . ' ' . $t['LastName'] . ')'];
}
?>
<form method="get" class="box">
  <label>Κατάσταση
    <select name="status"><?= select_options($statuses, 'v', 'l', $filter, 'Όλες') ?></select>
  </label>
  <button type="submit">Φίλτρο</button>
</form>
<?php
if ($tasks === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$tasks) {
    echo '<p class="muted">Δεν υπάρχουν εργασίες.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Τύπος</th><th>Από</th><th>Έως</th><th>Κατάσταση</th><th>Τεχνικός</th>'
       . '<th>Διεύθυνση</th><th>Μετρητής</th><th>Αίτημα</th><th>Αποτέλεσμα</th><th></th></tr>';
    foreach ($tasks as $t) {
        echo '<tr><td>' . h($t['TaskID']) . '</td><td>' . h($t['TaskType']) . '</td><td>' . h($t['ScheduledFrom'])
           . '</td><td>' . h($t['ScheduledTo']) . '</td><td>' . h($t['Status']) . '</td><td>' . h($t['TechnicianUsername'])
           . '</td><td>' . h($t['Address'] ?? '—') . '</td><td>' . h($t['MeterID'] ?? '—')
           . '</td><td>' . h($t['RequestID'] ?? '—') . '</td><td>' . h($t['Result'] ?? '') . '</td><td>';
        if ($t['Status'] === 'Assigned') {
            echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="reassign">'
               . '<input type="hidden" name="task" value="' . h($t['TaskID']) . '">'
               . '<select name="tech">' . select_options($techOptions, 'v', 'l', $t['TechnicianID']) . '</select>'
               . '<button>Αλλαγή τεχνικού</button></form>';
        }
        if ($t['Status'] === 'Assigned' || $t['Status'] === 'Accepted') {
            echo '<form method="post" onsubmit="return confirm(\'Να ακυρωθεί η εργασία;\')">' . csrf_field()
               . '<input type="hidden" name="action" value="cancel">'
               . '<input type="hidden" name="task" value="' . h($t['TaskID']) . '">'
               . '<input name="reason" placeholder="Λόγος" required maxlength="400">'
               . '<button class="danger">Ακύρωση</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
}
?>
<h2>Νέα εργασία</h2>
<?php if ($requests): ?>
<p class="muted">Αιτήματα που περιμένουν ανάθεση (δώστε τον αριθμό στο πεδίο «Αίτημα»):</p>
<?php print_table($requests, ['RequestID' => 'Αίτημα', 'RequestType' => 'Τύπος', 'Description' => 'Περιγραφή',
    'SubmittedAt' => 'Υποβλήθηκε', 'UserID' => 'Καταναλωτής', 'PremiseID' => 'Υποστατικό', 'Address' => 'Διεύθυνση', 'MeterID' => 'Μετρητής']); ?>
<?php endif; ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="create">
  <label>Τύπος
    <select name="type">
      <option>Installation</option><option>Replacement</option>
      <option>Technical check</option><option>Anti-tamper check</option>
    </select>
  </label>
  <label>Από <input type="datetime-local" name="from" required></label>
  <label>Έως <input type="datetime-local" name="to" required></label>
  <label>Τεχνικός <select name="tech" required><?= select_options($techOptions, 'v', 'l') ?></select></label>
  <label>Αίτημα καταναλωτή (προαιρετικό) <input name="request" inputmode="numeric" pattern="[0-9]*"></label>
  <label>Υποστατικό (ID) <input name="premise" inputmode="numeric" pattern="[0-9]*"></label>
  <label>Μετρητής (ID, μόνο για Replacement/έλεγχο) <input name="meter" inputmode="numeric" pattern="[0-9]*"></label>
  <label>Ειδοποίηση χρηστών (ID χωρισμένα με κόμμα) <input name="notify" maxlength="200"></label>
  <button type="submit">Δημιουργία εργασίας</button>
</form>
<?php page_footer();
