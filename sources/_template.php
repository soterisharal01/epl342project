<?php // ΠΡΟΤΥΠΟ ΣΕΛΙΔΑΣ: αντέγραψέ το στον φάκελο του ρόλου σου (π.χ. technician/tasks.php)
// =====================================================================
// Πώς φτιάχνεις νέα σελίδα (χωρίς να πειράξεις κανένα κοινό αρχείο):
//  1. Αντέγραψε αυτό το αρχείο στον φάκελο του ρόλου, π.χ. sources/dso/vee.php
//  2. Άλλαξε την ΠΡΩΤΗ γραμμή σε:   <?php // MENU: Έλεγχος VEE
//     (αυτό το κείμενο μπαίνει μόνο του στο μενού του ρόλου)
//  3. Άλλαξε το require_role(...) στον ρόλο της σελίδας.
//  4. Κάλεσε τα δικά σου procedures με call_proc('sp_...', [uid(), ...]).
//     ΠΑΝΤΑ πρώτη παράμετρος το uid(): το procedure ελέγχει τον ρόλο.
//  5. Κάθε POST φόρμα: csrf_field() μέσα στη φόρμα, check_csrf() στον χειρισμό.
//  6. Ό,τι τυπώνεις περνά από h(...) (ή print_table, που το κάνει μόνο του).
// Το αρχείο _template.php ΔΕΝ εμφανίζεται σε μενού (είναι στη ρίζα).
// =====================================================================
if (!is_file(__DIR__ . '/../layout.php')) { exit; }   // στη ρίζα δεν τρέχει (είναι μόνο πρότυπο)
require_once __DIR__ . '/../layout.php';
require_role('Consumer');                       // <- ο ρόλος της σελίδας

// --- Χειρισμός φόρμας (αλλαγή δεδομένων) ---
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $r = call_proc('sp_area_do_something', [uid(), $_POST['x'] ?? null]);
    if ($r === false) {
        flash(last_error(), 'error');           // το ελληνικό μήνυμα του THROW
    } else {
        flash('Αποθηκεύτηκε.');
    }
    redirect('consumer/example.php');           // Post/Redirect/Get: όχι διπλό submit με F5
}

// --- Εμφάνιση ---
page_header('Τίτλος σελίδας');
$rows = call_proc('sp_area_list_something', [uid()]);
print_table($rows, ['ColumnName' => 'Ελληνικός τίτλος']);
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Τιμή <input name="x" required></label>
  <button type="submit">Αποθήκευση</button>
</form>
<?php page_footer();
