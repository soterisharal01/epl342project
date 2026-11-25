<?php // MENU: Διατήρηση δεδομένων
// GDP-2: προεπισκόπηση και εκκαθάριση παλιών μετρήσεων (ωμές + επικυρωμένες). Τα aggregates μένουν.
// Κανόνας: 36 μήνες, ή 1 μήνας για καταναλωτή με εφαρμοσμένο αίτημα GDPR (ανάλογα με τον κάτοχο την ώρα της μέτρησης).
require_once __DIR__ . '/../layout.php';
require_role('Admin');

// Προαιρετική ημερομηνία αναφοράς (για επίδειξη). Κενό = τώρα (UTC).
function retention_asof(string $raw): ?string
{
    $raw = trim($raw);
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw) ? $raw : null;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $asof = retention_asof((string)($_POST['asof'] ?? ''));
    $r = call_proc('sp_retention_purge', [uid(), $asof]);
    if ($r === false) {
        flash(last_error(), 'error');
    } else {
        $x = $r[0] ?? [];
        flash('Η εκκαθάριση ολοκληρώθηκε: ωμές ' . h($x['RawDeleted'] ?? 0) . ', επικυρωμένες ' . h($x['ValidatedDeleted'] ?? 0)
            . ', διορθώσεις ' . h($x['EditsDeleted'] ?? 0) . '.');
    }
    redirect('admin/gdp_retention.php' . ($asof ? '?asof=' . urlencode($asof) : ''));
}

$asof = retention_asof((string)($_GET['asof'] ?? ''));
page_header('Διατήρηση δεδομένων');
?>
<p>Οι ωμές και οι επικυρωμένες μετρήσεις κρατιούνται 36 μήνες, ή 1 μήνα αν ο καταναλωτής που κρατούσε το υποστατικό
   εκείνη την ώρα έχει εφαρμοσμένο αίτημα GDPR. Τα aggregates και τα δεδομένα μετασχηματιστών μένουν για πάντα.
   Μια ημέρα ενέργειας (1.8.0/2.8.0) που δεν έχει ακόμη ημερήσιο aggregate <strong>δεν σβήνεται</strong>, ώστε να μη χαθεί
   το άθροισμά της· σβήνεται στην επόμενη εκκαθάριση, αφού το DSO χτίσει τα aggregates.</p>
<form method="get" class="box">
  <label>Ημερομηνία αναφοράς (προαιρετικά)
    <input type="date" name="asof" value="<?= h($asof ?? '') ?>"></label>
  <button type="submit">Προεπισκόπηση</button>
</form>
<?php
$rows = call_proc('sp_retention_preview', [uid(), $asof]);
print_table($rows, [
    'MeterID' => 'Μετρητής', 'SerialNumber' => 'Σειριακός', 'RetentionMonths' => 'Μήνες διατήρησης', 'Cutoff' => 'Όριο',
    'RawToDelete' => 'Ωμές προς διαγραφή', 'ValidatedToDelete' => 'Επικυρωμένες προς διαγραφή',
    'EditsToDelete' => 'Διορθώσεις προς διαγραφή', 'AsOf' => 'Ως',
]);
?>
<form method="post" class="box" onsubmit="return confirm('Οι μετρήσεις που λήγουν θα διαγραφούν οριστικά. Συνέχεια;')">
  <?= csrf_field() ?>
  <input type="hidden" name="asof" value="<?= h($asof ?? '') ?>">
  <button type="submit">Εκκαθάριση τώρα<?= $asof ? ' (ως ' . h($asof) . ')' : '' ?></button>
</form>
<?php page_footer();
