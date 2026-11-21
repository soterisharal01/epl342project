<?php // MENU: Χρήστες
// =====================================================================
// admin/10_users.php : λογαριασμοί προσωπικού (ADM-4 για ADM-2).
// Λίστα χρηστών με φίλτρο ρόλου, δημιουργία λογαριασμού, αναστολή/ενεργοποίηση.
// Procedures: sp_admin_list_users, sp_admin_create_user, sp_admin_set_account_status,
//             sp_admin_list_companies
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Admin');

$staffRoles = ['Operator' => 'Χειριστής', 'DSO' => 'ΔΣΜ (DSO)', 'TSO' => 'ΔΣΜΗΚ (TSO)',
               'Supplier' => 'Προμηθευτής', 'Aggregator' => 'Αθροιστής'];
$allRoles = ['Admin' => 'Διαχειριστής', 'Operator' => 'Χειριστής', 'Consumer' => 'Καταναλωτής',
             'Technician' => 'Τεχνικός', 'DSO' => 'ΔΣΜ (DSO)', 'TSO' => 'ΔΣΜΗΚ (TSO)',
             'Supplier' => 'Προμηθευτής', 'Aggregator' => 'Αθροιστής'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';
    if ($action === 'status') {
        $new = ($_POST['status'] ?? '') === 'Suspended' ? 'Suspended' : 'Active';
        $r = call_proc('sp_admin_set_account_status', [uid(), (int)($_POST['target'] ?? 0), $new]);
        $r === false ? flash(last_error(), 'error')
                     : flash($new === 'Suspended' ? 'Ο λογαριασμός ανεστάλη.' : 'Ο λογαριασμός ενεργοποιήθηκε.');
    } else {
        $role = $_POST['role'] ?? '';
        $password = (string)($_POST['password'] ?? '');
        $company = (int)($_POST['company'] ?? 0);
        if (strlen($password) < 8) {
            flash('Ο κωδικός πρέπει να έχει τουλάχιστον 8 χαρακτήρες.', 'error');
        } else {
            $r = call_proc('sp_admin_create_user', [
                uid(), $role, trim($_POST['username'] ?? ''), password_hash($password, PASSWORD_DEFAULT),
                trim($_POST['email'] ?? ''), post_or_null('phone'),
                trim($_POST['first'] ?? ''), trim($_POST['last'] ?? ''),
                $role === 'Supplier' && $company > 0 ? $company : null,
                $role === 'Aggregator' && $company > 0 ? $company : null,
            ]);
            $r === false ? flash(last_error(), 'error') : flash('Ο λογαριασμός δημιουργήθηκε.');
        }
    }
    $f = $_POST['filter'] ?? '';
    redirect('admin/10_users.php' . (isset($allRoles[$f]) ? '?role=' . urlencode($f) : ''));
}

page_header('Χρήστες');
$filter = $_GET['role'] ?? '';
if (!isset($allRoles[$filter])) { $filter = ''; }
?>
<form method="get" class="inline-form">
  <label>Ρόλος
    <select name="role"><?= select_options(array_map(fn($k, $v) => ['k' => $k, 'v' => $v], array_keys($allRoles), $allRoles), 'k', 'v', $filter, 'Όλοι') ?></select></label>
  <button type="submit">Φίλτρο</button>
</form>
<?php
$rows = call_proc('sp_admin_list_users', [uid(), $filter === '' ? null : $filter]);
if ($rows === false) {
    print_table($rows);
} elseif (!$rows) {
    echo '<p class="muted">Δεν υπάρχουν χρήστες.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Όνομα χρήστη</th><th>Ρόλος</th><th>Ονοματεπώνυμο</th><th>Email</th>'
       . '<th>Εταιρεία</th><th>Κατάσταση</th><th>Δημιουργία</th><th></th></tr>';
    foreach ($rows as $u) {
        $active = $u['AccountStatus'] === 'Active';
        echo '<tr><td>' . h($u['UserID']) . '</td><td>' . h($u['Username']) . '</td><td>' . h($allRoles[$u['Role']] ?? $u['Role'])
           . '</td><td>' . h($u['FirstName'] . ' ' . $u['LastName']) . '</td><td>' . h($u['Email'])
           . '</td><td>' . h($u['Company'] ?? '') . '</td><td>' . h($active ? 'Ενεργός' : 'Σε αναστολή')
           . '</td><td>' . h($u['CreatedAt']) . '</td><td>';
        if ((int)$u['UserID'] !== uid() || !$active) {
            echo '<form method="post">' . csrf_field()
               . '<input type="hidden" name="action" value="status">'
               . '<input type="hidden" name="target" value="' . h($u['UserID']) . '">'
               . '<input type="hidden" name="filter" value="' . h($filter) . '">'
               . '<input type="hidden" name="status" value="' . ($active ? 'Suspended' : 'Active') . '">'
               . '<button class="' . ($active ? 'danger' : '') . '">' . ($active ? 'Αναστολή' : 'Ενεργοποίηση') . '</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
}
$companies = call_proc('sp_admin_list_companies', [uid()]) ?: [];
$typeLabel = ['Supplier' => 'Προμηθευτής', 'Aggregator' => 'Αθροιστής'];
?>
<h2>Νέος λογαριασμός προσωπικού</h2>
<form method="post" class="box" id="newuser">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="create">
  <input type="hidden" name="filter" value="<?= h($filter) ?>">
  <label>Ρόλος
    <select name="role" id="role" required>
      <?php foreach ($staffRoles as $k => $v): ?>
        <option value="<?= h($k) ?>"><?= h($v) ?></option>
      <?php endforeach; ?>
    </select></label>
  <label id="companyrow" style="display:none">Εταιρεία (μόνο Προμηθευτής / Αθροιστής)
    <select name="company" id="company">
      <option value="">—</option>
      <?php foreach ($companies as $c): ?>
        <option value="<?= h($c['CompanyID']) ?>" data-type="<?= h($c['CompanyType']) ?>"><?= h(($typeLabel[$c['CompanyType']] ?? '') . ': ' . $c['Name']) ?></option>
      <?php endforeach; ?>
    </select></label>
  <label>Όνομα χρήστη <input name="username" required maxlength="50" autocomplete="off"></label>
  <label>Κωδικός (τουλάχιστον 8 χαρακτήρες) <input name="password" type="password" required minlength="8" autocomplete="new-password"></label>
  <label>Όνομα <input name="first" required maxlength="50"></label>
  <label>Επώνυμο <input name="last" required maxlength="50"></label>
  <label>Email <input name="email" type="email" required maxlength="254"></label>
  <label>Τηλέφωνο (προαιρετικό) <input name="phone" maxlength="20"></label>
  <button type="submit">Δημιουργία</button>
</form>
<script>
// Η λίστα εταιρειών δείχνει μόνο όσες ταιριάζουν στον ρόλο (Προμηθευτής ή Αθροιστής).
(function () {
  var role = document.getElementById('role'), row = document.getElementById('companyrow'), sel = document.getElementById('company');
  function sync() {
    var need = role.value === 'Supplier' || role.value === 'Aggregator';
    row.style.display = need ? '' : 'none';
    for (var i = 0; i < sel.options.length; i++) {
      var t = sel.options[i].getAttribute('data-type');
      sel.options[i].hidden = t !== null && t !== role.value;
    }
    sel.value = '';
    if (!need) { sel.value = ''; }
  }
  role.addEventListener('change', sync);
  sync();
})();
</script>
<?php page_footer();
