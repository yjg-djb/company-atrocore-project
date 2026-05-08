<?php

declare(strict_types=1);

namespace MyCompany;

use Atro\Core\ModuleManager\AbstractModule;

class Module extends AbstractModule
{
    public static function getLoadOrder(): int
    {
        return 9000;
    }
}
