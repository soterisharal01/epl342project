<?php // MENU: Χαρτοφυλάκια
// =====================================================================
// aggregator/30_portfolio.php : ΙΙΙ.5.1 χαρτοφυλάκια του Aggregator: δημιουργία, μετονομασία,
// υποστατικά του χαρτοφυλακίου, προσθήκη και αφαίρεση υποστατικού.
// Procedures: sp_aggregator_list_portfolios, sp_aggregator_list_portfolio_premises,
//             sp_aggregator_save_portfolio, sp_aggregator_add_premise, sp_aggregator_remove_premise
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('Aggregator');

// --- Χειρισμός φορμών (POST) ---
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = (string)($_POST['action'] ?? '');
    $pid = (int)($_POST['portfolio'] ?? 0);
    $back = 'aggregator/30_portfolio.php' . ($pid > 0 ? '?portfolio=' . $pid : '');
    if ($action === 'create') {
        $r = call_proc('sp_aggregator_save_portfolio', [uid(), null, (string)($_POST['name'] ?? '')]);
        if ($r === false) {
            flash(last_error(), 'error');
            $back = 'aggregator/30_portfolio.php';
        } else {
            flash('Το χαρτοφυλάκιο δημιουργήθηκε.');
            $back = 'aggregator/30_portfolio.php?portfolio=' . (int)$r[0]['PortfolioID'];
        }
    } elseif ($action === 'rename') {
        $r = call_proc('sp_aggregator_save_portfolio', [uid(), $pid, (string)($_POST['name'] ?? '')]);
        $r === false ? flash(last_error(), 'error') : flash('Το όνομα άλλαξε.');
    } elseif ($action === 'add') {
        $start = preg_match('/^\d{4}-\d{2}-\d{2}$/', (string)($_POST['start'] ?? '')) ? $_POST['start'] : null;
        $r = call_proc('sp_aggregator_add_premise', [uid(), $pid, (int)($_POST['premise'] ?? 0), $start]);
        $r === false ? flash(last_error(), 'error') : flash('Το υποστατικό προστέθηκε.');
    } elseif ($action === 'remove') {
        $r = call_proc('sp_aggregator_remove_premise', [uid(), $pid, (int)($_POST['premise'] ?? 0)]);
        $r === false ? flash(last_error(), 'error') : flash('Το υποστατικό αφαιρέθηκε από το χαρτοφυλάκιο.');
    }
    redirect($back);
}

// --- Εμφάνιση ---
page_header('Χαρτοφυλάκια');
$list = call_proc('sp_aggregator_list_portfolios', [uid()]);
if ($list === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
    page_footer();
    return;
}
$sel = (int)($_GET['portfolio'] ?? 0);
?>
<h2>Τα χαρτοφυλάκιά μου</h2>
<?php
if (!$list) {
    echo '<p class="muted">Δεν έχετε χαρτοφυλάκια ακόμη.</p>';
} else {
    echo '<table class="data"><tr><th>#</th><th>Όνομα</th><th>Ενεργά υποστατικά</th><th></th></tr>';
    foreach ($list as $p) {
        echo '<tr><td>' . h($p['PortfolioID']) . '</td><td>' . h($p['Name']) . '</td><td>' . h($p['ActivePremises'])
           . '</td><td><a href="30_portfolio.php?portfolio=' . h($p['PortfolioID']) . '">Υποστατικά</a></td></tr>';
    }
    echo '</table>';
}
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="create">
  <label>Νέο χαρτοφυλάκιο <input name="name" maxlength="100" required></label>
  <button type="submit">Δημιουργία</button>
</form>
<?php
$current = null;
foreach ($list as $p) {
    if ((int)$p['PortfolioID'] === $sel) { $current = $p; }
}
if ($current) {
    $pid = (int)$current['PortfolioID'];
    echo '<h2>Χαρτοφυλάκιο: ' . h($current['Name']) . '</h2>';
    ?>
<form method="post" class="inline-form">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="rename">
  <input type="hidden" name="portfolio" value="<?= h($pid) ?>">
  <label>Νέο όνομα <input name="name" maxlength="100" value="<?= h($current['Name']) ?>" required></label>
  <button type="submit">Μετονομασία</button>
</form>
<h3>Υποστατικά</h3>
<?php
    $prem = call_proc('sp_aggregator_list_portfolio_premises', [uid(), $pid]);
    if ($prem === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
    } elseif (!$prem) {
        echo '<p class="muted">Το χαρτοφυλάκιο δεν έχει υποστατικά.</p>';
    } else {
        echo '<table class="data"><tr><th>#</th><th>Διεύθυνση</th><th>ΤΚ</th><th>Χρήση</th><th>Από</th><th>Έως</th><th>Κατάσταση</th><th></th></tr>';
        foreach ($prem as $r) {
            $active = (string)$r['IsActive'] === '1' || $r['IsActive'] === true;
            echo '<tr><td>' . h($r['PremiseID']) . '</td><td>' . h($r['Address']) . '</td><td>' . h($r['PostalCode'])
               . '</td><td>' . h($r['UsageType']) . '</td><td>' . h($r['StartDate']) . '</td><td>' . h($r['EndDate'] ?? '')
               . '</td><td>' . ($active ? 'Ενεργό' : 'Αφαιρέθηκε') . '</td><td>';
            if ($active) {
                echo '<form method="post" class="inline-form">' . csrf_field()
                   . '<input type="hidden" name="action" value="remove">'
                   . '<input type="hidden" name="portfolio" value="' . h($pid) . '">'
                   . '<input type="hidden" name="premise" value="' . h($r['PremiseID']) . '">'
                   . '<button type="submit">Αφαίρεση</button></form>';
            }
            echo '</td></tr>';
        }
        echo '</table>';
    }
    ?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="add">
  <input type="hidden" name="portfolio" value="<?= h($pid) ?>">
  <label>Αριθμός υποστατικού <input name="premise" type="number" min="1" required style="width:8em"></label>
  <label>Από (προαιρετικά) <input name="start" type="date"></label>
  <button type="submit">Προσθήκη υποστατικού</button>
</form>
<?php
} elseif ($sel > 0) {
    echo '<p class="error">Το χαρτοφυλάκιο δεν βρέθηκε.</p>';
}
page_footer();
