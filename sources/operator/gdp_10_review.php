<?php // MENU: Αιτήματα GDPR
// =====================================================================
// operator/gdp_10_review.php : ΙΙΙ.1.4 εξέταση και προέγκριση αιτημάτων διαγραφής.
// Procedures: sp_gdpr_list, sp_gdpr_start_review, sp_gdpr_preapprove
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Operator');

$statuses = ['Submitted', 'Under review', 'Pre-approved', 'Approved', 'Rejected', 'Applied'];
$filter = isset($_GET['status']) && in_array($_GET['status'], $statuses, true) ? $_GET['status'] : null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $id = (int)($_POST['id'] ?? 0);
    $act = (string)($_POST['action'] ?? '');
    if ($act === 'review') {
        $r = call_proc('sp_gdpr_start_review', [uid(), $id]);
        $msg = 'Η εξέταση του αιτήματος ' . $id . ' ξεκίνησε.';
    } elseif ($act === 'approve' || $act === 'reject') {
        $r = call_proc('sp_gdpr_preapprove', [uid(), $id, $act === 'approve' ? 1 : 0, post_or_null('comment')]);
        $msg = $act === 'approve' ? 'Το αίτημα ' . $id . ' προεγκρίθηκε.' : 'Το αίτημα ' . $id . ' απορρίφθηκε.';
    } else {
        $r = false;
        $msg = '';
        flash('Άγνωστη ενέργεια.', 'error');
        redirect('operator/gdp_10_review.php');
    }
    if ($r === false) {
        flash(last_error(), 'error');
    } else {
        flash($msg);
    }
    redirect('operator/gdp_10_review.php' . ($filter ? '?status=' . urlencode($filter) : ''));
}

page_header('Αιτήματα GDPR');
?>
<form method="get" class="inline-form">
  Κατάσταση
  <select name="status">
    <option value="">Όλες</option>
    <?php foreach ($statuses as $s): ?>
    <option value="<?= h($s) ?>"<?= $s === $filter ? ' selected' : '' ?>><?= h($s) ?></option>
    <?php endforeach; ?>
  </select>
  <button type="submit">Φίλτρο</button>
</form>
<?php
$rows = call_proc('sp_gdpr_list', [uid(), $filter]);
if ($rows === false || !$rows) {
    print_table($rows);
} else {
    echo '<table class="data"><tr><th>#</th><th>Υποβλήθηκε</th><th>Καταναλωτής</th><th>Κατάσταση</th><th>Εξέταση από</th>'
       . '<th>Απόφαση Admin</th><th>Ενέργεια</th></tr>';
    foreach ($rows as $q) {
        echo '<tr><td>' . h($q['GdprRequestID']) . '</td><td>' . h($q['SubmittedAt']) . '</td><td>'
           . h($q['Username'] . ' (' . $q['FirstName'] . ' ' . $q['LastName'] . ')') . '</td><td>' . h($q['Status'])
           . '</td><td>' . h($q['PreApprovedByUsername'] ?? '') . ' ' . h($q['PreApprovedAt'] ?? '')
           . '</td><td>' . h($q['DecidedByUsername'] ?? '') . ' ' . h($q['DecidedAt'] ?? '') . '</td><td>';
        if (in_array($q['Status'], ['Submitted', 'Under review'], true)) {
            echo '<form method="post" class="inline-form">' . csrf_field()
               . '<input type="hidden" name="id" value="' . h($q['GdprRequestID']) . '">'
               . '<input name="comment" maxlength="500" placeholder="Σχόλιο">';
            if ($q['Status'] === 'Submitted') {
                echo '<button name="action" value="review">Έναρξη εξέτασης</button> ';
            }
            echo '<button name="action" value="approve">Προέγκριση</button> '
               . '<button name="action" value="reject">Απόρριψη</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
}
page_footer();
