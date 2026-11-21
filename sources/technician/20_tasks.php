<?php // MENU: Οι εργασίες μου
// =====================================================================
// technician/20_tasks.php : ΙΙΙ.2.2 εργασίες πεδίου του τεχνικού.
// Λίστα δικών μου εργασιών (με συντεταγμένες), αποδοχή, σημειώσεις, συνημμένο, ολοκλήρωση.
// Procedures: sp_tech_list_tasks, sp_tech_accept_task, sp_tech_add_note,
//             sp_tech_add_attachment, sp_tech_complete_task, sp_task_get, sp_task_notes, sp_task_attachments
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Technician');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $task = (int)($_POST['task'] ?? 0);
    switch ($_POST['action'] ?? '') {
        case 'accept':
            $r = call_proc('sp_tech_accept_task', [uid(), $task]);
            $ok = 'Η εργασία έγινε αποδεκτή.';
            break;
        case 'note':
            $r = call_proc('sp_tech_add_note', [uid(), $task, $_POST['kind'] ?? '', trim($_POST['text'] ?? '')]);
            $ok = 'Η σημείωση καταχωρίστηκε.';
            break;
        case 'attach':
            $r = call_proc('sp_tech_add_attachment', [uid(), $task, trim($_POST['path'] ?? ''), post_or_null('caption')]);
            $ok = 'Το συνημμένο καταχωρίστηκε.';
            break;
        case 'complete':
            $r = call_proc('sp_tech_complete_task', [uid(), $task, trim($_POST['result'] ?? '')]);
            $ok = 'Η εργασία ολοκληρώθηκε.';
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
    redirect('technician/20_tasks.php' . ($task ? '?task=' . $task : ''));
}

page_header('Οι εργασίες μου');
$filter = $_GET['status'] ?? '';
$tasks = call_proc('sp_tech_list_tasks', [uid(), $filter === '' ? null : $filter]);
?>
<form method="get" class="box">
  <label>Κατάσταση
    <select name="status">
      <?= select_options([
          ['v' => 'Assigned', 'l' => 'Assigned'], ['v' => 'Accepted', 'l' => 'Accepted'],
          ['v' => 'Done', 'l' => 'Done'], ['v' => 'Cancelled', 'l' => 'Cancelled'],
      ], 'v', 'l', $filter, 'Όλες') ?>
    </select>
  </label>
  <button type="submit">Φίλτρο</button>
</form>
<?php
if ($tasks === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$tasks) {
    echo '<p class="muted">Δεν υπάρχουν εργασίες.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Τύπος</th><th>Από</th><th>Έως</th><th>Κατάσταση</th><th>Διεύθυνση</th>'
       . '<th>Πλάτος, Μήκος</th><th>Μετρητής</th><th>Αίτημα</th><th></th></tr>';
    foreach ($tasks as $t) {
        echo '<tr><td>' . h($t['TaskID']) . '</td><td>' . h($t['TaskType']) . '</td><td>' . h($t['ScheduledFrom'])
           . '</td><td>' . h($t['ScheduledTo']) . '</td><td>' . h($t['Status']) . '</td><td>' . h($t['Address'] ?? '—')
           . '</td><td>' . h(($t['Latitude'] ?? '') . ', ' . ($t['Longitude'] ?? ''))
           . '</td><td>' . h($t['SerialNumber'] ?? '—') . '</td><td>' . h($t['RequestDescription'] ?? '—') . '</td><td>';
        if ($t['Status'] === 'Assigned') {
            echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="accept">'
               . '<input type="hidden" name="task" value="' . h($t['TaskID']) . '"><button>Αποδοχή</button></form>';
        }
        echo '<a href="?task=' . h($t['TaskID']) . '">Λεπτομέρειες</a></td></tr>';
    }
    echo '</table>';
}

$sel = (int)($_GET['task'] ?? 0);
if ($sel > 0) {
    $detail = call_proc('sp_task_get', [uid(), $sel]);
    if ($detail === false || !$detail) {
        echo '<p class="error">' . h(last_error() ?? 'Η εργασία δεν βρέθηκε.') . '</p>';
    } else {
        $d = $detail[0];
        echo '<h2>Εργασία ' . h($d['TaskID']) . ' (' . h($d['TaskType']) . ', ' . h($d['Status']) . ')</h2>';
        if ($d['Result'] !== null) {
            echo '<p><strong>Αποτέλεσμα:</strong> ' . h($d['Result']) . '</p>';
        }
        echo '<h3>Σημειώσεις</h3>';
        print_table(call_proc('sp_task_notes', [uid(), $sel]),
            ['NoteNo' => 'Α/Α', 'NoteKind' => 'Είδος', 'Text' => 'Κείμενο', 'WrittenAt' => 'Πότε',
             'WrittenBy' => 'ID', 'WrittenByUsername' => 'Χρήστης']);
        echo '<h3>Συνημμένα</h3>';
        print_table(call_proc('sp_task_attachments', [uid(), $sel]),
            ['AttachmentID' => '#', 'FilePath' => 'Αρχείο', 'Caption' => 'Λεζάντα', 'UploadedAt' => 'Πότε']);
        if ($d['Status'] !== 'Cancelled') {
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="note">
  <input type="hidden" name="task" value="<?= h($sel) ?>">
  <h3>Νέα σημείωση</h3>
  <label>Είδος
    <select name="kind"><option value="Observation">Παρατήρηση</option><option value="Finding">Εύρημα</option></select>
  </label>
  <label>Κείμενο <textarea name="text" required maxlength="2000"></textarea></label>
  <button type="submit">Προσθήκη σημείωσης</button>
</form>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="attach">
  <input type="hidden" name="task" value="<?= h($sel) ?>">
  <h3>Συνημμένο (διαδρομή αρχείου)</h3>
  <label>Διαδρομή <input name="path" required maxlength="400"></label>
  <label>Λεζάντα <input name="caption" maxlength="200"></label>
  <button type="submit">Προσθήκη συνημμένου</button>
</form>
<?php
        }
        if ($d['Status'] === 'Accepted') {
?>
<form method="post" class="box" onsubmit="return confirm('Να ολοκληρωθεί η εργασία;')">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="complete">
  <input type="hidden" name="task" value="<?= h($sel) ?>">
  <h3>Ολοκλήρωση</h3>
  <label>Αποτέλεσμα <textarea name="result" required maxlength="1000"></textarea></label>
  <button type="submit">Ολοκλήρωση εργασίας</button>
</form>
<?php
        }
    }
}
page_footer();
