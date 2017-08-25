function Test-DbaDiagnosticAudit {
    <#
		.SYNOPSIS
			Outputs the Noun found on the server.

		.DESCRIPTION
            Longer description of what Get-Noun does.

		.PARAMETER SqlInstance
			The SQL Server instance. Server version must be SQL Server version 2012 or higher.

        .PARAMETER SqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

			$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

			Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER Silent
			If this switch is enabled, the internal messaging functions will be silenced.

		.NOTES
            Tags: TAGS_HERE 
            Original Author: Your name (@TwitterHandle)

			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Get-DbaDiagnosticAudit

		.EXAMPLE
			Get-Noun -SqlInstance sqlserver2014a

			Returns basic information on all Nouns found on sqlserver2014a

    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]
        $SqlInstance,

        [parameter(Mandatory = $false)]
        [Alias("Credential")]
        [PSCredential][System.Management.Automation.CredentialAttribute()]
        $SqlCredential
    )

    PROCESS {
        $ErrorResults = @()
        foreach ($Instance in $SqlInstance) {
            $SysErrors = @()
            $TempdbResults	= Test-DbaTempDbConfiguration $Instance
            $Results = Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'Configuration Values', 'Process Memory', 'SQL Server NUMA Info', 'System Memory'
            $ConfigResults	= ( $Results | Where-Object { $_.name -eq 'Configuration Values' } ).Result
            $ProcResults	= ( $Results | Where-Object { $_.Name -eq 'Process Memory' } ).Result
            $SysMemResults	= ( $Results | Where-Object { $_.Name -eq 'System Memory' } ).Result
            $NUMAInfoResults = ( $Results | Where-Object { $_.Name -eq 'SQL Server NUMA Info' } ).Result 

            if ($TempdbResults) {
                $SysErrors += [PSCustomObject]@{
                    Instance    = $Instance
                    ErrorType   = "TempDB Configuration"
                    Error       = $TempdbResults
                    Check       = "Test-DbaTempDbConfiguration $Instance"       
                }
            }
            if ( $ProcResults.large_page_allocations_kb -gt 0 -OR $ProcResults.locked_page_allocations_kb -gt 0 ) {
                $SysErrors += [PSCustomObject]@{
                    Instance    = $Instance
                    ErrorType   = "Internal Memory Pressure"
                    Error       = [PSCustomObject]@{ large_page_allocations_kb = $ProcResults.large_page_allocations_kb; locked_page_allocations_kb = $ProcResults.locked_page_allocations_kb }
                    Check       = "Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'Process Memory'"  
                }
            }
            if ((( $NUMAInfoResults | Where-Object { $_.Name -eq 'SQL Server NUMA Info' } ).Result | Measure-Object).Count -gt 1 ) {
                $SysErrors += [PSCustomObject]@{
                    Instance    = $Instance
                    ErrorType   = "Multiple NUMA count"
                    Error       = $NUMAInfoResults
                    Check       = "Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'SQL Server NUMA Info'"
                }
            }
            if ( $ConfigResults | Where-Object { $_.value -ne $_.value_in_use } ) {
                $SysErrors += [PSCustomObject]@{
                    Instance    = $Instance
                    ErrorType   = "Running Configuration does not match Configuration"
                    Error       = $ConfigResults | Where-Object { $_.value -ne $_.value_in_use }
                    Check       = "Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'Configuration Values'"
                }
            }
            if ( $Mem = Get-DbaMaxMemory $instance | Where-Object { $_.SqlMaxMB -gt $_.TotalMB } ) {
                $SysErrors += [PSCustomObject]@{
                    Instance    = $Instance
                    ErrorType   = "Max Memory Configuration"
                    Error       = $Mem
                    Check       = "Get-DbaMaxMemory $instance"
                }
            }
            if ( !$SysMemResults.'System Memory State'.Contains('Available physical memory is high') ) {
                $SysErrors += [PSCustomObject]@{
                    Instance    = $Instance
                    ErrorType   = "External Memroy Pressure"
                    Error       = $SysMemResults
                    Check       = "Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'System Memory'"
                }
            }
        }
        Return $ErrorResults
    }
}

