<?php // MENU: Τιμολόγια και πληρωμές
// =====================================================================
// consumer/40_billing.php : ΙΙΙ.1.3 ιστορικό χρεώσεων και πληρωμών, εξόφληση.
// Procedures: sp_consumer_list_invoices, sp_consumer_list_payments,
//             sp_consumer_pay_invoice, sp_consumer_list_bank_accounts
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Consumer');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $r = call_proc('sp_consumer_pay_invoice', [
        uid(), (int)$_POST['invoice'], (int)$_POST['account'], (float)str_replace(',', '.', $_POST['amount'] ?? '0'),
    ]);
    if ($r === false) {
        flash(last_error(), 'error');
    } else {
        flash($r[0]['NewStatus'] === 'Paid' ? 'Το τιμολόγιο εξοφλήθηκε.'
            : 'Η πληρωμή καταχωρήθηκε. Υπόλοιπο: ' . number_format((float)$r[0]['Remaining'], 2, ',', '.') . ' €');
    }
    redirect('consumer/40_billing.php');
}

$year = isset($_GET['year']) && $_GET['year'] !== '' ? (int)$_GET['year'] : null;
page_header('Τιμολόγια και πληρωμές');
$accounts = call_proc('sp_consumer_list_bank_accounts', [uid()]) ?: [];
?>
<form method="get" class="inline-form">
  Έτος <input name="year" type="number" min="2000" max="2100" value="<?= h($year) ?>" style="width:7em">
  <button type="submit">Φίλτρο</button>
</form>
<?php
$inv = call_proc('sp_consumer_list_invoices', [uid(), $year]);
if ($inv) {
    echo '<table class="data"><tr><th>#</th><th>Έκδοση</th><th>Περίοδος</th><th>Υποστατικό</th><th>Προμηθευτής</th>'
       . '<th>Ποσό €</th><th>Πληρώθηκαν €</th><th>Υπόλοιπο €</th><th>Κατάσταση</th><th>Πληρωμή</th></tr>';
    foreach ($inv as $i) {
        echo '<tr><td>' . h($i['InvoiceID']) . '</td><td>' . h($i['IssueDate']) . '</td><td>' . h($i['PeriodFrom'] . ' – ' . $i['PeriodTo'])
           . '</td><td>' . h($i['Address'] ?? '') . '</td><td>' . h($i['Supplier'] ?? '') . '</td><td>' . money($i['Amount'])
           . '</td><td>' . money($i['Paid']) . '</td><td>' . money($i['Remaining']) . '</td><td>' . h($i['Status']) . '</td><td>';
        if ((float)$i['Remaining'] > 0 && $accounts) {
            echo '<form method="post" class="inline-form">' . csrf_field()
               . '<input type="hidden" name="invoice" value="' . h($i['InvoiceID']) . '">'
               . '<input name="amount" value="' . h($i['Remaining']) . '" inputmode="decimal" style="width:6em">'
               . '<select name="account">' . select_options($accounts, 'BankAccountID', 'IBAN') . '</select>'
               . '<button>Πληρωμή</button></form>';
        }
        echo '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($inv);
}
if (!$accounts) {
    echo '<p class="muted">Για να πληρώσετε, προσθέστε πρώτα <a href="20_bank.php">τραπεζικό λογαριασμό</a>.</p>';
}
?>
<h2>Πληρωμές</h2>
<?php
print_table(call_proc('sp_consumer_list_payments', [uid()]),
    ['PaymentID' => '#', 'PaidAt' => 'Ημερομηνία', 'Amount' => 'Ποσό €', 'InvoiceID' => 'Τιμολόγιο', 'IBAN' => 'Λογαριασμός', 'Reference' => 'Αναφορά']);
page_footer();
