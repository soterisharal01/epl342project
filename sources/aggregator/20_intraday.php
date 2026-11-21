<?php // MENU: Intraday
// aggregator/20_intraday.php : ΙΙΙ.5.2 Intraday (Aggregator). Procedures: sp_market_intraday
require_once __DIR__ . '/../layout.php';
require_role('Aggregator');
require_once __DIR__ . '/../supplier/_market_view.php';
market_intraday_page('Aggregator');
