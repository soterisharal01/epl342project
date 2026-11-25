<?php
// =====================================================================
// layout.php : η κοινή εμφάνιση κάθε σελίδας (πάνω μέρος + μενού + κάτω μέρος).
//
//   page_header('Τίτλος');  ...το περιεχόμενο της σελίδας...  page_footer();
//
// ΑΥΤΟΜΑΤΟ ΜΕΝΟΥ: για κάθε αρχείο .php στον φάκελο του ρόλου (π.χ. consumer/)
// που η ΠΡΩΤΗ γραμμή του είναι   <?php // MENU: Τα τιμολόγιά μου
// μπαίνει μόνο του ένα link στο μενού. Έτσι, για νέα σελίδα δεν αλλάζει
// κανείς κοινό αρχείο: απλώς φτιάχνει το αρχείο στον φάκελό του.
// Σειρά: αλφαβητική κατά όνομα αρχείου (βάλε 10_, 20_ μπροστά αν θες σειρά).
// =====================================================================

require_once __DIR__ . '/auth.php';

function menu_items(string $role): array
{
    $folder = ROLES[$role][0] ?? null;
    if ($folder === null) {
        return [];
    }
    $items = [];
    $files = glob(__DIR__ . '/' . $folder . '/*.php') ?: [];
    sort($files);
    foreach ($files as $f) {
        $fh = fopen($f, 'r');
        $first = $fh ? (fgets($fh) ?: '') : '';
        if ($fh) { fclose($fh); }
        if (preg_match('#^<\?php\s*//\s*MENU:\s*(.+?)\s*$#u', $first, $m)) {
            $items[$folder . '/' . basename($f)] = $m[1];
        }
    }
    if ($role === 'Technician' && technician_limited()) {   // FIX-2: πριν την έγκριση μόνο τα έγγραφα
        $items = array_intersect_key($items, array_flip(TECH_LIMITED_PAGES));
    }
    return $items;
}

function page_header(string $title): void
{
    $u = current_user();
    $self = str_replace('\\', '/', $_SERVER['SCRIPT_NAME']);
    ?>
<!DOCTYPE html>
<html lang="el">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= h($title) ?> | MDMS-Cy</title>
  <link rel="stylesheet" href="<?= url('css/style.css') ?>">
</head>
<body>
<header class="top">
  <img src="<?= url('images/ucy.jpg') ?>" alt="UCY" height="48">
  <div class="brand"><strong>MDMS-Cy</strong><span>ΕΠΛ342 · Ομάδα 12</span></div>
  <?php if ($u): ?>
    <div class="who">
      <?= h($u['FirstName'] . ' ' . $u['LastName']) ?> · <?= h(ROLES[$u['Role']][1] ?? $u['Role']) ?>
      · <a href="<?= url('profile.php') ?>">Προφίλ</a>
      · <a href="<?= url('logout.php') ?>">Αποσύνδεση</a>
    </div>
  <?php endif; ?>
</header>
<div class="wrap">
  <?php if ($u): ?>
  <nav class="side">
    <a href="<?= url('home.php') ?>"<?= str_ends_with($self, '/home.php') ? ' class="on"' : '' ?>>Αρχική</a>
    <?php foreach (menu_items($u['Role']) as $path => $label): ?>
      <a href="<?= url($path) ?>"<?= str_ends_with($self, '/' . $path) ? ' class="on"' : '' ?>><?= h($label) ?></a>
    <?php endforeach; ?>
  </nav>
  <?php endif; ?>
  <main>
    <h1><?= h($title) ?></h1>
    <?php if ($f = flash()): ?>
      <p class="<?= $f[0] === 'ok' ? 'ok' : 'error' ?>"><?= h($f[1]) ?></p>
    <?php endif; ?>
<?php
}

function page_footer(): void
{
    ?>
  </main>
</div>
<footer>Πανεπιστήμιο Κύπρου · Τμήμα Πληροφορικής · ΕΠΛ342</footer>
</body>
</html>
<?php
}
