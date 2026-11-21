<?php // MENU: Τα έγγραφά μου
// =====================================================================
// technician/10_documents.php : ΙΙΙ.2.1 έγγραφα τεχνικού (ID card, Installer licence, Training certificate).
// Procedures: sp_tech_add_document, sp_tech_list_documents
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Technician');

$types = [
    ['v' => 'ID card', 'l' => 'Ταυτότητα (ID card)'],
    ['v' => 'Installer licence', 'l' => 'Άδεια εγκαταστάτη (Installer licence)'],
    ['v' => 'Training certificate', 'l' => 'Πιστοποιητικό εκπαίδευσης (Training certificate)'],
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $r = call_proc('sp_tech_add_document', [
        uid(), $_POST['type'] ?? '', trim($_POST['number'] ?? ''), post_or_null('issue'),
        post_or_null('expiry'), trim($_POST['file'] ?? ''),
    ]);
    if ($r === false) {
        if (last_error() !== null) { flash(last_error(), 'error'); }
    } else {
        flash('Το έγγραφο καταχωρίστηκε και περιμένει έλεγχο.');
    }
    redirect('technician/10_documents.php');
}

page_header('Τα έγγραφά μου');
$docs = call_proc('sp_tech_list_documents', [uid()]);
print_table($docs, [
    'DocumentID' => '#', 'DocType' => 'Τύπος', 'DocNumber' => 'Αριθμός', 'IssueDate' => 'Έκδοση',
    'ExpiryDate' => 'Λήξη', 'FilePath' => 'Αρχείο', 'ReviewStatus' => 'Έλεγχος',
    'ReviewComment' => 'Σχόλιο', 'ReviewedAt' => 'Ελέγχθηκε',
]);
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <h2>Νέο έγγραφο</h2>
  <label>Τύπος
    <select name="type" required><?= select_options($types, 'v', 'l', null, '— επιλέξτε —') ?></select>
  </label>
  <label>Αριθμός <input name="number" maxlength="50" required></label>
  <label>Ημερομηνία έκδοσης <input type="date" name="issue" required></label>
  <label>Ημερομηνία λήξης (αν υπάρχει) <input type="date" name="expiry"></label>
  <label>Αρχείο (διαδρομή) <input name="file" maxlength="400" required></label>
  <button type="submit">Καταχώριση</button>
</form>
<?php page_footer();
