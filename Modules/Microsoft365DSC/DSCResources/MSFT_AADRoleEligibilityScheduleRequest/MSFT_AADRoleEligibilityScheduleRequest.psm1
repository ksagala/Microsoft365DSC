﻿function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $AppScopeId,

        [Parameter()]
        [ValidateSet("adminAssign", "adminUpdate", "adminRemove", "selfActivate", "selfDeactivate", "adminExtend", "adminRenew", "selfExtend", "selfRenew", "unknownFutureValue")]
        [System.String]
        $Action,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [System.Boolean]
        $IsValidationOnly,

        [Parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $TicketInfo,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )
    try
    {
        $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
            -InboundParameters $PSBoundParameters
    }
    catch
    {
        Write-Verbose -Message ($_)
    }

        #Ensure the proper dependencies are installed in the current environment.
        Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $nullResult = $PSBoundParameters
    $nullResult.Ensure = 'Absent'
    try
    {
        $request = $null
        if (-not [System.String]::IsNullOrEmpty($Id))
        {
            if ($null -ne $Script:exportedInstances -and $Script:ExportMode)
            {
                    $request = $Script:exportedInstances | Where-Object -FilterScript {$_.Id -eq $Id}
            }
            else
            {
                Write-Verbose -Message "Getting Role Eligibility by Id"
                $request = Get-MgBetaRoleManagementDirectoryRoleEligibilityScheduleRequest -UnifiedRoleEligibilityScheduleRequestId $Id `
                    -ErrorAction SilentlyContinue
            }
        }

        if ($null -eq $request)
        {
            if ($null -ne $Script:exportedInstances -and $Script:ExportMode)
            {
                    Write-Verbose -Message "Getting Role Eligibility by PrincipalId and RoleDefinitionId"
                    $PrincipalId = (Get-MgUser -Filter "UserPrincipalName eq '$Principal'").Id
                    Write-Verbose -Message "Found Principal {$PrincipalId}"
                    $RoleDefinitionId = (Get-MgBetaRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq '$RoleDefinition'").Id
                    $request = $Script:exportedInstances | Where-Object -FilterScript {$_.PrincipalId -eq $PrincipalId -and $_.RoleDefinitionId -eq $RoleDefinition}
            }
            else
            {
                Write-Verbose -Message "Getting Role Eligibility by PrincipalId and RoleDefinitionId"
                $PrincipalId = (Get-MgUser -Filter "UserPrincipalName eq '$Principal'").Id
                Write-Verbose -Message "Found Principal {$PrincipalId}"
                $RoleDefinitionId = (Get-MgBetaRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq '$RoleDefinition'").Id
                Write-Verbose -Message "Found Role {$RoleDefinitionId}"

                $request = Get-MgBetaRoleManagementDirectoryRoleEligibilityScheduleRequest -Filter "PrincipalId eq '$PrincipalId' and RoleDefinitionId eq '$RoleDefinitionId'"
            }
        }
        if ($null -eq $request)
        {
            return $nullResult
        }

        Write-Verbose -Message "Found existing AADRolelLigibilityScheduleRequest"
        $PrincipalValue = Get-MgUser -UserId $request.PrincipalId
        $RoleDefinitionValue = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $request.RoleDefinitionId

        $ScheduleInfoValue = @{}

        if ($null -ne $request.ScheduleInfo.Expiration)
        {
            $expirationValue = @{
                duration    = $request.ScheduleInfo.Expiration.Duration
                endDateTime = $request.ScheduleInfo.Expiration.EndDateTime
                type        = $request.ScheduleInfo.Expiration.Type
            }
            $ScheduleInfoValue.Add('expiration', $expirationValue)
        }
        if ($null -ne $request.ScheduleInfo.Recurrence)
        {
            $recurrenceValue = @{
                pattern = @{
                    dayOfMonth     = $request.ScheduleInfo.Recurrence.Pattern.dayOfMonth
                    daysOfWeek     = $request.ScheduleInfo.Recurrence.Pattern.daysOfWeek
                    firstDayOfWeek = $request.ScheduleInfo.Recurrence.Pattern.firstDayOfWeek
                    index          = $request.ScheduleInfo.Recurrence.Pattern.index
                    interval       = $request.ScheduleInfo.Recurrence.Pattern.interval
                    month          = $request.ScheduleInfo.Recurrence.Pattern.month
                    type           = $request.ScheduleInfo.Recurrence.Pattern.type
                }
                range   = @{
                    endDate             = $request.ScheduleInfo.Recurrence.Range.endDate
                    numberOfOccurrences = $request.ScheduleInfo.Recurrence.Range.numberOfOccurrences
                    recurrenceTimeZone  = $request.ScheduleInfo.Recurrence.Range.recurrenceTimeZone
                    startDate           = $request.ScheduleInfo.Recurrence.Range.startDate
                    type                = $request.ScheduleInfo.Recurrence.Range.type
                }
            }
            $ScheduleInfoValue.Add('Recurrence', $recurrenceValue)
        }
        if ($null -ne $request.ScheduleInfo.StartDateTime)
        {
            $ScheduleInfoValue.Add('StartDateTime', $request.ScheduleInfo.startDateTime.ToString())
        }

        $ticketInfoValue = $null
        if ($null -ne $request.TicketInfo)
        {
            $ticketInfoValue = @{
                ticketNumber = $request.TicketInfo.TicketNumber
                ticketSystem = $request.TicketInfo.TicketSystem
            }
        }

        $results = @{
            Principal             = $PrincipalValue.UserPrincipalName
            RoleDefinition        = $RoleDefinitionValue.DisplayName
            DirectoryScopeId      = $request.DirectoryScopeId
            AppScopeId            = $request.AppScopeId
            Action                = $request.Action
            Id                    = $request.Id
            Justification         = $request.Justification
            IsValidationOnly      = $request.IsValidationOnly
            ScheduleInfo          = $ScheduleInfoValue
            TicketInfo            = $ticketInfoValue
            Ensure                = 'Present'
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            ApplicationSecret     = $ApplicationSecret
            CertificateThumbprint = $CertificateThumbprint
            Managedidentity       = $ManagedIdentity.IsPresent
        }
        return $results
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error retrieving data:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return $nullResult
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $AppScopeId,

        [Parameter()]
        [ValidateSet("adminAssign", "adminUpdate", "adminRemove", "selfActivate", "selfDeactivate", "adminExtend", "adminRenew", "selfExtend", "selfRenew", "unknownFutureValue")]
        [System.String]
        $Action,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [System.Boolean]
        $IsValidationOnly,

        [Parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $TicketInfo,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )
    try
    {
        $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
            -InboundParameters $PSBoundParameters `
    }
    catch
    {
        Write-Verbose -Message $_
    }

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentInstance = Get-TargetResource @PSBoundParameters

    $PSBoundParameters.Remove('Ensure') | Out-Null
    $PSBoundParameters.Remove('Credential') | Out-Null
    $PSBoundParameters.Remove('ApplicationId') | Out-Null
    $PSBoundParameters.Remove('ApplicationSecret') | Out-Null
    $PSBoundParameters.Remove('TenantId') | Out-Null
    $PSBoundParameters.Remove('CertificateThumbprint') | Out-Null
    $PSBoundParameters.Remove('ManagedIdentity') | Out-Null
    $PSBoundParameters.Remove('Verbose') | Out-Null

    $ParametersOps = ([Hashtable]$PSBoundParameters).clone()

    if ($Ensure -eq 'Present')
    {
        $PrincipalIdValue = (Get-MgUser -Filter "UserPrincipalName eq '$Principal'").Id
        $ParametersOps.Add("PrincipalId", $PrincipalIdValue)
        $ParametersOps.Remove("Principal") | Out-Null

        $RoleDefinitionIdValue = (Get-MgBetaRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq '$RoleDefinition'").Id
        $ParametersOps.Add("RoleDefinitionId", $RoleDefinitionIdValue)
        $ParametersOps.Remove("RoleDefinition") | Out-Null

        if ($null -ne $ScheduleInfo)
        {
            $ScheduleInfoValue = @{}

            if ($ScheduleInfo.StartDateTime)
            {
                $ScheduleInfoValue.Add("startDateTime", $ScheduleInfo.StartDateTime)
            }

            if ($ScheduleInfo.Expiration)
            {
                $expirationValue = @{
                    duration    = $ScheduleInfo.Expiration.duration
                    endDateTime = $ScheduleInfo.Expiration.endDateTime
                    type        = $ScheduleInfo.Expiration.type
                }
                $ScheduleInfoValue.Add("Expiration", $expirationValue)
            }

            if ($ScheduleInfo.Recurrence)
            {
                $Found = $false
                $recurrenceValue = @{}

                if ($ScheduleInfo.Recurrence.Pattern)
                {
                    $Found = $true
                    $patternValue = @{
                        dayOfMonth     = $ScheduleInfo.Recurrence.Pattern.dayOfMonth
                        daysOfWeek     = $ScheduleInfo.Recurrence.Pattern.daysOfWeek
                        firstDayOfWeek = $ScheduleInfo.Recurrence.Pattern.firstDayOfWeek
                        index          = $ScheduleInfo.Recurrence.Pattern.index
                        interval       = $ScheduleInfo.Recurrence.Pattern.interval
                        month          = $ScheduleInfo.Recurrence.Pattern.month
                        type           = $ScheduleInfo.Recurrence.Pattern.type
                    }
                    $recurrenceValue.Add("Pattern", $patternValue)
                }
                if ($ScheduleInfo.Recurrence.Range)
                {
                    $Found = $true
                    $rangeValue = @{
                        endDate             = $ScheduleInfo.Recurrence.Range.endDate
                        numberOfOccurrences = $ScheduleInfo.Recurrence.Range.numberOfOccurrences
                        recurrenceTimeZone  = $ScheduleInfo.Recurrence.Range.recurrenceTimeZone
                        startDate           = $ScheduleInfo.Recurrence.Range.startDate
                        type                = $ScheduleInfo.Recurrence.Range.type
                    }
                    $recurrenceValue.Add("Range", $rangeValue)
                }
                if ($Found)
                {
                    $ScheduleInfoValue.Add("Recurrence", $recurrenceValue)
                }
            }
        }
        $ParametersOps.ScheduleInfo = $ScheduleInfoValue
    }

    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating an Azure AD Role Eligibility Schedule Request for user {$Principal} and role {$RoleDefinition}"
        $ParametersOps.Remove("Id") | Out-Null

        New-MgBetaRoleManagementDirectoryRoleEligibilityScheduleRequest @ParametersOps
    }
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating the Azure AD Role Eligibility Schedule Request for user {$Principal} and role {$RoleDefinition}"

        $ParametersOps.Add('UnifiedRoleEligibilityScheduleRequestId', $Id)
        $ParametersOps.Remove("Id") | Out-Null
        Update-MgBetaRoleManagementDirectoryRoleEligibilityScheduleRequest @ParametersOps
    }
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing the Azure AD Role Eligibility Schedule Request for user {$Principal} and role {$RoleDefinition}"

        Remove-MgBetaRoleManagementDirectoryRoleEligibilityScheduleRequest -UnifiedRoleEligibilityScheduleRequestId $Id
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $AppScopeId,

        [Parameter()]
        [ValidateSet("adminAssign", "adminUpdate", "adminRemove", "selfActivate", "selfDeactivate", "adminExtend", "adminRenew", "selfExtend", "selfRenew", "unknownFutureValue")]
        [System.String]
        $Action,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [System.Boolean]
        $IsValidationOnly,

        [Parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $TicketInfo,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message "Testing configuration of the Azure AD Role Eligibility Schedule Request for user {$Principal} and role {$RoleDefinition}"

    $CurrentValues = Get-TargetResource @PSBoundParameters
    $ValuesToCheck = ([Hashtable]$PSBoundParameters).clone()

    Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $CurrentValues)"
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $ValuesToCheck)"

    $testResult = Test-M365DSCParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck $ValuesToCheck.Keys

    Write-Verbose -Message "Test-TargetResource returned $testResult"

    return $testResult
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
        -InboundParameters $PSBoundParameters

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        $Script:ExportMode = $true
        #region resource generator code
        [array] $Script:exportedInstances = Get-MgBetaRoleManagementDirectoryRoleEligibilityScheduleRequest -All `
            -ErrorAction Stop
        #endregion

        $i = 1
        $dscContent = ''
        if ($Script:exportedInstances.Length -eq 0)
        {
            Write-Host $Global:M365DSCEmojiGreenCheckMark
        }
        else
        {
            Write-Host "`r`n" -NoNewline
        }
        foreach ($request in $Script:exportedInstances)
        {
            $displayedKey = $request.Id
            Write-Host "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -NoNewline
            $params = @{
                Id                    = $request.Id
                Principal             = $request.PrincipalId
                RoleDefinition        = 'TempDefinition'
                ScheduleInfo          = 'TempSchedule'
                Ensure                = 'Present'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                ApplicationSecret     = $ApplicationSecret
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
            }

            $Results = Get-TargetResource @Params

            $Results = Update-M365DSCExportAuthenticationResults -ConnectionMode $ConnectionMode `
                -Results $Results
            $Results.ScheduleInfo = Get-M365DSCAzureADEligibilityRequestScheduleInfoAsString -ScheduleInfo $Results.ScheduleInfo
            $Results.TicketInfo = Get-M365DSCAzureADEligibilityRequestTicketInfoAsString -TicketInfo $Results.TicketInfo

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential
            if ($null -ne $Results.ScheduleInfo)
            {
                $currentDSCBlock = Convert-DSCStringParamToVariable -DSCBlock $currentDSCBlock `
                    -ParameterName 'ScheduleInfo'
            }
            if ($null -ne $Results.TicketInfo)
            {
                $currentDSCBlock = Convert-DSCStringParamToVariable -DSCBlock $currentDSCBlock `
                    -ParameterName 'TicketInfo'
            }

            $dscContent += $currentDSCBlock
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName
            $i++
            Write-Host $Global:M365DSCEmojiGreenCheckMark
        }
        return $dscContent
    }
    catch
    {
        Write-Verbose -Message "Exception: $($_.Exception.Message)"

        Write-Host $Global:M365DSCEmojiRedX

        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return ''
    }
}

function Get-M365DSCAzureADEligibilityRequestTicketInfoAsString
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $TicketInfo
    )

    if ($TicketInfo.TicketNumber -or $TicketInfo.TicketSystem)
    {
        $StringContent  = "MSFT_AADRoleEligibilityScheduleRequestTicketInfo {`r`n"
        $StringContent += "                ticketNumber = '$($TicketInfo.TicketNumber)'`r`n"
        $StringContent += "                ticketSystem = '$($TicketInfo.TicketSystem)'`r`n"
        $StringContent += "             }`r`n"
        return $StringContent
    }
    else
    {
        return $null
    }
}

function Get-M365DSCAzureADEligibilityRequestScheduleInfoAsString
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $ScheduleInfo
    )

    $Found = $false
    $StringContent  = "MSFT_AADRoleEligibilityScheduleRequestSchedule {`r`n"

    if ($ScheduleInfo.Expiration.Duration -or $ScheduleInfo.Expiration.EndDateTime -or $ScheduleInfo.Expiration.Type)
    {
        $Found = $true
        $StringContent += "                expiration                = MSFT_AADRoleEligibilityScheduleRequestScheduleExpiration`r`n"
        $StringContent += "                    {`r`n"
        if ($ScheduleInfo.Expiration.Duration)
        {
            $StringContent += "                        duration    = '$($ScheduleInfo.Expiration.Duration)'`r`n"
        }
        if ($ScheduleInfo.Expiration.EndDateTime)
        {
            $StringContent += "                        endDateTime = '$($ScheduleInfo.Expiration.EndDateTime.ToString())'`r`n"
        }
        if($ScheduleInfo.Expiration.Type)
        {
            $StringContent += "                        type        = '$($ScheduleInfo.Expiration.Type)'`r`n"
        }
        $StringContent += "                    }`r`n"
    }
    if($ScheduleInfo.Recurrence.Pattern.DayOfMonth -or $ScheduleInfo.Recurrence.Pattern.DaysOfWeek -or `
    $ScheduleInfo.Recurrence.Pattern.firstDayOfWeek -or $ScheduleInfo.Recurrence.Pattern.Index -or `
    $ScheduleInfo.Recurrence.Pattern.Interval -or $ScheduleInfo.Recurrence.Pattern.Month -or `
    $ScheduleInfo.Recurrence.Pattern.Type -or $ScheduleInfo.Recurrence.Range.EndDate -or $ScheduleInfo.Recurrence.Range.numberOfOccurrences -or `
    $ScheduleInfo.Recurrence.Range.recurrenceTimeZone -or $ScheduleInfo.Recurrence.Range.startDate -or `
    $ScheduleInfo.Recurrence.Range.type)
    {
        $StringContent += "                recurrence                = MSFT_AADRoleEligibilityScheduleRequestScheduleRecurrence`r`n"
        $StringContent += "                    {`r`n"

        if ($ScheduleInfo.Recurrence.Pattern.DayOfMonth -or $ScheduleInfo.Recurrence.Pattern.DaysOfWeek -or `
            $ScheduleInfo.Recurrence.Pattern.firstDayOfWeek -or $ScheduleInfo.Recurrence.Pattern.Index -or `
            $ScheduleInfo.Recurrence.Pattern.Interval -or $ScheduleInfo.Recurrence.Pattern.Month -or `
            $ScheduleInfo.Recurrence.Pattern.Type)
        {
            $Found = $true
            $StringContent += "                         pattern = MSFT_AADRoleEligibilityScheduleRequestScheduleRecurrencePattern`r`n"
            $StringContent += "                             {`r`n"
            if ($ScheduleInfo.Recurrence.Pattern.DayOfMonth)
            {
                $StringContent += "                                 dayOfMonth     = $($ScheduleInfo.Recurrence.Pattern.DayOfMonth)`r`n"
            }
            if ($ScheduleInfo.Recurrence.Pattern.DaysOfWeek)
            {
                $StringContent += "                                 daysOfWeek     = @($($ScheduleInfo.Recurrence.Pattern.DaysOfWeek -join ','))`r`n"
            }
            if ($ScheduleInfo.Recurrence.Pattern.firstDayOfWeek)
            {
                $StringContent += "                                 firstDayOfWeek = '$($ScheduleInfo.Recurrence.Pattern.firstDayOfWeek)'`r`n"
            }
            if ($ScheduleInfo.Recurrence.Pattern.Index)
            {
                $StringContent += "                                 index          = '$($ScheduleInfo.Recurrence.Pattern.Index)'`r`n"
            }
            if ($ScheduleInfo.Recurrence.Pattern.Interval)
            {
                $StringContent += "                                 interval       = $($ScheduleInfo.Recurrence.Pattern.Interval.ToString())`r`n"
            }
            if ($ScheduleInfo.Recurrence.Pattern.Month)
            {
                $StringContent += "                                 month          = $($ScheduleInfo.Recurrence.Pattern.Month.ToString())`r`n"
            }
            if ($ScheduleInfo.Recurrence.Pattern.Type)
            {
                $StringContent += "                                 type           = '$($ScheduleInfo.Recurrence.Pattern.Type)'`r`n"
            }
            $StringContent += "                             }`r`n"
        }
        if ($ScheduleInfo.Recurrence.Range.EndDate -or $ScheduleInfo.Recurrence.Range.numberOfOccurrences -or `
            $ScheduleInfo.Recurrence.Range.recurrenceTimeZone -or $ScheduleInfo.Recurrence.Range.startDate -or `
            $ScheduleInfo.Recurrence.Range.type)
        {
            $Found = $true
            $StringContent += "                         range = MSFT_AADRoleEligibilityScheduleRequestScheduleRange`r`n"
            $StringContent += "                             {`r`n"
            $StringContent += "                                 endDate             = '$($ScheduleInfo.Recurrence.Range.EndDate)'`r`n"
            $StringContent += "                                 numberOfOccurrences = $($ScheduleInfo.Recurrence.Range.numberOfOccurrences)`r`n"
            $StringContent += "                                 recurrenceTimeZone  = '$($ScheduleInfo.Recurrence.Range.recurrenceTimeZone)'`r`n"
            $StringContent += "                                 startDate           = '$($ScheduleInfo.Recurrence.Range.startDate)'`r`n"
            $StringContent += "                                 type                = '$($ScheduleInfo.Recurrence.Range.type)'`r`n"
            $StringContent += "                             }`r`n"
        }

        $StringContent += "                    }`r`n"
    }
    $StringContent += "            }`r`n"

    if ($Found)
    {
        return $StringContent
    }
    return $null
}

Export-ModuleMember -Function *-TargetResource
