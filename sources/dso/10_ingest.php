<?php // MENU: Εισαγωγή πακέτου
// =====================================================================
// dso/10_ingest.php : ΙΙΙ.3.1 λήψη πακέτου τηλεμετρίας (JSON) για το demo.
// Η φόρμα στέλνει το JSON στο sp_dso_ingest_packet και δείχνει το αποτέλεσμα
// (κατάσταση, πλήθος μετρήσεων, μήνυμα). Από κάτω, τα πρόσφατα πακέτα.
// Procedures: sp_dso_ingest_packet, sp_dso_list_packets
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('DSO');

$example = '{ "Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "2026-11-21T12:00:00Z",' . "\n"
         . '  "Cell_Signal_Strength_dBm": -92, "Network_Type": "NB-IoT",' . "\n"
         . '  "Telemetry_Payload": [ {"obis": "1.8.0", "value": 14250.3200, "unit": "kWh"},' . "\n"
         . '                         {"obis": "32.7.0", "value": 228.40, "unit": "V"} ] }';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $r = call_proc('sp_dso_ingest_packet', [uid(), (string)($_POST['payload'] ?? '')]);
    if ($r === false) {
        flash(last_error(), 'error');
    } else {
        $_SESSION['ingest_result'] = $r;        // δείχνεται μία φορά μετά το redirect
        flash('Το πακέτο καταγράφηκε.');
    }
    $_SESSION['ingest_payload'] = (string)($_POST['payload'] ?? '');
    redirect('dso/10_ingest.php');              // Post/Redirect/Get: όχι διπλό submit με F5
}

page_header('Εισαγωγή πακέτου τηλεμετρίας');

if (isset($_SESSION['ingest_result'])) {
    echo '<h2>Αποτέλεσμα</h2>';
    print_table($_SESSION['ingest_result'], [
        'PacketID' => 'Πακέτο', 'IngestStatus' => 'Κατάσταση',
        'ReadingsStored' => 'Μετρήσεις που αποθηκεύτηκαν', 'ErrorMessage' => 'Μήνυμα',
    ]);
    unset($_SESSION['ingest_result']);
}
$text = $_SESSION['ingest_payload'] ?? $example;
unset($_SESSION['ingest_payload']);
?>
<form method="post" class="box">
  <?= csrf_field() ?>
  <label>Πακέτο JSON (όπως στο Παράρτημα της εκφώνησης)<br>
    <textarea name="payload" rows="10" cols="90" required><?= h($text) ?></textarea>
  </label>
  <button type="submit">Αποστολή</button>
</form>

<h2>Πρόσφατα πακέτα</h2>
<?php
print_table(call_proc('sp_dso_list_packets', [uid(), 20]), [
    'PacketID' => '#', 'ReceivedAt' => 'Λήψη (UTC)', 'TransmissionTimestamp' => 'Αποστολή (UTC)',
    'ReceivedNetworkID' => 'NetworkID', 'SerialNumber' => 'Μετρητής', 'NetworkType' => 'Δίκτυο',
    'SignalDbm' => 'dBm', 'IngestStatus' => 'Κατάσταση', 'ReadingsStored' => 'Μετρήσεις', 'ErrorMessage' => 'Μήνυμα',
]);
page_footer();
