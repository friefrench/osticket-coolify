<?php
/**
 * Relie les identifiants base de ost-config.php aux variables d'environnement.
 *
 * Pourquoi : l'installeur d'osTicket ecrit le mot de passe en dur dans le
 * fichier de config PHP, sans echappement fiable. Un mot de passe contenant
 * des caracteres speciaux est stocke abime : l'installation reussit (valeur
 * brute) mais le runtime echoue en "Access denied" (valeur abimee) -> 500.
 *
 * Ce script remplace les define() DB* par une lecture de l'environnement,
 * avec la valeur actuelle correctement echappee (var_export) en secours si
 * jamais l'environnement n'est pas visible du process PHP. Il est idempotent
 * et relance a chaque boot par l'entrypoint : la config suit toujours l'env.
 */

$file = '/var/www/html/include/ost-config.php';

$s = file_get_contents($file);
if ($s === false) {
    fwrite(STDERR, "[config-env] $file illisible\n");
    exit(1);
}

$map = array(
    'DBHOST' => 'DB_HOST',
    'DBNAME' => 'DB_NAME',
    'DBUSER' => 'DB_USER',
    'DBPASS' => 'DB_PASSWORD',
);

$n = 0;
foreach ($map as $def => $env) {
    $val = getenv($env);
    if ($val === false) {
        continue;
    }
    $line = "define('$def', getenv('$env') !== false ? getenv('$env') : "
          . var_export($val, true) . ");";
    // Les define() du fichier tiennent sur une ligne : remplacement par ligne
    // entiere. Callback obligatoire : avec preg_replace, un mot de passe
    // contenant $ ou \ serait re-abime par l'interpretation du remplacement.
    $s2 = preg_replace_callback(
        '/^\s*define\s*\(\s*[\'"]' . $def . '[\'"].*$/m',
        function ($m) use ($line) { return $line; },
        $s,
        1,
        $count
    );
    if ($s2 !== null && $count === 1) {
        $s = $s2;
        $n++;
    }
}

if ($n > 0 && file_put_contents($file, $s) === false) {
    fwrite(STDERR, "[config-env] ecriture impossible dans $file\n");
    exit(1);
}

echo "[config-env] $n define(s) DB relie(s) aux variables d'environnement.\n";
