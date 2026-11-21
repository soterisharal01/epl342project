<?php // MENU: Intraday
// supplier/20_intraday.php : ΙΙΙ.5.2 Intraday (Supplier). Procedures: sp_market_intraday
require_once __DIR__ . '/../layout.php';
require_role('Supplier');
require_once __DIR__ . '/../supplier/_market_view.php';
market_intraday_page('Supplier');
