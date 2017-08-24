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
			
			$Results 		= Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'Configuration Values','Process Memory','SQL Server NUMA Info','System Memory'
			$ConfigResults	= ( $Results | Where-Object { $_.name -eq 'Configuration Values' } ).Result
			$ProcResults	= ( $Results | Where-Object { $_.Name -eq 'Process Memory' } ).Result
			$SysMemResults	= ( $Results | Where-Object { $_.Name -eq 'System Memory' } ).Result

			If ( $ProcResults.large_page_allocations_kb -gt 0 -OR $ProcResults.locked_page_allocations_kb -gt 0 ) {
				$MemoryPressure = $TRUE
				$ErrorResults += "Possible internal memory pressure run: Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'Process Memory'"
			}
			if ((( $SysMemResults | Where-Object { $_.Name -eq 'SQL Server NUMA Info' } ).Result | Measure-Object).Count -gt 1 ) {
				$ErrorResults += "Multiple NUMA count run: Invoke-DbaDiagnosticQuery -SqlInstance $Instance -QueryName 'SQL Server NUMA Info'"
			}

			[PSCustomObject]@{
				InstanceName	= $Instance
				ConfigDiff		= $ConfigResults | Where-Object { $_.value -ne $_.value_in_use }
				ConfigBack		= $ConfigResults | Where-Object { $_.name.Contains('backup') -AND 0 -ne $_.value }
				MemoryPressure	= $MemoryPressure
				NUMACount		= (( $SysMemResults | Where-Object { $_.Name -eq 'SQL Server NUMA Info' } ).Result | Measure-Object).Count
			}
		}
	}
}