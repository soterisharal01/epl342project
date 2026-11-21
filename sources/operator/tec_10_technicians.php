<?php // MENU: Έγκριση τεχνικών
// =====================================================================
// operator/tec_10_technicians.php : ΙΙΙ.2.1 έγκριση/απόρριψη τεχνικών και έλεγχος εγγράφων.
// Έγκριση μόνο με αποδεκτό, μη ληγμένο έγγραφο για καθέναν από τους 3 τύπους.
// Procedures: sp_operator_list_pending_technicians, sp_operator_list_technician_documents,
//             sp_operator_review_document, sp_operator_decide_technician, sp_operator_set_technician_status
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Operator');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $tech = (int)($_POST['tech'] ?? 0);
    switch ($_POST['action'] ?? '') {
        case 'review':
            $r = call_proc('sp_operator_review_document', [
                uid(), (int)($_POST['doc'] ?? 0), ($_POST['accept'] ?? '') === '1' ? 1 : 0, post_or_null('comment'),
            ]);
            $ok = 'Ο έλεγχος του εγγράφου καταχωρίστηκε.';
            break;
        case 'decide':
            $r = call_proc('sp_operator_decide_technician', [
                uid(), $tech, ($_POST['approve'] ?? '') === '1' ? 1 : 0, post_or_null('comment'),
            ]);
            $ok = 'Η απόφαση καταχωρίστηκε.';
            break;
        case 'status':
            $r = call_proc('sp_operator_set_technician_status', [
                uid(), $tech, $_POST['status'] ?? '', post_or_null('comment'),
            ]);
            $ok = 'Η κατάσταση άλλαξε.';
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
    redirect('operator/tec_10_technicians.php' . ($tech ? '?tech=' . $tech : ''));
}

page_header('Έγκριση τεχνικών');
$pending = call_proc('sp_operator_list_pending_technicians', [uid()]);
if ($pending === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
} elseif (!$pending) {
    echo '<p class="muted">Δεν υπάρχουν τεχνικοί σε εκκρεμότητα.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Όνομα χρήστη</th><th>Ονοματεπώνυμο</th><th>Email</th><th>Κατηγορίες</th>'
       . '<th>Έγγραφα (εκκρεμή / αποδεκτά / απορριφθέντα)</th><th></th></tr>';
    foreach ($pending as $t) {
        echo '<tr><td>' . h($t['TechnicianID']) . '</td><td>' . h($t['Username']) . '</td><td>'
           . h($t['FirstName'] . ' ' . $t['LastName']) . '</td><td>' . h($t['Email']) . '</td><td>' . h($t['Categories'])
           . '</td><td>' . h($t['DocsPending'] . ' / ' . $t['DocsAccepted'] . ' / ' . $t['DocsRejected'])
           . '</td><td><a href="?tech=' . h($t['TechnicianID']) . '">Έλεγχος</a></td></tr>';
    }
    echo '</table>';
}

$sel = (int)($_GET['tech'] ?? 0);
if ($sel > 0) {
    echo '<h2>Τεχνικός ' . h($sel) . '</h2>';
    $docs = call_proc('sp_operator_list_technician_documents', [uid(), $sel]);
    if ($docs === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } elseif (!$docs) {
        echo '<p class="muted">Δεν έχει καταθέσει έγγραφα.</p>';
    } else {
        echo '<table class="data"><tr><th>#</th><th>Τύπος</th><th>Αριθμός</th><th>Έκδοση</th><th>Λήξη</th><th>Αρχείο</th>'
           . '<th>Έλεγχος</th><th>Σχόλιο</th><th></th></tr>';
        foreach ($docs as $d) {
            echo '<tr><td>' . h($d['DocumentID']) . '</td><td>' . h($d['DocType']) . '</td><td>' . h($d['DocNumber'])
               . '</td><td>' . h($d['IssueDate']) . '</td><td>' . h($d['ExpiryDate'] ?? '—') . '</td><td>' . h($d['FilePath'])
               . '</td><td>' . h($d['ReviewStatus']) . '</td><td>' . h($d['ReviewComment'] ?? '') . '</td><td>';
            if ($d['ReviewStatus'] === 'Pending') {
                echo '<form method="post">' . csrf_field() . '<input type="hidden" name="action" value="review">'
                   . '<input type="hidden" name="tech" value="' . h($sel) . '">'
                   . '<input type="hidden" name="doc" value="' . h($d['DocumentID']) . '">'
                   . '<input name="comment" placeholder="Σχόλιο (υποχρεωτικό για απόρριψη)">'
                   . '<button name="accept" value="1">Αποδοχή</button> <button name="accept" value="0">Απόρριψη</button></form>';
            }
            echo '</td></tr>';
        }
        echo '</table>';
    }
    ?>
    <form method="post" class="box">
      <?= csrf_field() ?>
      <input type="hidden" name="action" value="decide">
      <input type="hidden" name="tech" value="<?= h($sel) ?>">
      <h3>Απόφαση για τον τεχνικό (μόνο όσο είναι Pending)</h3>
      <label>Σχόλιο <input name="comment" maxlength="500"></label>
      <button name="approve" value="1">Έγκριση</button>
      <button name="approve" value="0">Απόρριψη (απαιτεί σχόλιο)</button>
    </form>
    <form method="post" class="box">
      <?= csrf_field() ?>
      <input type="hidden" name="action" value="status">
      <input type="hidden" name="tech" value="<?= h($sel) ?>">
      <h3>Αναστολή / επαναφορά εγκεκριμένου τεχνικού</h3>
      <label>Σχόλιο <input name="comment" maxlength="500"></label>
      <button name="status" value="Suspended">Αναστολή (απαιτεί σχόλιο)</button>
      <button name="status" value="Approved">Επαναφορά</button>
    </form>
    <?php
}
page_footer();
