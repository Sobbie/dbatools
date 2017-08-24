function Get-DbaVersionAudit {
<#
.SYNOPSIS
Write an csv file out with version data for SQL Instances.

.DESCRIPTION
Write an csv file out with version data for SQL Instances.

.PARAMETER SqlInstance
The SQL Server instance. Server version must be SQL Server version 2012 or higher.

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

To connect as a different Windows user, run PowerShell as that user.


.PARAMETER Path
The Path to the CSV File

.EXAMPLE
Get-VersionAudit -SQLInstance Server01 -Path C:\temp\file.csv

.NOTES
Original Author: Paul Ksobiech

Website: https://dbatools.io
Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
#>
    [CmdletBinding()]
    PARAM (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[Object[]]
        $SqlInstance,

		[parameter(Mandatory = $false)]
		[Alias("Credential")]
		[PSCredential][System.Management.Automation.CredentialAttribute()]
		$SqlCredential,

        [string]
        $Path = "C:\temp\" + $(Get-Date -Format 'yyyy-MM-ddThh-mm-ss') + ".csv",

        [switch]
        $DatabaseExpantion = $False
    )

    BEGIN{
        If (Test-Path $Path) {
            $caption = "$Path"
            $message = "File Exists would you like to delete it?"
            $Delete = new-Object System.Management.Automation.Host.ChoiceDescription "&delete","Delete"
            $Cancel = new-Object System.Management.Automation.Host.ChoiceDescription "&cancel","Cancel"
            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($delete,$Cancel)
            $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)
            switch ($answer){
                0 { 
                    "Overwriting... .. ."
                    Remove-Item $Path
                }
                1 { "Canceling... .. ."; Exit}
            }
        }
    }

    PROCESS {
        ForEach ($Instance in $SqlInstance) {
            If (Test-Connection -Quiet -Count 2 -ComputerName $Instance.Split("\")[0]) {
                Try {
                    $Results = Get-DbaSqlBuildReference -SqlInstance $Instance -Silent
                    $uptime = Get-DbaUptime -SqlInstance $Instance -SqlOnly
                }
                Catch {
                    $Results = [PSCustomObject]@{
                        ComputerName        = $Instance.Split("\")[0]
                        SqlInstance         = $Instance
                        Build               = "N/A"
                        Edition             = "N/A"
                        NameLevel           = "N/A"
                        SPLevel             = "N/A"
                        CULevel             = "N/A"
                        KBLevel             = "N/A"
                        SupportedUntil      = "N/A"
                        MatchType           = "N/A"
                        SinceSqlStart       = "N/A"
                        Database            = "N/A"
                        DatabaseSizeMB      = "N/A"
                        Warning             = ($error[0] | Select-Object *).Exception
                    }
                }
                If ($DatabaseExpantion) {
                    Try {
                        Foreach ( $DB in (Get-DbaDatabase -SqlInstance $Instance -Silent) ) {
                            [PSCustomObject]@{
                                ComputerName        = $Instance.Split("\")[0]
                                SqlInstance         = $Instance
                                Build               = $Results.Build
                                Edition             = $Results.Edition
                                NameLevel           = $Results.NameLevel
                                SPLevel             = $Results.SPLevel -Join " "
                                CULevel             = $Results.CULevel
                                KBLevel             = $Results.KBLevel
                                SupportedUntil      = $Results.SupportedUntil
                                MatchType           = $Results.MatchType
                                SinceSqlStart       = $uptime.SinceSqlStart
                                Database            = $DB.Name
                                DatabaseSizeMB      = (Get-DbaDatabase -SqlInstance $Instance -Database $DB.Name  -Silent).SizeMB
                                Warning             = $Results.Warning
                            } | Export-Csv -Path $Path -Append -NoTypeInformation
                        }
                    }
                    Catch {
                        [PSCustomObject]@{
                                ComputerName        = $Instance.Split("\")[0]
                                SqlInstance         = $Instance
                                Build               = $Results.Build
                                Edition             = $Results.Edition
                                NameLevel           = $Results.NameLevel
                                SPLevel             = $Results.SPLevel -Join " "
                                CULevel             = $Results.CULevel
                                KBLevel             = $Results.KBLevel
                                SupportedUntil      = $Results.SupportedUntil
                                MatchType           = $Results.MatchType
                                SinceSqlStart       = $uptime.SinceSqlStart
                                Database            = "Error Getting Size: $(($error[0] | Select-Object *).Exception)"
                                DatabaseSizeMB      = "Error Getting Size: $(($error[0] | Select-Object *).Exception)"
                                Warning             = $Results.Warning
                        } | Export-Csv -Path $Path -Append -NoTypeInformation
                    } 
                }
                Else {
                    Try {
                        [PSCustomObject]@{
                            ComputerName        = $Instance.Split("\")[0]
                            SqlInstance         = $Instance
                            Build               = $Results.Build
                            Edition             = $Results.Edition
                            NameLevel           = $Results.NameLevel
                            SPLevel             = $Results.SPLevel -Join " "
                            CULevel             = $Results.CULevel
                            KBLevel             = $Results.KBLevel
                            SupportedUntil      = $Results.SupportedUntil
                            MatchType           = $Results.MatchType
                            SinceSqlStart       = $uptime.SinceSqlStart
                            Databases           = (Get-DbaDatabase -SqlInstance $Instance -ExcludeAllSystemDb -Silent | Select-Object -ExpandProperty Name) -Join ", "
                            DatabaseSizeMB      = ((Get-DbaDatabase -SqlInstance $Instance  -Silent| Select-Object  -ExpandProperty SizeMB) | Measure-Object -Sum).Sum
                            Warning             = $Results.Warning
                        } | Export-Csv -Path $Path -Append -NoTypeInformation
                    }
                    Catch {
                        [PSCustomObject]@{
                            ComputerName        = $Instance.Split("\")[0]
                            SqlInstance         = $Instance
                            Build               = $Results.Build
                            Edition             = $Results.Edition
                            NameLevel           = $Results.NameLevel
                            SPLevel             = $Results.SPLevel -Join " "
                            CULevel             = $Results.CULevel
                            KBLevel             = $Results.KBLevel
                            SupportedUntil      = $Results.SupportedUntil
                            MatchType           = $Results.MatchType
                            SinceSqlStart       = $uptime.SinceSqlStart
                            Databases           = "Error Getting Size: $(($error[0] | Select-Object *).Exception)"
                            DatabaseSizeMB      = "Error Getting Size: $(($error[0] | Select-Object *).Exception)"
                            Warning             = $Results.Warning
                        } | Export-Csv -Path $Path -Append -NoTypeInformation

                    }

                }

                Clear-Variable uptime
                Clear-Variable Results
            }
        }
    }
}
