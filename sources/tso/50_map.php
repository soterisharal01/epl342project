<?php // MENU: Χάρτης δικτύου
// =====================================================================
// tso/50_map.php : TSO-6 (bonus) χάρτης Leaflet: γεωφράκτες, μετασχηματιστές, μετρητές.
// Procedure: sp_tso_map_data (ένα result set, στήλη Kind = 'Transformer' | 'Meter').
// Το Leaflet 1.9.4 είναι αντιγραμμένο στο sources/lib/leaflet/ (δουλεύει χωρίς δίκτυο).
// Τα πλακίδια του χάρτη (OpenStreetMap) φορτώνουν μόνο online. Offline φαίνονται κανονικά
// τα διανυσματικά στρώματα (ορθογώνια, δείκτες, κύκλοι) πάνω σε κενό φόντο.
// Τα δεδομένα περνούν στη σελίδα ως JSON (json_encode με HEX σημαίες), και όλα τα κείμενα
// των popup φτιάχνονται με κόμβους κειμένου (textContent), όχι με innerHTML.
// =====================================================================
require_once __DIR__ . '/../layout.php';
require_role('TSO');

page_header('Χάρτης δικτύου');
$rows = call_proc('sp_tso_map_data', [uid()]);
if ($rows === false) {
    echo '<p class="error">' . h(last_error()) . '</p>';
    page_footer();
    exit;
}
$flags = JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE | JSON_PARTIAL_OUTPUT_ON_ERROR;
$data = json_encode(array_values($rows), $flags);
?>
<link rel="stylesheet" href="<?= h(url('lib/leaflet/leaflet.css')) ?>">
<style>
  #netmap { height: 70vh; min-height: 420px; border: 1px solid #bbb; background: #eef1f4; }
  .legend-note { font-size: .9em; margin: .5em 0; }
</style>
<p class="legend-note">Ορθογώνια: γεωφράκτες (φύλλα γεμάτα, ανώτερα επίπεδα διακεκομμένα). Δείκτες: μετασχηματιστές.
  Κύκλοι: μετρητές (πράσινο = Active, πορτοκαλί = Pending confirmation, γκρι = Retired).
  Χωρίς σύνδεση στο διαδίκτυο λείπει μόνο το φόντο του χάρτη.</p>
<div id="netmap"></div>
<script src="<?= h(url('lib/leaflet/leaflet.js')) ?>"></script>
<script>
(function () {
  var rows = <?= $data ?: '[]' ?>;
  var map = L.map('netmap');
  // Πλακίδια OpenStreetMap (online). Αν δεν φορτώσουν, τα υπόλοιπα στρώματα φαίνονται κανονικά.
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  }).addTo(map);

  function popup(lines) {            // κάθε τιμή μπαίνει ως κόμβος κειμένου, όχι ως HTML
    var box = document.createElement('div');
    lines.forEach(function (ln, i) {
      if (i) { box.appendChild(document.createElement('br')); }
      if (i === 0) {
        var b = document.createElement('strong'); b.textContent = ln; box.appendChild(b);
      } else { box.appendChild(document.createTextNode(ln)); }
    });
    return box;
  }
  function kwh(v) { return v === null ? '-' : Number(v).toLocaleString('el-GR', { maximumFractionDigits: 2 }) + ' kWh'; }

  var fences = L.layerGroup(), trafos = L.layerGroup(), meters = L.layerGroup();
  var statusColor = { 'Active': '#2e8b3d', 'Pending confirmation': '#e08a00', 'Retired': '#777777' };
  var all = [];

  rows.forEach(function (r) {
    var lat = Number(r.Latitude), lon = Number(r.Longitude);
    if (r.Kind === 'Transformer') {
      var leaf = r.IsLeaf === true || r.IsLeaf === 1 || r.IsLeaf === '1';
      var b = [[Number(r.MinLat), Number(r.MinLon)], [Number(r.MaxLat), Number(r.MaxLon)]];
      var rect = L.rectangle(b, leaf
        ? { color: '#1f5fa8', weight: 1, fillColor: '#1f5fa8', fillOpacity: 0.15 }
        : { color: '#7a3b9c', weight: 2, dashArray: '6 6', fill: false });
      rect.bindPopup(popup([r.Name, 'Γεωφράκτης επιπέδου ' + r.Level]));
      fences.addLayer(rect);
      all.push(b[0], b[1]);
      var mk = L.marker([lat, lon]);
      mk.bindPopup(popup([r.Name, 'Επίπεδο: ' + r.Level + (leaf ? ' (φύλλο)' : ''),
                          'Import: ' + kwh(r.ImportKWh), 'Export: ' + kwh(r.ExportKWh)]));
      trafos.addLayer(mk);
    } else if (r.Kind === 'Meter') {
      var c = L.circleMarker([lat, lon], { radius: 7, color: '#333', weight: 1, fillOpacity: 0.9,
                                           fillColor: statusColor[r.Status] || '#999999' });
      c.bindPopup(popup(['Μετρητής ' + r.SerialNumber, 'Κατάσταση: ' + r.Status, 'Μετασχηματιστής #' + r.TransformerID]));
      meters.addLayer(c);
      all.push([lat, lon]);
    }
  });

  fences.addTo(map); trafos.addTo(map); meters.addTo(map);
  L.control.layers(null, { 'Γεωφράκτες': fences, 'Μετασχηματιστές': trafos, 'Μετρητές': meters }).addTo(map);
  // Προσαρμογή στο δίκτυο· αν δεν υπάρχουν δεδομένα, όλη η Κύπρος.
  map.fitBounds(all.length ? all : [[34.5, 32.2], [35.7, 34.7]], { padding: [20, 20] });
})();
</script>
<?php page_footer();
