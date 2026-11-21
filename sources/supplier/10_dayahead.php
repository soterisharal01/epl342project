<?php // MENU: Day-Ahead
// supplier/10_dayahead.php : ΙΙΙ.5.2 Day-Ahead (Supplier). Procedures: sp_supplier_aggregates, sp_supplier_totals
require_once __DIR__ . '/../layout.php';
require_role('Supplier');
require_once __DIR__ . '/../supplier/_market_view.php';
market_dayahead_page('Supplier');
