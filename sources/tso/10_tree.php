<?php // MENU: Δέντρο μετασχηματιστών
// =====================================================================
// tso/10_tree.php : ΙΙΙ.4.1 δέντρο μετασχηματιστών.
// Δείχνει το δέντρο (εσοχή ανά επίπεδο), προσθέτει νέο μετασχηματιστή με γεωφράκτη,
// βρίσκει από συντεταγμένες το φύλλο-μετασχηματιστή.
// Procedures: sp_tso_tree, sp_tso_add_transformer, sp_tso_locate
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('TSO');

function tso_num(string $key): float
{
    return (float)str_replace(',', '.', trim($_POST[$key] ?? ''));
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'add') {
    check_csrf();
    $parent = trim($_POST['parent'] ?? '');
    $r = call_proc('sp_tso_add_transformer', [
        uid(), trim($_POST['name'] ?? ''), tso_num('lat'), tso_num('lon'),
        $parent === '' ? null : (int)$parent, trim($_POST['gname'] ?? ''),
        tso_num('minlat'), tso_num('minlon'), tso_num('maxlat'), tso_num('maxlon'),
    ]);
    $r === false ? flash(last_error(), 'error') : flash('Ο μετασχηματιστής προστέθηκε.');
    redirect('tso/10_tree.php');
}

page_header('Δέντρο μετασχηματιστών');
$tree = call_proc('sp_tso_tree', [uid()]);
if ($tree) {
    echo '<table class="data"><tr><th>Μετασχηματιστής</th><th>#</th><th>Φύλλο</th><th>Μετρητές (άμεσα / συνολικά)</th>'
       . '<th>Γεωφράκτης</th><th>Όρια (πλάτος / μήκος)</th></tr>';
    foreach ($tree as $t) {
        $pad = str_repeat('&nbsp;&nbsp;&nbsp;&nbsp;', (int)$t['Level']);
        echo '<tr><td>' . $pad . h($t['Name']) . '</td><td>' . h($t['TransformerID']) . '</td><td>'
           . ($t['IsLeaf'] ? 'Ναι' : 'Όχι') . '</td><td>' . h($t['DirectMeters']) . ' / ' . h($t['TotalMeters'])
           . '</td><td>' . h($t['GeofenceName']) . '</td><td>' . h($t['MinLat'] . '–' . $t['MaxLat'] . ' / ' . $t['MinLon'] . '–' . $t['MaxLon'])
           . '</td></tr>';
    }
    echo '</table>';
} else {
    print_table($tree);
}

// --- Εύρεση φύλλου από συντεταγμένες (GET, δεν αλλάζει δεδομένα) ---
echo '<h2>Εύρεση μετασχηματιστή από συντεταγμένες</h2>';
$qlat = trim($_GET['qlat'] ?? '');
$qlon = trim($_GET['qlon'] ?? '');
?>
<form method="get" class="box">
  <label>Γεωγραφικό πλάτος <input name="qlat" required inputmode="decimal" value="<?= h($qlat) ?>"></label>
  <label>Γεωγραφικό μήκος <input name="qlon" required inputmode="decimal" value="<?= h($qlon) ?>"></label>
  <button type="submit">Εύρεση</button>
</form>
<?php
if ($qlat !== '' && $qlon !== '') {
    $found = call_proc('sp_tso_locate', [uid(), (float)str_replace(',', '.', $qlat), (float)str_replace(',', '.', $qlon)]);
    if ($found === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } elseif (!$found) {
        echo '<p>Κανένας μετασχηματιστής-φύλλο δεν καλύπτει αυτό το σημείο.</p>';
    } else {
        print_table($found, ['TransformerID' => '#', 'Name' => 'Μετασχηματιστής', 'GeofenceName' => 'Γεωφράκτης', 'Path' => 'Διαδρομή']);
    }
}
?>
<h2>Νέος μετασχηματιστής</h2>
<p>Ο γεωφράκτης του πρέπει να είναι μέσα σε αυτόν του γονέα και ο γονέας να μην έχει μετρητές. Χωρίς γονέα μόνο για την πρώτη ρίζα.</p>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="add">
  <label>Όνομα <input name="name" required maxlength="50"></label>
  <label>Γεωγραφικό πλάτος <input name="lat" required inputmode="decimal"></label>
  <label>Γεωγραφικό μήκος <input name="lon" required inputmode="decimal"></label>
  <label>Κωδικός γονέα (κενό = ρίζα) <input name="parent" inputmode="numeric" pattern="[0-9]*"></label>
  <label>Όνομα γεωφράκτη <input name="gname" required maxlength="100"></label>
  <label>Ελάχιστο πλάτος <input name="minlat" required inputmode="decimal"></label>
  <label>Ελάχιστο μήκος <input name="minlon" required inputmode="decimal"></label>
  <label>Μέγιστο πλάτος <input name="maxlat" required inputmode="decimal"></label>
  <label>Μέγιστο μήκος <input name="maxlon" required inputmode="decimal"></label>
  <button type="submit">Προσθήκη</button>
</form>
<?php page_footer();
