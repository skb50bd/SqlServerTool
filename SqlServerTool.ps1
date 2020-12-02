$IsSqlServerModuleInstalled = 
    (Get-Module SqlServer -ListAvailable).Name.Length -gt 0

IF (!$IsSqlServerModuleInstalled) {
    Write-Host "SqlServer Module is not installed. Installing..."
    $installationResult = 
        Install-Module SqlServer -Force
    
    IF ($null -eq $installationResult) {
        Write-Host "Installation Succeeded" -ForegroundColor Green
    }
    ELSE {
        Write-Host "Installation Failed" -ForegroundColor Red
        Break
    }
}

$ExampleUsageBackup = "./SqlServerTool.ps1 backup [<server-instance>] [<db-name>] [<output-dir>] [<tag>]"
$ExampleUsageRestore = "./SqlServerTool.ps1 restore [<server-instance>] [<db-name] [<backup-file-path>]"

$operation = $args[0]
IF ([string]::IsNullOrWhiteSpace($operation)) {
    $operation = Read-Host "Operation Name [backup | restore]"
}

IF ($operation -NotLike "backup" -And $operation -NotLike "restore") { 
    Write-Host "Invalid Operation:" $args[0] -ForegroundColor Red
    Write-Host: "Hint: " -ForegroundColor Blue
    Write-Host $ExampleUsageBackup -ForegroundColor Blue
    Write-Host $ExampleUsageRestore -ForegroundColor Blue
    Break
}

$serverInstance = $args[1]
IF ([string]::IsNullOrWhiteSpace($serverInstance)) {
    $serverInstance = Read-Host "SQL Server Instance Name"
}

$serverInstanceInvalid = 
    $null -eq (Get-SqlDatabase -ServerInstance $serverInstance)

IF ($serverInstanceInvalid) {
    Write-Host "The Server Instance is Invalid." -ForegroundColor Red 
    Break
}

IF ($operation -Like "backup") {
    $dbName = $args[2]
    IF ([string]::IsNullOrWhiteSpace($dbName)) {
        Get-SqlDatabase -ServerInstance $serverInstance
        Write-Host ""
        $dbName = Read-Host "DB Name"
    }

    $db = 
        Get-SqlDatabase -ServerInstance $serverInstance 
        | Where-Object { $_.Name -eq $dbName }

    IF ($null -eq $db) {
        Write-Host "Error! Couldn't find db" -ForegroundColor Red
        Break
    } 
    
    $backupDirectory = $args[3] 
    IF ([string]::IsNullOrWhiteSpace($backupDirectory)) {
        $backupDirectory = Read-Host "Backup Directory"
    }

    IF (-Not (Test-Path $backupDirectory)) {
        Write-Host "The Directory for Backup doesn't exist. Creating..."
        mkdir $backupDirectory
    }

    $tag = $args[4]
    IF ([string]::IsNullOrWhiteSpace($tag)) {
        $tag = Read-Host "Tag [optional]"
    }

    $backupFileName = $dbName + "_" + $tag + "_" + ("{0:yyyyMMddHHmmss}" -f (Get-Date)) + ".bak"
    $backupFilePath = Join-Path $backupDirectory $backupFileName

    Backup-SqlDatabase -DatabaseObject $db -BackupFile $backupFilePath

    Write-Host "Backup was Successful" -ForegroundColor Green
    Write-Host "Backup Path: " $backupFilePath -ForegroundColor Green
}

IF ($operation -Like "restore") {
    $dbName = $args[2]
    IF ([string]::IsNullOrWhiteSpace($dbName)) {
        $dbName = Read-Host "DB Name"
    }

    $backupFilePath = $args[3]
    IF ([string]::IsNullOrWhiteSpace($backupFilePath)) {
        $backupFilePath = Read-Host "Backup File Path"
    }

    IF (-Not (Test-Path $backupFilePath)) {
        Write-Host "File Not Found" -ForegroundColor Red
        Break
    }

    $db = Get-SqlDatabase -Name $dbName -ServerInstance $serverInstance
    IF ($null -ne $db) {
        Write-Host "DB Already Exists. Dropping..." -ForegroundColor Yellow

        $prepareForRestoreQuery = 
            "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = [N'" + $dbName + "']
                GO
                use [" + $dbName + "];
                GO
                use [master];
                GO
                USE [master]
                GO
                ALTER DATABASE [" + $dbName + "] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
                GO
                USE [master]
                GO
                DROP DATABASE [" + $dbName + "]
                GO"
        
        $dropOperationResult = 
            Invoke-Sqlcmd -Query $prepareForRestoreQuery -ServerInstance $serverInstance

        IF ($null -eq $dropOperationResult) {
            Write-Host "Dropped" -ForegroundColor Green
        }
        ELSE {
            Write-Host "Drop failed" -ForegroundColor Red
            Break
        }
    }

    $restoreOperationResult = 
        Restore-SqlDatabase -ServerInstance $serverInstance -Database $dbName -BackupFile $backupFilePath -ReplaceDatabase
    
    IF ($null -eq $restoreOperationResult) {
        $configureDbQuery =  
            "ALTER DATABASE [" + $dbName + "] 
                SET TRUSTWORTHY ON;
                USE [" + $dbName + "]
                GO
                
                EXEC sp_changedbowner 'sa'
                GO
                
                EXEC sp_configure 'clr enabled', 1;  
                RECONFIGURE WITH OVERRIDE;
                GO
            
                USE [master]
                ALTER DATABASE [" + $dbName + "]
                SET MULTI_USER;
                GO"
        
            Invoke-Sqlcmd -Query $configureDbQuery -ServerInstance $serverInstance

            $setOnlineQuery = "ALTER DATABASE [" + $dbName + "] SET ONLINE"
            Invoke-Sqlcmd -Query $setOnlineQuery -ServerInstance $serverInstance
            
            Write-Host "Restore Complete!" -ForegroundColor Green
    }
    ELSE {
        Write-Host "Restore Failed" -ForegroundColor Red
    }
}