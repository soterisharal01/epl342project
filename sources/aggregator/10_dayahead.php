<?php // MENU: Day-Ahead
// aggregator/10_dayahead.php : ΙΙΙ.5.2 Day-Ahead (Aggregator). Procedures: sp_supplier_aggregates, sp_supplier_totals
require_once __DIR__ . '/../layout.php';
require_role('Aggregator');
require_once __DIR__ . '/../supplier/_market_view.php';
market_dayahead_page('Aggregator');
