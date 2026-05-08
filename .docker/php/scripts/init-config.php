<?php

declare(strict_types=1);

chdir(dirname(__DIR__, 3));
set_include_path(getcwd());

require_once 'vendor/autoload.php';

$required = ['POSTGRES_PIM_USER', 'POSTGRES_PIM_PASSWORD', 'POSTGRES_PIM_DB'];
foreach ($required as $name) {
    if (getenv($name) === false || getenv($name) === '') {
        fwrite(STDERR, "Missing required environment variable {$name}\n");
        exit(1);
    }
}

$bootstrap = in_array('--bootstrap', $argv, true);

if ($bootstrap && !file_exists('data/config.php')) {
    \Atro\Composer\PostUpdate::postUpdate();
}

$app = new \Atro\Core\Application();
$config = $app->getContainer()->get('config');

$config->set('database', [
    'driver'   => 'pdo_pgsql',
    'host'     => getenv('POSTGRES_HOST') ?: 'db',
    'port'     => getenv('POSTGRES_PORT') ?: '',
    'charset'  => 'utf8',
    'dbname'   => getenv('POSTGRES_PIM_DB'),
    'user'     => getenv('POSTGRES_PIM_USER'),
    'password' => getenv('POSTGRES_PIM_PASSWORD'),
]);
$config->set('useChromeNoSandbox', true);
$config->save();
