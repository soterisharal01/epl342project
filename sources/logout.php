<?php
// logout.php : κλείνει το session και γυρίζει στη σελίδα σύνδεσης.
require_once __DIR__ . '/auth.php';
$_SESSION = [];
session_destroy();
header('Location: index.php');
exit;
