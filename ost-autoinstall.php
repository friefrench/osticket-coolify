<?php
/**
 * Installation osTicket sans wizard (headless).
 *
 * Ce script rejoue exactement le bootstrap de setup/install.php, mais alimente
 * l'installeur avec des variables d'environnement au lieu du formulaire web.
 * Il appelle la classe Installer d'osTicket elle-meme : aucune logique SQL
 * reimplementee, donc robuste d'une version a l'autre.
 *
 * DOIT etre execute depuis le dossier setup/ (cwd = .../html/setup) pour que
 * les chemins relatifs (setup.inc.php, ../include/ost-config.php) resolvent
 * comme dans le vrai installeur.
 */

error_reporting(E_ERROR | E_PARSE);

// Contexte HTTP minimal attendu par setup.inc.php en mode CLI
$_SERVER['HTTP_HOST']   = $_SERVER['HTTP_HOST']   ?? 'localhost';
$_SERVER['PHP_SELF']    = $_SERVER['PHP_SELF']    ?? '/setup/install.php';
$_SERVER['REQUEST_URI'] = $_SERVER['REQUEST_URI'] ?? '/setup/install.php';
$_SERVER['HTTPS']       = $_SERVER['HTTPS']       ?? '';

require('setup.inc.php');                       // idem install.php
require_once INC_DIR.'class.installer.php';

define('OSTICKET_CONFIGFILE', '../include/ost-config.php');

$installer = new Installer(OSTICKET_CONFIGFILE);

function env_req($k) {
    $v = getenv($k);
    if ($v === false || $v === '') {
        fwrite(STDERR, "[autoinstall] variable manquante: $k\n");
        exit(3);
    }
    return $v;
}

$vars = array(
    'name'        => env_req('OSTICKET_NAME'),      // nom du helpdesk
    'email'       => env_req('OSTICKET_EMAIL'),     // email systeme par defaut
    'fname'       => env_req('ADMIN_FIRSTNAME'),
    'lname'       => env_req('ADMIN_LASTNAME'),
    'admin_email' => env_req('ADMIN_EMAIL'),        // doit differer de OSTICKET_EMAIL
    'username'    => env_req('ADMIN_USERNAME'),      // pas "admin"/"osticket" (refuse)
    'passwd'      => env_req('ADMIN_PASSWORD'),
    'passwd2'     => env_req('ADMIN_PASSWORD'),
    'prefix'      => getenv('TABLE_PREFIX') ?: 'ost_',
    'dbhost'      => env_req('DB_HOST'),
    'dbname'      => env_req('DB_NAME'),
    'dbuser'      => env_req('DB_USER'),
    'dbpass'      => env_req('DB_PASSWORD'),
    'lang_id'     => getenv('OSTICKET_LANG') ?: 'en_US',
    'timezone'    => getenv('OSTICKET_TIMEZONE') ?: 'UTC',
);

if ($installer->install($vars)) {
    fwrite(STDOUT, "[autoinstall] osTicket installe avec succes.\n");
    exit(0);
}

$errors = $installer->getErrors();
fwrite(STDERR, "[autoinstall] ECHEC de l'installation:\n");
foreach ((array) $errors as $k => $v) {
    fwrite(STDERR, "  - $k: " . (is_array($v) ? json_encode($v) : $v) . "\n");
}
exit(1);
