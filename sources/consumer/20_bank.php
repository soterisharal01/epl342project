<?php // MENU: Τραπεζικοί λογαριασμοί
// =====================================================================
// consumer/20_bank.php : ΙΙΙ.1.1 τραπεζικοί λογαριασμοί του καταναλωτή.
// Procedures: sp_consumer_list_bank_accounts, sp_consumer_add_bank_account,
//             sp_consumer_list_premises (για τη λίστα υποστατικών)
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $premise = post_or_null('premise');
    $r = call_proc('sp_consumer_add_bank_account', [
        uid(), trim($_POST['iban'] ?? ''), trim($_POST['holder'] ?? ''), $premise === null ? null : (int)$premise,
    ]);
    $r === false ? flash(last_error(), 'error') : flash('Ο λογαριασμός προστέθηκε.');
    redirect('consumer/20_bank.php');
}

page_header('Τραπεζικοί λογαριασμοί');
print_table(call_proc('sp_consumer_list_bank_accounts', [uid()]),
    ['BankAccountID' => '#', 'IBAN' => 'IBAN', 'HolderName' => 'Δικαιούχος', 'Premises' => 'Για υποστατικά']);
$premises = array_values(array_filter(call_proc('sp_consumer_list_premises', [uid()]) ?: [], fn($p) => $p['EndDate'] === null));
$u = current_user();
?>
<h2>Νέος λογαριασμός</h2>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>IBAN <input name="iban" required maxlength="50" placeholder="CY17 0020 0128 0000 0012 0052 7600"></label>
  <label>Δικαιούχος <input name="holder" required maxlength="100" value="<?= h($u['FirstName'] . ' ' . $u['LastName']) ?>"></label>
  <label>Για υποστατικό (προαιρετικό)
    <select name="premise"><?= select_options($premises, 'PremiseID', 'Address', null, '—') ?></select></label>
  <button type="submit">Προσθήκη</button>
</form>
<?php page_footer();
