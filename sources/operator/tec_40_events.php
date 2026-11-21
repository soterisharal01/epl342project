<?php // MENU: Συμβάντα / anti-tamper
// =====================================================================
// operator/tec_40_events.php : ΙΙΙ.2.4 ανοιχτά συμβάντα -> εργασία anti-tamper (X4),
// και έγκριση / παρακολούθηση εντολών εξ αποστάσεως (B15).
// Procedures: sp_operator_list_open_events, sp_event_create_task, sp_task_list_technicians,
//             sp_command_list, sp_operator_approve_command, sp_command_record_attempt, sp_command_list_attempts
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Operator');

// Τιμή datetime-local (2027-06-15T09:00) -> 'Y-m-d H:i:s' για το SQL Server.
function event_dt(string $v): ?string
{
    $v = trim(str_replace('T', ' ', $v));
    if ($v === '') { return null; }
    return strlen($v) === 16 ? $v . ':00' : $v;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    switch ($_POST['action'] ?? '') {
        case 'create_task':
            $r = call_proc('sp_event_create_task', [
                uid(), (int)($_POST['event'] ?? 0), (int)($_POST['tech'] ?? 0),
                event_dt($_POST['from'] ?? ''), event_dt($_POST['to'] ?? ''),
            ]);
            $ok = 'Δημιουργήθηκε εργασία anti-tamper και το συμβάν είναι In progress.';
            break;
        case 'command':
            $approve = ($_POST['decision'] ?? '') === 'approve' ? 1 : 0;
            $r = call_proc('sp_operator_approve_command', [uid(), (int)($_POST['command'] ?? 0), $approve, post_or_null('comment')]);
            $ok = $approve ? 'Η εντολή εγκρίθηκε και στάλθηκε.' : 'Η εντολή απορρίφθηκε.';
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
    redirect('operator/tec_40_events.php');
}

page_header('Συμβάντα / anti-tamper');
$techOptions = [];
foreach (call_proc('sp_task_list_technicians', [uid()]) ?: [] as $t) {
    $techOptions[] = ['v' => $t['UserID'], 'l' => $t['Username'] . ' (' . $t['FirstName'] . ' ' . $t['LastName'] . ')'];
}
$events = call_proc('sp_operator_list_open_events', [uid()]);
?>
<h2>Ανοιχτά συμβάντα</h2>
<?php
if ($events === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$events) {
    echo '<p class="muted">Δεν υπάρχουν ανοιχτά συμβάντα.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Είδος</th><th>Σοβαρότητα</th><th>Περιγραφή</th><th>Πότε</th>'
       . '<th>Μετρητής</th><th>Εργασία προέλευσης</th><th>Νέα εργασία anti-tamper</th></tr>';
    foreach ($events as $e) {
        echo '<tr><td>' . h($e['EventID']) . '</td><td>' . h($e['EventType']) . '</td><td>' . h($e['Severity'])
           . '</td><td>' . h($e['Description'] ?? '') . '</td><td>' . h($e['OccurredAt'])
           . '</td><td>' . h($e['SerialNumber'] ?? '—') . '</td><td>' . h($e['SourceTaskID'] ?? '—') . '</td><td>';
        if ($e['MeterID'] !== null) {
            echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="create_task">'
               . '<input type="hidden" name="event" value="' . h($e['EventID']) . '">'
               . '<select name="tech" required>' . select_options($techOptions, 'v', 'l') . '</select>'
               . '<input type="datetime-local" name="from" required> <input type="datetime-local" name="to" required>'
               . '<button>Δημιουργία εργασίας</button></form>';
        } else {
            echo '<span class="muted">Χωρίς μετρητή</span>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
}
?>
<h2>Εντολές εξ αποστάσεως</h2>
<?php
$cmds = call_proc('sp_command_list', [uid(), null]);
if ($cmds === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$cmds) {
    echo '<p class="muted">Δεν υπάρχουν εντολές.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Εντολή</th><th>Μετρητής</th><th>Παράμετροι</th><th>Ζητήθηκε από</th>'
       . '<th>Ζητήθηκε</th><th>Κατάσταση</th><th>Προσπάθειες</th><th>Τελευταίο</th><th></th></tr>';
    foreach ($cmds as $c) {
        echo '<tr><td>' . h($c['CommandID']) . '</td><td>' . h($c['CommandType']) . '</td><td>' . h($c['SerialNumber'])
           . '</td><td>' . h($c['Parameters'] ?? '') . '</td><td>' . h($c['RequestedByUsername'])
           . '</td><td>' . h($c['RequestedAt']) . '</td><td>' . h($c['Status']) . '</td><td>' . h($c['Attempts'])
           . '</td><td>' . h($c['LastOutcome'] ?? '—') . '</td><td><a href="?cmd=' . h($c['CommandID']) . '">Προσπάθειες</a>';
        if ($c['Status'] === 'Awaiting approval') {
            echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="command">'
               . '<input type="hidden" name="command" value="' . h($c['CommandID']) . '">'
               . '<input name="comment" placeholder="Σχόλιο (υποχρεωτικό στην απόρριψη)" maxlength="500">'
               . '<button name="decision" value="approve">Έγκριση</button>'
               . '<button name="decision" value="reject" class="danger">Απόρριψη</button></form>';
        } elseif ($c['Status'] === 'Sent') {
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
page_footer();
