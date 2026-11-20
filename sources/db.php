<?php
// =====================================================================
// db.php : ΟΛΗ η επικοινωνία με τη βάση περνά από εδώ.
//
//   db()                          -> η σύνδεση (ανοίγει μία φορά ανά σελίδα)
//   call_proc('sp_x', [a, b])     -> τρέχει {CALL sp_x(?, ?)} και δίνει τις γραμμές
//   print_table($rows)            -> τυπώνει τις γραμμές ως πίνακα HTML
//   last_error()                  -> το μήνυμα του τελευταίου λάθους (για τον χρήστη)
//
// Γιατί έτσι:
//  * Η PHP ΔΕΝ γράφει SQL. Μόνο καλεί procedures με ? (κλείνει το SQL injection).
//  * Τα μηνύματα των δικών μας THROW (50000-59999) είναι ελληνικά και ασφαλή,
//    οπότε τα δείχνουμε. Κάθε άλλο λάθος της SQL ΔΕΝ το δείχνουμε (ο WAF του
//    τμήματος δίνει 403 αν δει κείμενο λάθους SQL), το γράφουμε στο error log.
// =====================================================================

function config(): array
{
    static $cfg = null;
    if ($cfg === null) {
        $file = __DIR__ . '/config.php';
        if (!is_file($file)) {
            die('Λείπει το config.php. Αντίγραψε το config.example.php σε config.php και βάλε τον κωδικό της βάσης.');
        }
        $cfg = require $file;
    }
    return $cfg;
}

function db()
{
    static $conn = null;
    if ($conn === null) {
        $cfg = config();
        $conn = sqlsrv_connect($cfg['serverName'], $cfg['connectionOptions']);
        if ($conn === false) {
            error_log('MDMS db connect: ' . print_r(sqlsrv_errors(), true));
            die('Δεν ήταν δυνατή η σύνδεση με τη βάση. Δοκίμασε ξανά σε λίγο.');
        }
    }
    return $conn;
}

$GLOBALS['MDMS_LAST_ERROR'] = null;

function last_error(): ?string
{
    return $GLOBALS['MDMS_LAST_ERROR'];
}

// Κάνει τα λάθη της βάσης ένα απλό μήνυμα για τον χρήστη.
function remember_error(): void
{
    $errs = sqlsrv_errors() ?: [];
    $msg = 'Κάτι πήγε στραβά. Δοκίμασε ξανά ή ενημέρωσε τον διαχειριστή.';
    foreach ($errs as $e) {
        $code = (int)$e['code'];
        if ($code >= 50000 && $code <= 59999) {          // δικό μας THROW
            // το μήνυμα έρχεται ως "[Microsoft][ODBC Driver..][SQL Server]κείμενο"
            $msg = preg_replace('/^(\[[^\]]*\])+/', '', $e['message']);
            // Αν ο driver δώσει το μήνυμα σε ελληνική κωδικοσελίδα (όχι UTF-8), το μετατρέπουμε,
            // αλλιώς το htmlspecialchars θα έδειχνε κενό.
            if (!preg_match('//u', $msg) && function_exists('iconv')) {
                $msg = iconv('Windows-1253', 'UTF-8//IGNORE', $msg);
            }
            break;
        }
    }
    if (!empty(config()['debug'])) {
        $msg .= ' [debug: ' . ($errs[0]['message'] ?? '') . ']';
    }
    error_log('MDMS sql: ' . print_r($errs, true));
    $GLOBALS['MDMS_LAST_ERROR'] = $msg;
}

// Καλεί ένα stored procedure. Επιστρέφει τις γραμμές του ΠΡΩΤΟΥ αποτελέσματος
// (array από associative arrays), ή false αν έγινε λάθος (δες last_error()).
// Τα DATETIME έρχονται ως κείμενο (ReturnDatesAsStrings) για εύκολη εμφάνιση.
function call_proc(string $name, array $params = [])
{
    if (!preg_match('/^sp_[a-z0-9_]+$/i', $name)) {
        die('Μη έγκυρο όνομα procedure.');
    }
    $GLOBALS['MDMS_LAST_ERROR'] = null;
    $placeholders = implode(', ', array_fill(0, count($params), '?'));
    $sql = '{CALL ' . $name . ($params ? '(' . $placeholders . ')' : '') . '}';
    $stmt = sqlsrv_query(db(), $sql, array_values($params), ['ReturnDatesAsStrings' => true]);
    if ($stmt === false) {
        remember_error();
        return false;
    }
    $rows = [];
    $got = false;
    // Διαβάζουμε το ΠΡΩΤΟ αποτέλεσμα που έχει στήλες, και μετά τρέχουμε ό,τι έμεινε
    // (ώστε να φανεί και ένα THROW που έρχεται μετά από SELECT).
    while (true) {
        if (!$got && sqlsrv_num_fields($stmt) > 0) {
            while (($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) !== null) {
                if ($r === false) { remember_error(); return false; }
                $rows[] = $r;
            }
            $got = true;
        }
        $next = sqlsrv_next_result($stmt);
        if ($next === false) { remember_error(); return false; }
        if ($next === null) { break; }          // τέλος αποτελεσμάτων
    }
    sqlsrv_free_stmt($stmt);
    return $rows;
}

// Ασφαλής εμφάνιση κειμένου (κλείνει το XSS). Πάντα h() σε ό,τι τυπώνουμε.
function h($v): string
{
    return htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8');
}

// Τυπώνει γραμμές ως πίνακα. $headers: προαιρετικά ελληνικοί τίτλοι στηλών.
function print_table($rows, array $headers = []): void
{
    if ($rows === false) {
        echo '<p class="error">' . h(last_error()) . '</p>';
        return;
    }
    if (count($rows) === 0) {
        echo '<p class="muted">Δεν υπάρχουν δεδομένα.</p>';
        return;
    }
    echo '<table class="data"><tr>';
    foreach (array_keys($rows[0]) as $col) {
        echo '<th>' . h($headers[$col] ?? $col) . '</th>';
    }
    echo '</tr>';
    foreach ($rows as $r) {
        echo '<tr>';
        foreach ($r as $v) {
            echo '<td>' . h($v) . '</td>';
        }
        echo '</tr>';
    }
    echo '</table>';
}
