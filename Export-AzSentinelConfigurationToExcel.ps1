#requires -version 6.2
<#
    .SYNOPSIS
        This command will generate a Excel document containing the information about all the Microsoft Sentinel
        Solutions.  
    .DESCRIPTION
       This command will generate a Excel document containing the information about all the Microsoft Sentinel
        Solutions.  
    .NOTES
        AUTHOR: Gary Bushey
        LASTEDIT: 6 June 2025
        REASON: Added GUI and new Sentinel features
#>


Function Export-AzSentinelConfigurationToExcel($fileName) {

    $resourceGroupName = $resourceGroupName.Text
    $workspaceName = $WorkspaceName.Text

    #Setup the Authentication header needed for the REST calls
    
    $context = Get-AzContext
    $myProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($myProfile)
    $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json' 
        'Authorization' = 'Bearer ' + $token.AccessToken 
    }
    $SubscriptionId = (Get-AzContext).Subscription.Id
    $baseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/providers/Microsoft.SecurityInsights/"
    $apiVersion = "?api-version=2025-01-01-preview"
    #$WorkspaceID = (Get-AzOperationalInsightsWorkspace -Name $workspaceName -ResourceGroupName $resourceGroupName).CustomerID
        
    $StatusBox.text += "Starting...`r`n"

    try {

        #Load the list of all  solutions
        $url = $baseUrl + "contentPackages" + $apiVersion + "&%24expand=SolutionV2"
        $solutions = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
        #$solutions = $allSolutions | Where-Object { $null -ne $_.properties.installedVersion }

        #Load all the metadata entries.  Used to get some Sentinel workbook data
        $url = $baseUrl + "metadata" + $apiVersion
        $metadata = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        #Load all the alert rules
        $url = $baseUrl + "alertrules" + $apiVersion
        $alertRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        #Setup Excel
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false   #We don't want to see excel while this is running
        # Add a new workbook
        $Workbook = $Excel.Workbooks.Add()
        $Worksheets = $Workbook.Worksheets

        #Add the Title page
        $Worksheet = $Worksheets.Item(1)
        Add-TitlePage $Worksheet
        

        #Add all the workbooks
        if ($ShowWorkbooks.checked) {
            Add-AllWorkbooks $metadata $workbook 
        }

        #Add all the Hunts that have been created
        if ($ShowHunts.checked) {
            Add-AllHunts $workbook   
        }

        #Add the MITRE coverage
        if ($ShowMitre.checked) {
            Add-AllMitre $workbook
        }

        #Add the solutions
        if ($ShowSolutions.checked) {
            Add-AllSolutions $solutions $workbook 
            
        }

        #Add the Repository information
        if ($ShowRepositories.checked) {
            Add-AllRepositories $workbook
            
        }

        #Add the Workspace Manager
        if ($ShowWorkspace.checked) {
            Add-AllWorkspaces $workbook
            
        }

        #Add the Data Connectors
        if ($ShowDataConnectors.checked) {
            Add-AllDataConnectors $solutions $workbook
            
        }

        #Add the Analytic Rules
        if ($ShowRules.checked) {
            Add-AllAnalyticRules  $alertRules $workbook
            
        }

        #Add the Summary Rules
        if ($ShowSummary.checked) {
            Add-AllSummaryRules $workbook
            
        }

        #Add the Watchlists
        if ($ShowWatchlist.checked) {
            Add-AllWatchlists $workbook
            
        }
        
        #Add the Automation rules
        if ($ShowAutomation.checked) {
            Add-AllAutomation $alertRules $workbook
            
        }

        #Add the Playbooks
        if ($ShowPlaybooks.checked) {
            Add-AllPlaybooks $workbook
            
        }

        #Add the Settings
        if ($ShowSettings.checked) {
            Add-AllSettings $workbook
            
        }

        #Add the Tables
        if ($ShowTables.checked) {
            Add-AllTables $workbook
            
        } 

        #Add the RBAC roles
        if ($ShowRBAC.checked) {
            Add-AllRBAC $workbook
            
        } 


        $outputPath = Join-Path $PWD.Path $fileName
        $Workbook.SaveAs($outputPath)

        # Close the workbook and quit Excel
        $Workbook.Close()
        $Excel.Quit()

        # Release COM objects
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
       
        #NOTE:  If for some reason the Powershell quits before it can quit work, go into task manager
        #to close manually, otherwise you can get some weird results
        $StatusBox.text += "Completed! "
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred: " + $errorReturn
        # Close without saving
        $Workbook.Close($false)
        # Release COM objects
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
    }
}

Function Add-TitlePage ($Worksheet) {
    #Title Page
    $Worksheet.Name = "Title"
    $Worksheet.Range("A1").Font.Size = 20
    $Worksheet.Cells.Item(1, 1) = "Microsoft Sentinel Documentation"   #Add the text
    $text = Get-Date
    $Worksheet.Range("A2:Z24").Font.Size = 12
    $Worksheet.Cells.Item(3, 1) = "Created" 
    $Worksheet.Cells.Item(3, 2) = $text
    $Worksheet.Cells.Item(4, 1) = "Resource Group" 
    $Worksheet.Cells.Item(4, 2) = $ResourceGroupName  
    $Worksheet.Cells.Item(5, 1) = "Workspace Name" 
    $Worksheet.Cells.Item(5, 2) = $WorkSpaceName

}
Function Add-AllSettings ($workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Settings"

    $row = 1

    Write-Host "Settings: " -NoNewline
    $StatusBox.text += "Settings: "

    $url = $baseUrl + "settings" + $apiVersion
    $settings = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

    $worksheet.Cells.Item($row, 1) = "User Entity Behavior Analytics"
    $row++ 
    try {

        $foundSources = $false
        $entityAnalytics = $settings | Where-Object -Property Name -eq "EntityAnalytics"
        if ($null -ne $entityAnalytics) {
            $worksheet.Cells.Item($row, 2) = "Enabled: True"
            $row++
            $worksheet.Cells.Item($row, 2) = "Directory services"
            $row++
            foreach ($entityProvider in $entityAnalytics.properties.entityProviders) {
                $text = TranslateServices $entityProvider
                $worksheet.Cells.Item($row, 3) = $text
                $row++
            }
            $euba = $settings | Where-Object -Property Name -eq "Ueba"
            $worksheet.Cells.Item($row, 2) = "Directory sources"
            $row++
            foreach ($dataSource in $euba.properties.dataSources) {
                $foundSources = $true
                $text = TranslateServices $dataSource
                $worksheet.Cells.Item($row, 3) = $text
                $row++
            }
        }
        else {
            $worksheet.Cells.Item($row, 2) = "Enabled: False"
        }
        if (!$foundSources) {
            $row++
        }
        $StatusBox.text += "."

        $worksheet.Cells.Item($row, 1) = "Anomalies"
        $row++
        $anomalies = $settings | Where-Object -Property Name -eq "Anomalies"
        if ($null -ne $anomalies) {
            $worksheet.Cells.Item($row, 2) = "Enabled: True"
        }
        else {
            $worksheet.Cells.Item($row, 2) = "Enabled: False"
        }
        $row++

        $url = $baseUrl + "workspaceManagerConfigurations" + $apiVersion
        $settings = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $worksheet.Cells.Item($row, 1) = "Is workspace a central workspace?"
        $row++
        if ($settings.properties.mode -eq "Enabled") {
            $worksheet.Cells.Item($row, 2) = "Yes"
        }
        else {
            $worksheet.Cells.Item($row, 2) = "No"
        }
        $row++
        $StatusBox.text += "."

        $worksheet.Cells.Item($row, 1) = "Allow Microsoft Sentinel engineers to access your data?"
        $row++
        $anomalies = $settings | Where-Object -Property Name -eq "EyesOn"
        if ($null -ne $anomalies) {
            $worksheet.Cells.Item($row, 2) = "Enabled: True"
        }
        else {
            $worksheet.Cells.Item($row, 2) = "Enabled: False"
        }
        $row++
        $StatusBox.text += "."

        #Check to see which Resource Groups are set to run playbooks
        $worksheet.Cells.Item($row, 1) = "Resource Groups that can run playbooks"
        $row++
        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups?api-version=2020-10-01" 
        $resourceGroups = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
        foreach ($resourceGroup in $resourceGroups) {
            $rgName = $resourceGroup.name
            $url = "https://management.azure.com/subscriptions/$subScriptionId/resourceGroups/$rgName/providers/Microsoft.Authorization/" +
            "roleAssignments?api-version=2015-07-01&%24filter=atScope()%20and%20assignedTo('4fae0573-3b67-4b20-98d1-5847c5faa905')"
            $foundRG = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
            if ($null -ne $foundRg.properties) {
                $worksheet.Cells.Item($row, 2) = $rgName
                $row++
            }
        }
        $StatusBox.text += "."

        #Audit and Health monitoring
        $worksheet.Cells.Item($row, 1) = "Auditing and Health Monitoring"
        $row++
        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/" +
        "workspaces/$workspaceName/providers/Microsoft.SecurityInsights/settings/SentinelHealth/providers/microsoft.insights/diagnosticSettings?api-version=2021-05-01-preview"
        $audit = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
        $auditLogs = $audit.properties.logs
        $allLogs = $auditLogs | Where-Object -Property categoryGroup -eq "allLogs"
        if ($null -ne $allLogs) {
            $worksheet.Cells.Item($row, 2) = "All Logs"
        }
        else {
            foreach ($log in $auditLogs) {
                $name = TranslateServices $log.Category
                $worksheet.Cells.Item($row, 2) = $name
                $row++
            }
        }
        $StatusBox.text += "."
        $StatusBox.text += "`r`n"
        Write-Host "Done"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Settings: " + $errorReturn
        $StatusBox.text += "`r`n"

    }
}
Function TranslateServices ($text) {
    $returnText = $text
    switch ($text) {
        "AzureActiveDirectory" { $returnText = "Azure Active Directory" }
        "ActiveDirectory" { $returnText = "Active Directory" }
        "AuditLogs" { $returnText = "Audit Logs" }
        "AzureActivity" { $returnText = "Azure Activity" }
        "SecurityEvent" { $returnText = "Security Events" }
        "SignInLogs" { $returnText = "Sign In Logs" }
        "DataConnectors" { $returnText = "Data Collection - Connectors" }
    }
    return $returnText
}
Function Add-AllTables ( $worksheet) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Tables"

    Write-Host "Tables: " -NoNewline
    try {

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Plan"
        $worksheet.Cells.Item($row, 3) = "Interactive Retention"
        $worksheet.Cells.Item($row, 4) = "Total Retention"
        $row++

        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/tables?api-version=2025-02-01"
        $laTables = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "Tables (" + $laTables.count + "): "

        foreach ($laTable in $laTables | Sort-Object { $_.properties.schema.name }) {
            $worksheet.Cells.Item($row, 1) = $laTable.properties.schema.name.toString()
            $worksheet.Cells.Item($row, 2) = $laTable.properties.plan.toString()
            $worksheet.Cells.Item($row, 3) = $laTable.properties.retentionInDays.toString()
            $worksheet.Cells.Item($row, 4) = $laTable.properties.totalRetentionInDays.toString()
            $row++
            $StatusBox.text += "."
        }

        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Tables: " + $errorReturn
        $StatusBox.text += "`r`n"

    }
}

Function Add-AllWorkspaces ( $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Workspace Manager - Workspaces"

    Write-Host "Workspaces: " -NoNewline
    try {

        $url = $baseUrl + "workspaceManagerGroups?api-version=2023-04-01-preview"
        $groups = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $url = $baseUrl + "workspaceManagerAssignments?api-version=2023-04-01-preview"
        $assignments = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $url = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2019-04-01"

        $body = @{
            "subscriptions" = @(
                "$SubscriptionId"
            )
            "query"         = "resources | where type =~ 'microsoft.operationsmanagement/solutions'" +
            "| where name contains 'SecurityInsights'" +
            "| project id = tolower(tostring(properties.workspaceResourceId))" +
            "| join kind = inner (" +
            "resources" +
            "| where type =~ 'microsoft.operationalinsights/workspaces'" +
            "| extend id=tolower(id)" +
            ") on id" + "     |  parse id with '/subscriptions/' subId '/resourcegroups/' resourceGroupName '/providers/' providers '/' nestedResource '/' resourceName" + 
            "| extend id =  strcat('/subscriptions/', subId, '/resourcegroups/' ,resourceGroupName, '/providers/' ,'microsoft.securityinsightsarg/sentinel/', resourceName)" + 
            "| extend type = 'microsoft.securityinsightsarg/sentinel'" + "| project id,name,type,location,resourceGroup,subscriptionId,tenantId" + 
            "| extend locationDisplayName=case(location =~ 'eastus','East US',location =~ 'southcentralus','South Central US',location =~ 'westus2','West US 2',location =~ 'westus3'," + 
            "'West US 3',location =~ 'australiaeast','Australia East',location =~ 'southeastasia','Southeast Asia',location =~ 'northeurope','North Europe',location =~ 'swedencentral'," + 
            "'Sweden Central',location =~ 'uksouth','UK South',location =~ 'westeurope','West Europe',location =~ 'centralus','Central US',location =~ 'southafricanorth','South Africa North'," + 
            "location =~ 'centralindia','Central India',location =~ 'eastasia','East Asia',location =~ 'indonesiacentral','Indonesia Central',location =~ 'japaneast','Japan East'," + 
            "location =~ 'japanwest','Japan West',location =~ 'koreacentral','Korea Central',location =~ 'malaysiawest','Malaysia West',location =~ 'newzealandnorth','New Zealand North'," + 
            "location =~ 'canadacentral','Canada Central',location =~ 'francecentral','France Central',location =~ 'germanywestcentral','Germany West Central',location =~ 'italynorth','Italy North'," + 
            "location =~ 'norwayeast','Norway East',location =~ 'polandcentral','Poland Central',location =~ 'spaincentral','Spain Central',location =~ 'switzerlandnorth','Switzerland North'," + 
            "location =~ 'mexicocentral','Mexico Central',location =~ 'uaenorth','UAE North',location =~ 'brazilsouth','Brazil South',location =~ 'chilecentral','Chile Central'," + 
            "location =~ 'israelcentral','Israel Central',location =~ 'qatarcentral','Qatar Central',location =~ 'centralusstage','Central US (Stage)',location =~ 'eastusstage','East US (Stage)'," + 
            "location =~ 'eastus2stage','East US 2 (Stage)',location =~ 'northcentralusstage','North Central US (Stage)',location =~ 'southcentralusstage','South Central US (Stage)'," +
            "location =~ 'westusstage','West US (Stage)',location =~ 'westus2stage','West US 2 (Stage)',location =~ 'asia','Asia',location =~ 'asiapacific','Asia Pacific'," +
            "location =~ 'australia','Australia',location =~ 'brazil','Brazil',location =~ 'canada','Canada',location =~ 'europe','Europe',location =~ 'france','France'," + 
            "location =~ 'germany','Germany',location =~ 'global','Global',location =~ 'india','India',location =~ 'indonesia','Indonesia',location =~ 'israel','Israel'," + 
            "location =~ 'italy','Italy',location =~ 'japan','Japan',location =~ 'korea','Korea',location =~ 'malaysia','Malaysia',location =~ 'mexico','Mexico'," + 
            "location =~ 'newzealand','New Zealand',location =~ 'norway','Norway',location =~ 'poland','Poland',location =~ 'qatar','Qatar',location =~ 'singapore','Singapore'," +
            "location =~ 'southafrica','South Africa',location =~ 'spain','Spain',location =~ 'sweden','Sweden',location =~ 'switzerland','Switzerland',location =~ 'taiwan','Taiwan'," +
            "location =~ 'uae','United Arab Emirates',location =~ 'uk','United Kingdom',location =~ 'unitedstates','United States',location =~ 'unitedstateseuap','United States EUAP'," +
            "location =~ 'eastasiastage','East Asia (Stage)',location =~ 'southeastasiastage','Southeast Asia (Stage)',location =~ 'brazilus','Brazil US',location =~ 'eastus2','East US 2'," +
            "location =~ 'northcentralus','North Central US',location =~ 'westus','West US',location =~ 'jioindiawest','Jio India West',location =~ 'westcentralus','West Central US'," +
            "location =~ 'southafricawest','South Africa West',location =~ 'australiacentral','Australia Central',location =~ 'australiacentral2','Australia Central 2'," +
            "location =~ 'australiasoutheast','Australia Southeast',location =~ 'jioindiacentral','Jio India Central',location =~ 'koreasouth','Korea South'," +
            "location =~ 'southindia','South India',location =~ 'westindia','West India',location =~ 'canadaeast','Canada East',location =~ 'francesouth','France South'," +
            "location =~ 'germanynorth','Germany North',location =~ 'norwaywest','Norway West',location =~ 'switzerlandwest','Switzerland West',location =~ 'ukwest','UK West'," +
            "location =~ 'uaecentral','UAE Central',location =~ 'brazilsoutheast','Brazil Southeast',location) " + 
            "| project name,resourceGroup,locationDisplayName,tenantId,id,type,location,subscriptionId | sort by (tolower(tostring(name))) asc " + 
            "| join kind = leftouter (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project-rename subscriptionDisplayName=name " +
            "|project subscriptionId, subscriptionDisplayName) on subscriptionId | project-away subscriptionId1"
        }

        #Note that this does not return data as JSON
        #.data.rows[x][0] = Name
        #.data.rows[x][1] = Resource group  (I may have [0]and [1] reversed)
        #.data.rows[x][2] = Location (for display purposes)
        #.data.rows[x][3] = Tenant Id
        #.data.rows[x][4] = Id
        #.data.rows[x][5] = Type
        #.data.rows[x][6] = Location (internal name)
        #.data.rows[x][7] = Subscription Id
        #.data.rows[x][8] = Subscription Name
        $workspaces = Invoke-RestMethod -Method "POST" -Uri $url -Headers $authHeader  -Body ($body | ConvertTo-Json -EnumsAsStrings -Depth 5)

        $url = $baseUrl + "workspaceManagerMembers?api-version=2023-04-01-preview"
        $workspaceMembers = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        #Need to load all the tenants to map that out correctly
        $url = "https://management.azure.com/tenants?api-version=2020-01-01&%24includeAllTenantCategories=true"
        $tenants = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        #Need to load all the resources that the workspace could send to match all the entries in the $assignments
        $url = $baseUrl + "alertRules?api-version=2022-11-01-preview"
        $alertRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $url = $baseUrl + "automationRules?api-version=2022-12-01-preview"
        $automationRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Insights//workbooks?api-version=2022-04-01" +
        "&canFetchContent=false&%24filter=sourceId%20eq%20'%2Fsubscriptions%2F9790d913-b5da-460d-b167-ac985d5f3b83%2FresourceGroups%2Fmssentinel%2F" +
        "providers%2FMicrosoft.OperationalInsights%2Fworkspaces%2Fmicrosoftsentinel'&category=sentinel"
        $workbooks = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/workspaces/microsoftsentinel/savedSearches?api-version=2021-06-01"
        $savedSearches = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "Workspaces (" + $groups.count + "): "

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Group(s)"
        $worksheet.Cells.Item($row, 3) = "Directory"
        $worksheet.Cells.Item($row, 4) = "Location"
        $row++

        #Output the Workspace information
        foreach ($workspace in $workspaces.data.rows | Sort-Object { $_.properties.displayName }) {
            $worksheet.Cells.Item($row, 1) = $workspace[0]
            
            #Find all the matching groups.  There is no direct route from Workspaces => Groups only Groups => Workspaces
            $matchedGroups = ""
            foreach ($group in $groups) {
                $resourceIds = $group.properties.memberResourceNames
                foreach ($resourceId in $resourceIds) {
                    $match = $workspaceMembers | Where-Object { $_.name -eq $resourceId }
                    if ($null -ne $match) { 
                        $name = $match.properties.targetWorkspaceResourceId.split("/")[-1]
                        if ($name -eq $workspace[0]) {
                            $matchedGroups = $matchedGroups + $group.properties.displayName + ","
                        }
                    }
                }
            }
            if ($matchedGroups -ne "") {
                $matchedGroups = $matchedGroups.Substring(0, $matchedGroups.Length - 1)
            }

            $worksheet.Cells.Item($row, 2) = $matchedGroups

            $tenant = $tenants | Where-Object { $_.tenantId -eq $workspace[3] }

            if ($null -eq $tenant.displayName) {
                $worksheet.Cells.Item($row, 3) = "unknown"
            }
            else {
                $worksheet.Cells.Item($row, 3) = $tenant.displayName
            }
            
            $worksheet.Cells.Item($row, 4) = $workspace[2]
            $row++
        }

        $worksheet = $workbook.Worksheets.Add()
        $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
        $worksheet.Name = "Workspace Manager - Groups"

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Description"
        $worksheet.Cells.Item($row, 3) = "Workspaces"
        $worksheet.Cells.Item($row, 4) = "Content Items"
        $worksheet.Cells.Item($row, 5) = "Last Publish Status"
        $worksheet.Cells.Item($row, 6) = "Last Publish Date"
        $worksheet.Cells.Item($row, 7) = "Selected Content"
        $row++


        foreach ($group in $groups) {

            $assignmentList = $assignments | Where-Object { $_.properties.targetResourceName -eq $group.name }

            $worksheet.Cells.Item($row, 1) = $group.properties.displayName
            $worksheet.Cells.Item($row, 2) = $group.properties.description
            $worksheet.Cells.Item($row, 3) = $group.properties.memberResourceNames.count
            $worksheet.Cells.Item($row, 4) = $assignmentList.properties.items.count
            
            if ($null -ne $assignmentList.properties.LastJobProvisioningState) {
                $worksheet.Cells.Item($row, 5) = $assignmentList.properties.LastJobProvisioningState
            }
            else {
                $worksheet.Cells.Item($row, 5) = "-"
            }
            
            $lastEndDate = $assignmentList.properties.LastJobEndTime
            $lastEndDateFormat = ""
            if ($null -ne $lastEndDate) {
                $lastEndDateFormat = [DateTime]::Parse($lastEndDate)
            }
            
            if ($lastEndDateFormat -ne "") {
                $worksheet.Cells.Item($row, 6) = $lastEndDateFormat.ToString("MM/dd/yyyy hh:mm tt")
            }
            else {
                $worksheet.Cells.Item($row, 6) = "-"
            }

            

            #Output Group information
            #Match the assignment with the resource.  Will need to check each one until we match
            foreach ($item in $assignmentList.properties.items) {
                $resourceId = $item.resourceId
                $found = $null
                $found = $alertRules | Where-Object { $_.id -eq $resourceId }
                if ($null -eq $found) {
                    $found = $automationRules | Where-Object { $_.id -eq $resourceId }
                }
                if ($null -eq $found) {
                    $found = $alertRules | Where-Object { $_.id -eq $resourceId }
                }
                if ($null -eq $found) {
                    $found = $workbooks | Where-Object { $_.id -eq $resourceId }
                }
                if ($null -eq $found) {
                    $found = $savedSearches | Where-Object { $_.id -eq $resourceId }
                }
                if ($null -eq $found) {
                    $worksheet.Cells.Item($row, 7) = $resourceId
                    $row++
                }
                else {
                    $worksheet.Cells.Item($row, 7) = $found.properties.displayName
                    $row++

                }

                $StatusBox.text += "."
            }
        }

        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Workspaces: " + $errorReturn
        $StatusBox.text += "`r`n"

    }
}

Function Add-AllRBAC( $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "RBAC"

    Write-Host "RBAC: " -NoNewline

    try {

        #Get all the assignments
        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Authorization/roleAssignments?api-version=2020-04-01-preview&%24filter=atScope()"
        $roleAssignments = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        #Get all the OOTB roles
        $url = "https://management.azure.com/providers/Microsoft.Authorization/roleDefinitions?%24filter=type%20eq%20%27BuiltInRole%27&api-version=2022-05-01-preview"
        $roleDefinitions = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value     
        
        $url = "https://management.azure.com/providers/Microsoft.Authorization/roleDefinitions?%24filter=type%20eq%20%27CustomRole%27&api-version=2022-05-01-preview"
        $customRoleDefinitions = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value    

        Connect-MgGraph -Scopes "Directory.Read.All" -NoWelcome
        $url = "https://graph.microsoft.com/v1.0/directoryObjects/getByIds"

        $objectTypes = @(
            "user",
            "group",
            "servicePrincipal",
            "device",
            "directoryObjectPartnerReference"
        )

        $objectIds = @()
        foreach ($roleAssignment in $roleAssignments.properties) {
            $objectIds += $roleAssignment.principalId
        }

        $body = @{
            ids   = $objectIds
            types = $objectTypes
        } | ConvertTo-Json -Depth 3

        $userIDs = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/directoryObjects/getByIds" -Body $body  -ContentType "application/json"
        
        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Type"
        $worksheet.Cells.Item($row, 3) = "Role"
        $worksheet.Cells.Item($row, 4) = "Scope"
   
        $row++

       
        $StatusBox.text += "RBAC (" + $roleAssignments.count + "): "

        #Get the role names and save it
        foreach ($roleAssignment in $roleAssignments) {
            $roleId = $roleAssignment.properties.roleDefinitionId.split("/subscriptions/$SubscriptionId")[1]
            $role = $roleDefinitions | Where-Object { $_.id -eq $roleId }
            if ($null -eq $role) {
                $role = $customRoleDefinitions | Where-Object { $_.id -eq $roleId }
            }
            #We don't care about this field so it is going to save the role name so we can sort
            $roleAssignment.properties.condition = $role.properties.roleName
        }

        foreach ($roleAssignment in $roleAssignments | Sort-Object { $_.properties.condition } ) {
            $user = $userIDs.value | Where-Object { $_.id -eq $roleAssignment.properties.principalId }
            #Some Managed Identities only match on their appId
            if ($null -eq $user) {
                $user = $userIDs | Where-Object { $_.appId -eq $roleAssignment.properties.principalId }
            }

            $StatusBox.text += "."
            $worksheet.Cells.Item($row, 1) = $user.displayName
             $userType="User"
            switch ($roleAssignment.properties.principalType )
            {
                "User" { $userType="User"}
                "ServicePrincipal" { $userType = "Service Principal"}
                "ManagedIdentity" {$userType = "Managed Identity"}
            }
            $worksheet.Cells.Item($row, 2) = $userType
            $worksheet.Cells.Item($row, 3) = $roleAssignment.properties.condition
        
            switch ([string]($roleAssignment.properties.scope.split("/").count)) {
                "2" {
                    $worksheet.Cells.Item($row, 4) = "Root"
                }
                "3" {
                    $worksheet.Cells.Item($row, 4) = "Subscription (Inherited)"
                }
                "4" {
                    $worksheet.Cells.Item($row, 4) = "This resource group"
                }
                default {
                    $worksheet.Cells.Item($row, 4) = "ManagementGroup"
                }
            }
            $row++
        }

        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Summary Rules: " + $errorReturn
        $StatusBox.text += "`r`n"

    }
}
Function Add-AllSummaryRules ( $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Summary Rules"

    Write-Host "Summary Rules: " -NoNewline

    try {

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Description"
        $worksheet.Cells.Item($row, 3) = "Frequency"
        $worksheet.Cells.Item($row, 4) = "Status"
        $worksheet.Cells.Item($row, 5) = "Provisioning State"
        $worksheet.Cells.Item($row, 6) = "Last Run Time"
        $worksheet.Cells.Item($row, 7) = "Last run row count"
        $worksheet.Cells.Item($row, 8) = "Last run status"
        $row++

        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/summarylogs?api-version=2023-01-01-preview"
        $summaryRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $workspaceUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$workspaceName" + "?api-version=2023-01-01-preview"
        $workspaceData = Invoke-RestMethod -Uri $workspaceUrl -Method Get -Headers $authHeader
        $workspaceId = $workspaceData.properties.CustomerID

        $queryUrl = "https://api.loganalytics.io/v1/workspaces/$workspaceId/query"
        $queryBody = @{'query' = 'LASummaryLogs | summarize arg_max(TimeGenerated, *) by RuleName | project RuleName, BinStartTime, ResultsRecordCount, Status' }
        $queryToken = (Get-AzAccessToken -ResourceUrl "https://api.loganalytics.io/")
        $queryAuth = @{
            'Content-Type'  = 'application/json' 
            'Authorization' = 'Bearer ' + $queryToken.Token 
        }
        $queryResults = Invoke-RestMethod -Uri $queryUrl -Method POST -Headers $queryAuth -Body ($queryBody | ConvertTo-Json -EnumsAsStrings -Depth 5)
        $queryRows = $queryResults.tables.rows

        $StatusBox.text += "Summary Rules (" + $summaryRules.count + "): "

        foreach ($rule in $summaryRules | Sort-Object { $_.properties.displayName }) {

            $StatusBox.text += "."
            $worksheet.Cells.Item($row, 1) = $rule.properties.displayName
            $worksheet.Cells.Item($row, 2) = $rule.properties.description
            $worksheet.Cells.Item($row, 3) = [string]$rule.properties.ruleDefinition.binsize + " minutes"
            $worksheet.Cells.Item($row, 4) = $rule.properties.isActive
            $worksheet.Cells.Item($row, 5) = $rule.properties.provisioningState 

            $filteredData = $queryRows | Where-Object { $_[0] -eq $rule.Name }

            $worksheet.Cells.Item($row, 6) = $filteredData[1] 
            $worksheet.Cells.Item($row, 7) = $filteredData[2] 
            $worksheet.Cells.Item($row, 8) = $filteredData[3] 
            $row++
        }

        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Summary Rules: " + $errorReturn
        $StatusBox.text += "`r`n"

    }
}

$tacticsAndTechniques = [ordered]@{
    "Reconnaissance"          = [ordered]@{"none" = 0; "T1595" = 0; "T1592" = 0; "T1589" = 0; "T1590" = 0; "T1591" = 0; "T1598" = 0; "T1597" = 0; "T1596" = 0; "T1593" = 0; "T1594" = 0 }
    "ResourceDevelopment"     = [ordered]@{"none" = 0; "T1650" = 0; "T1583" = 0; "T1586" = 0; "T1584" = 0; "T1587" = 0; "T1585" = 0; "T1588" = 0; "T1608" = 0 }
    "InitialAccess"           = [ordered]@{"none" = 0; "T1189" = 0; "T1190" = 0; "T1133" = 0; "T1200" = 0; "T1566" = 0; "T1091" = 0; "T1195" = 0; "T1199" = 0; "T1078" = 0; "T1659" = 0; "T1456" = 0; "T1461" = 0; "T1458" = 0; "T1474" = 0; "T1661" = 0; "T1664" = 0; "T1660" = 0; "T0817" = 0; "T0819" = 0; "T0866" = 0; "T0822" = 0; "T0883" = 0; "T0886" = 0; "T0847" = 0; "T0848" = 0; "T0865" = 0; "T0862" = 0; "T0864" = 0; "T0860" = 0 }
    "Execution"               = [ordered]@{"none" = 0; "T1059" = 0; "T1203" = 0; "T1559" = 0; "T1106" = 0; "T1053" = 0; "T1129" = 0; "T1072" = 0; "T1569" = 0; "T1204" = 0; "T1047" = 0 ; "T1648" = 0; "T1651" = 0; "T1609" = 0; "T1610" = 0; "T1623" = 0; "T1575" = 0; "T1603" = 0; "T1658" = 0; "T0858" = 0; "T0807" = 0; "T0871" = 0; "T0823" = 0; "T0874" = 0; "T0821" = 0; "T0834" = 0; "T0853" = 0; "T0863" = 0; "T0895" = 0 }
    "Persistence"             = [ordered]@{"none" = 0; "T1098" = 0; "T1197" = 0; "T1547" = 0; "T1037" = 0; "T1176" = 0; "T1554" = 0; "T1136" = 0; "T1543" = 0; "T1546" = 0; "T1133" = 0; "T1574" = 0; "T1556" = 0; "T1137" = 0; "T1542" = 0; "T1053" = 0; "T1505" = 0; "T1205" = 0; "T1078" = 0; "T1653" = 0; "T1525" = 0; "T1398" = 0; "T1577" = 0; "T1645" = 0; "T1624" = 0; "T1541" = 0; "T1625" = 0; "T1603" = 0; "T0891" = 0; "T0889" = 0; "T0839" = 0; "T0873" = 0; "T0857" = 0; "T0859" = 0 }
    "PrivilegeEscalation"     = [ordered]@{"none" = 0; "T1548" = 0; "T1134" = 0; "T1547" = 0; "T1037" = 0; "T1543" = 0; "T1484" = 0; "T1611" = 0; "T1546" = 0; "T1068" = 0; "T1574" = 0; "T1055" = 0; "T1053" = 0; "T1078" = 0; "T1098" = 0; "T1626" = 0; "T1404" = 0; "T1631" = 0; "T0890" = 0; "T0874" = 0 }    
    "DefenseEvasion"          = [ordered]@{"none" = 0; "T1548" = 0; "T1134" = 0; "T1197" = 0; "T1622" = 0; "T1140" = 0; "T1006" = 0; "T1484" = 0; "T1480" = 0; "T1211" = 0; "T1222" = 0; "T1564" = 0; "T1574" = 0; "T1562" = 0; "T1070" = 0; "T1202" = 0; "T1036" = 0; "T1556" = 0; "T1112" = 0; "T1027" = 0; "T1542" = 0; "T1055" = 0; "T1620" = 0; "T1207" = 0; "T1014" = 0; "T1553" = 0; "T1218" = 0; "T1216" = 0; "T1221" = 0; "T1205" = 0; "T1127" = 0; "T1550" = 0; "T1078" = 0; "T1497" = 0; "T1220" = 0; "T1656" = 0; "T1647" = 0; "T1578" = 0; "T1535" = 0; "T1666" = 0; "T1601" = 0; "T1599" = 0; "T1600" = 0; "T1612" = 0; "T1610" = 0; "T1407" = 0; "T1627" = 0; "T1541" = 0; "T1628" = 0; "T1617" = 0; "T1629" = 0; "T1630" = 0; "T1516" = 0; "T1575" = 0; "T1406" = 0; "T1631" = 0; "T1604" = 0; "T1632" = 0; "T1633" = 0; "T1661" = 0; "T1655" = 0 }
    "CredentialAccess"        = [ordered]@{"none" = 0; "T1557" = 0; "T1110" = 0; "T1555" = 0; "T1212" = 0; "T1187" = 0; "T1606" = 0; "T1056" = 0; "T1556" = 0; "T1111" = 0; "T1621" = 0; "T1040" = 0; "T1003" = 0; "T1649" = 0; "T1558" = 0; "T1539" = 0; "T1552" = 0; "T1528" = 0; "T1517" = 0; "T1414" = 0; "T1417" = 0; "T1635" = 0; "T1634" = 0 }  
    "Discovery"               = [ordered]@{"none" = 0; "T1087" = 0; "T1010" = 0; "T1217" = 0; "T1622" = 0; "T1652" = 0; "T1482" = 0; "T1083" = 0; "T1615" = 0; "T1046" = 0; "T1135" = 0; "T1040" = 0; "T1201" = 0; "T1120" = 0; "T1069" = 0; "T1057" = 0; "T1012" = 0; "T1018" = 0; "T1518" = 0; "T1082" = 0; "T1614" = 0; "T1016" = 0; "T1049" = 0; "T1033" = 0; "T1007" = 0; "T1124" = 0; "T1497" = 0; "T1654" = 0; "T1526" = 0; "T1538" = 0; "T1580" = 0; "T1619" = 0; "T1613" = 0; "T1420" = 0; "T1430" = 0; "T1423" = 0; "T1424" = 0; "T1418" = 0; "T1426" = 0; "T1422" = 0; "T1421" = 0; "T0840" = 0; "T0842" = 0; "T0846" = 0; "T0888" = 0; "T0887" = 0 }   
    "LateralMovement"         = [ordered]@{"none" = 0; "T1210" = 0; "T1534" = 0; "T1570" = 0; "T1563" = 0; "T1021" = 0; "T1091" = 0; "T1072" = 0; "T1080" = 0; "T1550" = 0; "T1428" = 0; "T1458" = 0; "T0812" = 0; "T0866" = 0; "T0891" = 0; "T0867" = 0; "T0843" = 0; "T0886" = 0; "T0859" = 0 }
    "Collection"              = [ordered]@{"none" = 0; "T1557" = 0; "T1560" = 0; "T1123" = 0; "T1119" = 0; "T1185" = 0; "T1115" = 0; "T1213" = 0; "T1005" = 0; "T1039" = 0; "T1025" = 0; "T1074" = 0; "T1114" = 0; "T1056" = 0; "T1113" = 0; "T1125" = 0; "T1530" = 0; "T1602" = 0; "T1517" = 0; "T1638" = 0; "T1532" = 0; "T1429" = 0; "T1616" = 0; "T1414" = 0; "T1533" = 0; "T1417" = 0; "T1430" = 0; "T1636" = 0; "T1513" = 0; "T1409" = 0; "T1512" = 0; "T0830" = 0; "T0802" = 0; "T0811" = 0; "T0893" = 0; "T0868" = 0; "T0877" = 0; "T0801" = 0; "T0861" = 0; "T0845" = 0; "T0852" = 0; "T0887" = 0 }  
    "CommandAndControl"       = [ordered]@{"none" = 0; "T1071" = 0; "T1092" = 0; "T1132" = 0; "T1001" = 0; "T1568" = 0; "T1573" = 0; "T1008" = 0; "T1105" = 0; "T1104" = 0; "T1095" = 0; "T1571" = 0; "T1572" = 0; "T1090" = 0; "T1219" = 0; "T1205" = 0; "T1102" = 0; "T1659" = 0; "T1665" = 0; "T1437" = 0; "T1616" = 0; "T1637" = 0; "T1521" = 0; "T1544" = 0; "T1509" = 0; "T1644" = 0; "T1481" = 0; "T1663" = 0; "T0885" = 0; "T0884" = 0; "T0869" = 0 }
    "Exfiltration"            = [ordered]@{"none" = 0; "T1020" = 0; "T1030" = 0; "T1048" = 0; "T1041" = 0; "T1011" = 0; "T1052" = 0; "T1567" = 0; "T1029" = 0 ; "T1537" = 0; "T1639" = 0; "T1646" = 0 }
    "Impact"                  = [ordered]@{"none" = 0; "T1531" = 0; "T1485" = 0; "T1486" = 0; "T1565" = 0; "T1491" = 0; "T1561" = 0; "T1499" = 0; "T1495" = 0; "T1490" = 0; "T1498" = 0; "T1496" = 0; "T1489" = 0; "T1529" = 0; "T1657" = 0; "T1640" = 0; "T1616" = 0; "T1471" = 0; "T1641" = 0; "T1642" = 0; "T1643" = 0; "T1516" = 0; "T1464" = 0; "T1582" = 0; "T1662" = 0; "T0879" = 0; "T0813" = 0; "T0815" = 0; "T0826" = 0; "T0827" = 0; "T0828" = 0; "T0837" = 0; "T0880" = 0; "T0829" = 0; "T0831" = 0; "T0832" = 0; "T0882" = 0 }  
    "Evasion"                 = [ordered]@{"none" = 0; "T0858" = 0; "T0820" = 0; "T0872" = 0; "T0849" = 0; "T0851" = 0; "T0856" = 0; "T0894" = 0 }
    "ImpairProcessControl"    = [ordered]@{"none" = 0; "T0806" = 0; "T0836" = 0; "T0839" = 0; "T0856" = 0; "T0855" = 0 }
    "InhibitResponseFunction" = [ordered]@{"none" = 0; "T0880" = 0; "T0878" = 0; "T0803" = 0; "T0804" = 0; "T0805" = 0; "T0892" = 0; "T0809" = 0; "T0814" = 0; "T0816" = 0; "T0835" = 0; "T0838" = 0; "T0851" = 0; "T0881" = 0; "T0857" = 0 }
}

$tacticDescriptionHash = @{
    "Reconnaissance"      = "The adversary is trying to gather information they can use to plan future operations."
    "ResourceDevelopment" = "The adversary is trying to establish resources they can use to support operations."
    "Collection"          = "Collection consists of techniques used to identify and gather information."
    "CommandAndControl"   = "The command and control tactic represents how adversaries communicate with systems under their control within a target network."
    "CredentialAccess"    = "Credential access represents techniques resulting in access to or control over system, domain, or service credentials."
    "DefenseEvasion"      = "Defense evasion consists of techniques an adversary may use to evade detection or avoid other defenses."
    "Discovery"           = "Discovery consists of techniques that allow the adversary to gain knowledge about the system and internal network."
    "Execution"           = "The execution tactic represents techniques that result in the execution of adversary-controlled code on a local or remote system."
    "Exfiltration"        = "Exfiltration refers to techniques and attributes that result or aid in the adversary removing files and information from a target network."
    "Impact"              = "Impact consists of techniques that adversaries use to disrupt availability or compromise integrity by manipulating business and operational processes."
    "InitialAccess"       = "The initial access tactic represents the vectors adversaries use to gain an initial foothold within a network."
    "LateralMovement"     = "Lateral movement consists of techniques that enable an adversary to access and control remote systems on a network."
    "Persistence"         = "Persistence is any access, action, or configuration change to a system that gives an adversary a persistent presence on that system."
    "PrivilegeEscalation" = "Privilege escalation is the result of actions that allows an adversary to obtain a higher level of permissions on a system or network."
    "Evasion"             = "Evasion consists of techniques that adversaries use to avoid technical defenses throughout their campaign."
}

$tacticNameHash = @{
    "Reconnaissance"          = "Reconnaissance"    
    "ResourceDevelopment"     = "Resource Development"
    "Collection"              = "Collection"
    "CommandAndControl"       = "Command And Control"
    "CredentialAccess"        = "Credential Access"
    "DefenseEvasion"          = "Defense Evasion"
    "Discovery"               = "Discovery"
    "Execution"               = "Execution"
    "Exfiltration"            = "Exfiltration"
    "Impact"                  = "Impact"
    "InitialAccess"           = "Initial Access."
    "LateralMovement"         = "Lateral Movement"
    "Persistence"             = "Persistence"
    "PrivilegeEscalation"     = "Privilege Escalation"
    "Evasion"                 = "Evasion"
    "ImpairProcessControl"    = "Impair Process Control"
    "InhibitResponseFunction" = "Inhibit Response Function"
}

$techniqueNameHash = [ordered] @{
    "1548"      = "Abuse Elevation Control Mechanism"
    "T1548.001" = "Setuid and Setgid"
    "T1548.002" = "Bypass User Account Control"
    "T1548.003" = "Sudo and Sudo Caching"
    "T1548.004" = "Elevated Execution with Prompt"
    "T1548.005" = "Temporary Elevated Cloud Access"
    "T1548.006" = "TCC Manipulation"
    "T1134"     = "Access Token Manipulation"
    "T1134.001" = "Token Impersonation/Theft"
    "T1134.002" = "Create Process with Token"
    "T1134.003" = "Make and Impersonate Token"
    "T1134.004" = "Parent PID Spoofing"
    "T1134.005" = "SID-History Injection"
    "T1531"     = "Account Access Removal"
    "T1087"     = "Account Discovery"
    "T1087.001" = "Local Account"
    "T1087.002" = "Domain Account"
    "T1087.003" = "Email Account"
    "T1087.004" = "Cloud Account"
    "T1098"     = "Account Manipulation"
    "T1098.001" = "Additional Cloud Credentials"
    "T1098.002" = "Additional Email Delegate Permissions"
    "T1098.003" = "Additional Cloud Roles"
    "T1098.004" = "SSH Authorized Keys"
    "T1098.005" = "Device Registration"
    "T1098.006" = "Additional Container Cluster Roles"
    "T1098.007" = "Additional Local or Domain Groups"
    "T1650"     = "Acquire Access"
    "T1583"     = "Acquire Infrastructure"
    "T1583.001" = "Domains"
    "T1583.002" = "DNS Server"
    "T1583.003" = "Virtual Private Server"
    "T1583.004" = "Server"
    "T1583.005" = "Botnet"
    "T1583.006" = "Web Services"
    "T1583.007" = "Serverless"
    "T1583.008" = "Malvertising"
    "T1595"     = "Active Scanning"
    "T1595.001" = "Scanning IP Blocks"
    "T1595.002" = "Vulnerability Scanning"
    "T1595.003" = "Excellist Scanning"
    "T1557"     = "Adversary-in-the-Middle"
    "T1557.001" = "LLMNR/NBT-NS Poisoning and SMB Relay"
    "T1557.002" = "ARP Cache Poisoning"
    "T1557.003" = "DHCP Spoofing"
    "T1557.004" = "Evil Twin"
    "T1071"     = "Application Layer Protocol"
    "T1071.001" = "Web Protocols"
    "T1071.002" = "File Transfer Protocols"
    "T1071.003" = "Mail Protocols"
    "T1071.004" = "DNS"
    "T1071.005" = "Publish/Subscribe Protocols"
    "T1010"     = "Application Window Discovery"
    "T1560"     = "Archive Collected Data"
    "T1560.001" = "Archive via Utility"
    "T1560.002" = "Archive via Library"
    "T1560.003" = "Archive via Custom Method"
    "T1123"     = "Audio Capture"
    "T1119"     = "Automated Collection"
    "T1020"     = "Automated Exfiltration"
    "T1020.001" = "Traffic Duplication"
    "T1197"     = "BITS Jobs"
    "T1547"     = "Boot or Logon Autostart Execution"
    "T1547.001" = "Registry Run Keys / Startup Folder"
    "T1547.002" = "Authentication Package"
    "T1547.003" = "Time Providers"
    "T1547.004" = "Winlogon Helper DLL"
    "T1547.005" = "Security Support Provider"
    "T1547.006" = "Kernel Modules and Extensions"
    "T1547.007" = "Re-opened Applications"
    "T1547.008" = "LSASS Driver"
    "T1547.009" = "Shortcut Modification"
    "T1547.010" = "Port Monitors"
    "T1547.012" = "Print Processors"
    "T1547.013" = "XDG Autostart Entries"
    "T1547.014" = "Active Setup"
    "T1547.015" = "Login Items"
    "T1037"     = "Boot or Logon Initialization Scripts"
    "T1037.001" = "Logon Script (Windows)"
    "T1037.002" = "Login Hook"
    "T1037.003" = "Network Logon Script"
    "T1037.004" = "RC Scripts"
    "T1037.005" = "Startup Items"
    "T1176"     = "Browser Extensions"
    "T1217"     = "Browser Information Discovery"
    "T1185"     = "Browser Session Hijacking"
    "T1110"     = "Brute Force"
    "T1110.001" = "Password Guessing"
    "T1110.002" = "Password Cracking"
    "T1110.003" = "Password Spraying"
    "T1110.004" = "Credential Stuffing"
    "T1612"     = "Build Image on Host"
    "T1115"     = "Clipboard Data"
    "T1651"     = "Cloud Administration Command"
    "T1580"     = "Cloud Infrastructure Discovery"
    "T1538"     = "Cloud Service Dashboard"
    "T1526"     = "Cloud Service Discovery"
    "T1619"     = "Cloud Storage Object Discovery"
    "T1059"     = "Command and Scripting Interpreter"
    "T1059.001" = "PowerShell"
    "T1059.002" = "AppleScript"
    "T1059.003" = "Windows Command Shell"
    "T1059.004" = "Unix Shell"
    "T1059.005" = "Visual Basic"
    "T1059.006" = "Python"
    "T1059.007" = "JavaScript"
    "T1059.008" = "Network Device CLI"
    "T1059.009" = "Cloud API"
    "T1059.010" = "AutoHotKey & AutoIT"
    "T1059.011" = "Lua"
    "T1092"     = "Communication Through Removable Media"
    "T1586"     = "Compromise Accounts"
    "T1586.001" = "Social Media Accounts"
    "T1586.002" = "Email Accounts"
    "T1586.003" = "Cloud Accounts"
    "T1554"     = "Compromise Host Software Binary"
    "T1584"     = "Compromise Infrastructure"
    "T1584.001" = "Domains"
    "T1584.002" = "DNS Server"
    "T1584.003" = "Virtual Private Server"
    "T1584.004" = "Server"
    "T1584.005" = "Botnet"
    "T1584.006" = "Web Services"
    "T1584.007" = "Serverless"
    "T1584.008" = "Network Devices"
    "T1609"     = "Container Administration Command"
    "T1613"     = "Container and Resource Discovery"
    "T1659"     = "Content Injection"
    "T1136"     = "Create Account"
    "T1136.001" = "Local Account"
    "T1136.002" = "Domain Account"
    "T1136.003" = "Cloud Account"
    "T1543"     = "Create or Modify System Process"
    "T1543.001" = "Launch Agent"
    "T1543.002" = "Systemd Service"
    "T1543.003" = "Windows Service"
    "T1543.004" = "Launch Daemon"
    "T1543.005" = "Container Service"
    "T1555"     = "Credentials from Password Stores"
    "T1555.001" = "Keychain"
    "T1555.002" = "Securityd Memory"
    "T1555.003" = "Credentials from Web Browsers"
    "T1555.004" = "Windows Credential Manager"
    "T1555.005" = "Password Managers"
    "T1555.006" = "Cloud Secrets Management Stores"
    "T1485"     = "Data Destruction"
    "T1485.001" = "Lifecycle-Triggered Deletion"
    "T1132"     = "Data Encoding"
    "T1132.001" = "Standard Encoding"
    "T1132.002" = "Non-Standard Encoding"
    "T1486"     = "Data Encrypted for Impact"
    "T1530"     = "Data from Cloud Storage"
    "T1602"     = "Data from Configuration Repository"
    "T1602.001" = "SNMP (MIB Dump)"
    "T1602.002" = "Network Device Configuration Dump"
    "T1213"     = "Data from Information Repositories"
    "T1213.001" = "Confluence"
    "T1213.002" = "Sharepoint"
    "T1213.003" = "Code Repositories"
    "T1213.004" = "Customer Relationship Management Software"
    "T1213.005" = "Messaging Applications"
    "T1005"     = "Data from Local System"
    "T1039"     = "Data from Network Shared Drive"
    "T1025"     = "Data from Removable Media"
    "T1565"     = "Data Manipulation"
    "T1565.001" = "Stored Data Manipulation"
    "T1565.002" = "Transmitted Data Manipulation"
    "T1565.003" = "Runtime Data Manipulation"
    "T1001"     = "Data Obfuscation"
    "T1001.001" = "Junk Data"
    "T1001.002" = "Steganography"
    "T1001.003" = "Protocol or Service Impersonation"
    "T1074"     = "Data Staged"
    "T1074.001" = "Local Data Staging"
    "T1074.002" = "Remote Data Staging"
    "T1030"     = "Data Transfer Size Limits"
    "T1622"     = "Debugger Evasion"
    "T1491"     = "Defacement"
    "T1491.001" = "Internal Defacement"
    "T1491.002" = "External Defacement"
    "T1140"     = "Deobfuscate/Decode Files or Information"
    "T1610"     = "Deploy Container"
    "T1587"     = "Develop Capabilities"
    "T1587.001" = "Malware"
    "T1587.002" = "Code Signing Certificates"
    "T1587.003" = "Digital Certificates"
    "T1587.004" = "Exploits"
    "T1652"     = "Device Driver Discovery"
    "T1006"     = "Direct Volume Access"
    "T1561"     = "Disk Wipe"
    "T1561.001" = "Disk Content Wipe"
    "T1561.002" = "Disk Structure Wipe"
    "T1484"     = "Domain or Tenant Policy Modification"
    "T1484.001" = "Group Policy Modification"
    "T1484.002" = "Trust Modification"
    "T1482"     = "Domain Trust Discovery"
    "T1189"     = "Drive-by Compromise"
    "T1568"     = "Dynamic Resolution"
    "T1568.001" = "Fast Flux DNS"
    "T1568.002" = "Domain Generation Algorithms"
    "T1568.003" = "DNS Calculation"
    "T1114"     = "Email Collection"
    "T1114.001" = "Local Email Collection"
    "T1114.002" = "Remote Email Collection"
    "T1114.003" = "Email Forwarding Rule"
    "T1573"     = "Encrypted Channel"
    "T1573.001" = "Symmetric Cryptography"
    "T1573.002" = "Asymmetric Cryptography"
    "T1499"     = "Endpoint Denial of Service"
    "T1499.001" = "OS Exhaustion Flood"
    "T1499.002" = "Service Exhaustion Flood"
    "T1499.003" = "Application Exhaustion Flood"
    "T1499.004" = "Application or System Exploitation"
    "T1611"     = "Escape to Host"
    "T1585"     = "Establish Accounts"
    "T1585.001" = "Social Media Accounts"
    "T1585.002" = "Email Accounts"
    "T1585.003" = "Cloud Accounts"
    "T1546"     = "Event Triggered Execution"
    "T1546.001" = "Change Default File Association"
    "T1546.002" = "Screensaver"
    "T1546.003" = "Windows Management Instrumentation Event Subscription"
    "T1546.004" = "Unix Shell Configuration Modification"
    "T1546.005" = "Trap"
    "T1546.006" = "LC_LOAD_DYLIB Addition"
    "T1546.007" = "Netsh Helper DLL"
    "T1546.008" = "Accessibility Features"
    "T1546.009" = "AppCert DLLs"
    "T1546.010" = "AppInit DLLs"
    "T1546.011" = "Application Shimming"
    "T1546.012" = "Image File Execution Options Injection"
    "T1546.013" = "PowerShell Profile"
    "T1546.014" = "Emond"
    "T1546.015" = "Component Object Model Hijacking"
    "T1546.016" = "Installer Packages"
    "T1546.017" = "Udev Rules"
    "T1480"     = "Execution Guardrails"
    "T1480.001" = "Environmental Keying"
    "T1480.002" = "Mutual Exclusion"
    "T1048"     = "Exfiltration Over Alternative Protocol"
    "T1048.001" = "Exfiltration Over Symmetric Encrypted Non-C2 Protocol"
    "T1048.002" = "Exfiltration Over Asymmetric Encrypted Non-C2 Protocol"
    "T1048.003" = "Exfiltration Over Unencrypted Non-C2 Protocol"
    "T1041"     = "Exfiltration Over C2 Channel"
    "T1011"     = "Exfiltration Over Other Network Medium"
    "T1011.001" = "Exfiltration Over Bluetooth"
    "T1052"     = "Exfiltration Over Physical Medium"
    "T1052.001" = "Exfiltration over USB"
    "T1567"     = "Exfiltration Over Web Service"
    "T1567.001" = "Exfiltration to Code Repository"
    "T1567.002" = "Exfiltration to Cloud Storage"
    "T1567.003" = "Exfiltration to Text Storage Sites"
    "T1567.004" = "Exfiltration Over Webhook"
    "T1190"     = "Exploit Public-Facing Application"
    "T1203"     = "Exploitation for Client Execution"
    "T1212"     = "Exploitation for Credential Access"
    "T1211"     = "Exploitation for Defense Evasion"
    "T1068"     = "Exploitation for Privilege Escalation"
    "T1210"     = "Exploitation of Remote Services"
    "T1133"     = "External Remote Services"
    "T1008"     = "Fallback Channels"
    "T1083"     = "File and Directory Discovery"
    "T1222"     = "File and Directory Permissions Modification"
    "T1222.001" = "Windows File and Directory Permissions Modification"
    "T1222.002" = "Linux and Mac File and Directory Permissions Modification"
    "T1657"     = "Financial Theft"
    "T1495"     = "Firmware Corruption"
    "T1187"     = "Forced Authentication"
    "T1606"     = "Forge Web Credentials"
    "T1606.001" = "Web Cookies"
    "T1606.002" = "SAML Tokens"
    "T1592"     = "Gather Victim Host Information"
    "T1592.001" = "Hardware"
    "T1592.002" = "Software"
    "T1592.003" = "Firmware"
    "T1592.004" = "Client Configurations"
    "T1589"     = "Gather Victim Identity Information"
    "T1589.001" = "Credentials"
    "T1589.002" = "Email Addresses"
    "T1589.003" = "Employee Names"
    "T1590"     = "Gather Victim Network Information"
    "T1590.001" = "Domain Properties"
    "T1590.002" = "DNS"
    "T1590.003" = "Network Trust Dependencies"
    "T1590.004" = "Network Topology"
    "T1590.005" = "IP Addresses"
    "T1590.006" = "Network Security Appliances"
    "T1591"     = "Gather Victim Org Information"
    "T1591.001" = "Determine Physical Locations"
    "T1591.002" = "Business Relationships"
    "T1591.003" = "Identify Business Tempo"
    "T1591.004" = "Identify Roles"
    "T1615"     = "Group Policy Discovery"
    "T1200"     = "Hardware Additions"
    "T1564"     = "Hide Artifacts"
    "T1564.001" = "Hidden Files and Directories"
    "T1564.002" = "Hidden Users"
    "T1564.003" = "Hidden Window"
    "T1564.004" = "NTFS File Attributes"
    "T1564.005" = "Hidden File System"
    "T1564.006" = "Run Virtual Instance"
    "T1564.007" = "VBA Stomping"
    "T1564.008" = "Email Hiding Rules"
    "T1564.009" = "Resource Forking"
    "T1564.010" = "Process Argument Spoofing"
    "T1564.011" = "Ignore Process Interrupts"
    "T1564.012" = "File/Path Exclusions"
    "T1665"     = "Hide Infrastructure"
    "T1574"     = "Hijack Execution Flow"
    "T1574.001" = "DLL Search Order Hijacking"
    "T1574.002" = "DLL Side-Loading"
    "T1574.004" = "Dylib Hijacking"
    "T1574.005" = "Executable Installer File Permissions Weakness"
    "T1574.006" = "Dynamic Linker Hijacking"
    "T1574.007" = "Path Interception by PATH Environment Variable"
    "T1574.008" = "Path Interception by Search Order Hijacking"
    "T1574.009" = "Path Interception by Unquoted Path"
    "T1574.010" = "Services File Permissions Weakness"
    "T1574.011" = "Services Registry Permissions Weakness"
    "T1574.012" = "COR_PROFILER"
    "T1574.013" = "KernelCallbackTable"
    "T1574.014" = "AppDomainManager"
    "T1562"     = "Impair Defenses"
    "T1562.001" = "Disable or Modify Tools"
    "T1562.002" = "Disable Windows Event Logging"
    "T1562.003" = "Impair Command History Logging"
    "T1562.004" = "Disable or Modify System Firewall"
    "T1562.006" = "Indicator Blocking"
    "T1562.007" = "Disable or Modify Cloud Firewall"
    "T1562.008" = "Disable or Modify Cloud Logs"
    "T1562.009" = "Safe Mode Boot"
    "T1562.010" = "Downgrade Attack"
    "T1562.011" = "Spoof Security Alerting"
    "T1562.012" = "Disable or Modify Linux Audit System"
    "T1656"     = "Impersonation"
    "T1525"     = "Implant Internal Image"
    "T1070"     = "Indicator Removal"
    "T1070.001" = "Clear Windows Event Logs"
    "T1070.002" = "Clear Linux or Mac System Logs"
    "T1070.003" = "Clear Command History"
    "T1070.004" = "File Deletion"
    "T1070.005" = "Network Share Connection Removal"
    "T1070.006" = "Timestomp"
    "T1070.007" = "Clear Network Connection History and Configurations"
    "T1070.008" = "Clear Mailbox Data"
    "T1070.009" = "Clear Persistence"
    "T1070.010" = "Relocate Malware"
    "T1202"     = "Indirect Command Execution"
    "T1105"     = "Ingress Tool Transfer"
    "T1490"     = "Inhibit System Recovery"
    "T1056"     = "Input Capture"
    "T1056.001" = "Keylogging"
    "T1056.002" = "GUI Input Capture"
    "T1056.003" = "Web Portal Capture"
    "T1056.004" = "Credential API Hooking"
    "T1559"     = "Inter-Process Communication"
    "T1559.001" = "Component Object Model"
    "T1559.002" = "Dynamic Data Exchange"
    "T1559.003" = "XPC Services"
    "T1534"     = "Internal Spearphishing"
    "T1570"     = "Lateral Tool Transfer"
    "T1654"     = "Log Enumeration"
    "T1036"     = "Masquerading"
    "T1036.001" = "Invalid Code Signature"
    "T1036.002" = "Right-to-Left Override"
    "T1036.003" = "Rename System Utilities"
    "T1036.004" = "Masquerade Task or Service"
    "T1036.005" = "Match Legitimate Name or Location"
    "T1036.006" = "Space after Filename"
    "T1036.007" = "Double File Extension"
    "T1036.008" = "Masquerade File Type"
    "T1036.009" = "Break Process Trees"
    "T1036.010" = "Masquerade Account Name"
    "T1556"     = "Modify Authentication Process"
    "T1556.001" = "Domain Controller Authentication"
    "T1556.002" = "Password Filter DLL"
    "T1556.003" = "Pluggable Authentication Modules"
    "T1556.004" = "Network Device Authentication"
    "T1556.005" = "Reversible Encryption"
    "T1556.006" = "Multi-Factor Authentication"
    "T1556.007" = "Hybrid Identity"
    "T1556.008" = "Network Provider DLL"
    "T1556.009" = "Conditional Access Policies"
    "T1578"     = "Modify Cloud Compute Infrastructure"
    "T1578.001" = "Create Snapshot"
    "T1578.002" = "Create Cloud Instance"
    "T1578.003" = "Delete Cloud Instance"
    "T1578.004" = "Revert Cloud Instance"
    "T1578.005" = "Modify Cloud Compute Configurations"
    "T1666"     = "Modify Cloud Resource Hierarchy"
    "T1112"     = "Modify Registry"
    "T1601"     = "Modify System Image"
    "T1601.001" = "Patch System Image"
    "T1601.002" = "Downgrade System Image"
    "T1111"     = "Multi-Factor Authentication Interception"
    "T1621"     = "Multi-Factor Authentication Request Generation"
    "T1104"     = "Multi-Stage Channels"
    "T1106"     = "Native API"
    "T1599"     = "Network Boundary Bridging"
    "T1599.001" = "Network Address Translation Traversal"
    "T1498"     = "Network Denial of Service"
    "T1498.001" = "Direct Network Flood"
    "T1498.002" = "Reflection Amplification"
    "T1046"     = "Network Service Discovery"
    "T1135"     = "Network Share Discovery"
    "T1040"     = "Network Sniffing"
    "T1095"     = "Non-Application Layer Protocol"
    "T1571"     = "Non-Standard Port"
    "T1027"     = "Obfuscated Files or Information"
    "T1027.001" = "Binary Padding"
    "T1027.002" = "Software Packing"
    "T1027.003" = "Steganography"
    "T1027.004" = "Compile After Delivery"
    "T1027.005" = "Indicator Removal from Tools"
    "T1027.006" = "HTML Smuggling"
    "T1027.007" = "Dynamic API Resolution"
    "T1027.008" = "Stripped Payloads"
    "T1027.009" = "Embedded Payloads"
    "T1027.010" = "Command Obfuscation"
    "T1027.011" = "Fileless Storage"
    "T1027.012" = "LNK Icon Smuggling"
    "T1027.013" = "Encrypted/Encoded File"
    "T1027.014" = "Polymorphic Code"
    "T1588"     = "Obtain Capabilities"
    "T1588.001" = "Malware"
    "T1588.002" = "Tool"
    "T1588.003" = "Code Signing Certificates"
    "T1588.004" = "Digital Certificates"
    "T1588.005" = "Exploits"
    "T1588.006" = "Vulnerabilities"
    "T1588.007" = "Artificial Intelligence"
    "T1137"     = "Office Application Startup"
    "T1137.001" = "Office Template Macros"
    "T1137.002" = "Office Test"
    "T1137.003" = "Outlook Forms"
    "T1137.004" = "Outlook Home Page"
    "T1137.005" = "Outlook Rules"
    "T1137.006" = "Add-ins"
    "T1003"     = "OS Credential Dumping"
    "T1003.001" = "LSASS Memory"
    "T1003.002" = "Security Account Manager"
    "T1003.003" = "NTDS"
    "T1003.004" = "LSA Secrets"
    "T1003.005" = "Cached Domain Credentials"
    "T1003.006" = "DCSync"
    "T1003.007" = "Proc Filesystem"
    "T1003.008" = "/etc/passwd and /etc/shadow"
    "T1201"     = "Password Policy Discovery"
    "T1120"     = "Peripheral Device Discovery"
    "T1069"     = "Permission Groups Discovery"
    "T1069.001" = "Local Groups"
    "T1069.002" = "Domain Groups"
    "T1069.003" = "Cloud Groups"
    "T1566"     = "Phishing"
    "T1566.001" = "Spearphishing Attachment"
    "T1566.002" = "Spearphishing Link"
    "T1566.003" = "Spearphishing via Service"
    "T1566.004" = "Spearphishing Voice"
    "T1598"     = "Phishing for Information"
    "T1598.001" = "Spearphishing Service"
    "T1598.002" = "Spearphishing Attachment"
    "T1598.003" = "Spearphishing Link"
    "T1598.004" = "Spearphishing Voice"
    "T1647"     = "Plist File Modification"
    "T1653"     = "Power Settings"
    "T1542"     = "Pre-OS Boot"
    "T1542.001" = "System Firmware"
    "T1542.002" = "Component Firmware"
    "T1542.003" = "Bootkit"
    "T1542.004" = "ROMMONkit"
    "T1542.005" = "TFTP Boot"
    "T1057"     = "Process Discovery"
    "T1055"     = "Process Injection"
    "T1055.001" = "Dynamic-link Library Injection"
    "T1055.002" = "Portable Executable Injection"
    "T1055.003" = "Thread Execution Hijacking"
    "T1055.004" = "Asynchronous Procedure Call"
    "T1055.005" = "Thread Local Storage"
    "T1055.008" = "Ptrace System Calls"
    "T1055.009" = "Proc Memory"
    "T1055.011" = "Extra Window Memory Injection"
    "T1055.012" = "Process Hollowing"
    "T1055.013" = "Process Doppelgänging"
    "T1055.014" = "VDSO Hijacking"
    "T1055.015" = "ListPlanting"
    "T1572"     = "Protocol Tunneling"
    "T1090"     = "Proxy"
    "T1090.001" = "Internal Proxy"
    "T1090.002" = "External Proxy"
    "T1090.003" = "Multi-hop Proxy"
    "T1090.004" = "Domain Fronting"
    "T1012"     = "Query Registry"
    "T1620"     = "Reflective Code Loading"
    "T1219"     = "Remote Access Software"
    "T1563"     = "Remote Service Session Hijacking"
    "T1563.001" = "SSH Hijacking"
    "T1563.002" = "RDP Hijacking"
    "T1021"     = "Remote Services"
    "T1021.001" = "Remote Desktop Protocol"
    "T1021.002" = "SMB/Windows Admin Shares"
    "T1021.003" = "Distributed Component Object Model"
    "T1021.004" = "SSH"
    "T1021.005" = "VNC"
    "T1021.006" = "Windows Remote Management"
    "T1021.007" = "Cloud Services"
    "T1021.008" = "Direct Cloud VM Connections"
    "T1018"     = "Remote System Discovery"
    "T1091"     = "Replication Through Removable Media"
    "T1496"     = "Resource Hijacking"
    "T1496.001" = "Compute Hijacking"
    "T1496.002" = "Bandwidth Hijacking"
    "T1496.003" = "SMS Pumping"
    "T1496.004" = "Cloud Service Hijacking"
    "T1207"     = "Rogue Domain Controller"
    "T1014"     = "Rootkit"
    "T1053"     = "Scheduled Task/Job"
    "T1053.002" = "At"
    "T1053.003" = "Cron"
    "T1053.005" = "Scheduled Task"
    "T1053.006" = "Systemd Timers"
    "T1053.007" = "Container Orchestration Job"
    "T1029"     = "Scheduled Transfer"
    "T1113"     = "Screen Capture"
    "T1597"     = "Search Closed Sources"
    "T1597.001" = "Threat Intel Vendors"
    "T1597.002" = "Purchase Technical Data"
    "T1596"     = "Search Open Technical Databases"
    "T1596.001" = "DNS/Passive DNS"
    "T1596.002" = "WHOIS"
    "T1596.003" = "Digital Certificates"
    "T1596.004" = "CDNs"
    "T1596.005" = "Scan Databases"
    "T1593"     = "Search Open Websites/Domains"
    "T1593.001" = "Social Media"
    "T1593.002" = "Search Engines"
    "T1593.003" = "Code Repositories"
    "T1594"     = "Search Victim-Owned Websites"
    "T1505"     = "Server Software Component"
    "T1505.001" = "SQL Stored Procedures"
    "T1505.002" = "Transport Agent"
    "T1505.003" = "Web Shell"
    "T1505.004" = "IIS Components"
    "T1505.005" = "Terminal Services DLL"
    "T1648"     = "Serverless Execution"
    "T1489"     = "Service Stop"
    "T1129"     = "Shared Modules"
    "T1072"     = "Software Deployment Tools"
    "T1518"     = "Software Discovery"
    "T1518.001" = "Security Software Discovery"
    "T1608"     = "Stage Capabilities"
    "T1608.001" = "Upload Malware"
    "T1608.002" = "Upload Tool"
    "T1608.003" = "Install Digital Certificate"
    "T1608.004" = "Drive-by Target"
    "T1608.005" = "Link Target"
    "T1608.006" = "SEO Poisoning"
    "T1528"     = "Steal Application Access Token"
    "T1649"     = "Steal or Forge Authentication Certificates"
    "T1558"     = "Steal or Forge Kerberos Tickets"
    "T1558.001" = "Golden Ticket"
    "T1558.002" = "Silver Ticket"
    "T1558.003" = "Kerberoasting"
    "T1558.004" = "AS-REP Roasting"
    "T1558.005" = "Ccache Files"
    "T1539"     = "Steal Web Session Cookie"
    "T1553"     = "Subvert Trust Controls"
    "T1553.001" = "Gatekeeper Bypass"
    "T1553.002" = "Code Signing"
    "T1553.003" = "SIP and Trust Provider Hijacking"
    "T1553.004" = "Install Root Certificate"
    "T1553.005" = "Mark-of-the-Web Bypass"
    "T1553.006" = "Code Signing Policy Modification"
    "T1195"     = "Supply Chain Compromise"
    "T1195.001" = "Compromise Software Dependencies and Development Tools"
    "T1195.002" = "Compromise Software Supply Chain"
    "T1195.003" = "Compromise Hardware Supply Chain"
    "T1218"     = "System Binary Proxy Execution"
    "T1218.001" = "Compiled HTML File"
    "T1218.002" = "Control Panel"
    "T1218.003" = "CMSTP"
    "T1218.004" = "InstallUtil"
    "T1218.005" = "Mshta"
    "T1218.007" = "Msiexec"
    "T1218.008" = "Odbcconf"
    "T1218.009" = "Regsvcs/Regasm"
    "T1218.010" = "Regsvr32"
    "T1218.011" = "Rundll32"
    "T1218.012" = "Verclsid"
    "T1218.013" = "Mavinject"
    "T1218.014" = "MMC"
    "T1218.015" = "Electron Applications"
    "T1082"     = "System Information Discovery"
    "T1614"     = "System Location Discovery"
    "T1614.001" = "System Language Discovery"
    "T1016"     = "System Network Configuration Discovery"
    "T1016.001" = "Internet Connection Discovery"
    "T1016.002" = "Wi-Fi Discovery"
    "T1049"     = "System Network Connections Discovery"
    "T1033"     = "System Owner/User Discovery"
    "T1216"     = "System Script Proxy Execution"
    "T1216.001" = "PubPrn"
    "T1216.002" = "SyncAppvPublishingServer"
    "T1007"     = "System Service Discovery"
    "T1569"     = "System Services"
    "T1569.001" = "Launchctl"
    "T1569.002" = "Service Execution"
    "T1529"     = "System Shutdown/Reboot"
    "T1124"     = "System Time Discovery"
    "T1080"     = "Taint Shared Content"
    "T1221"     = "Template Injection"
    "T1205"     = "Traffic Signaling"
    "T1205.001" = "Port Knocking"
    "T1205.002" = "Socket Filters"
    "T1537"     = "Transfer Data to Cloud Account"
    "T1127"     = "Trusted Developer Utilities Proxy Execution"
    "T1127.001" = "MSBuild"
    "T1127.002" = "ClickOnce"
    "T1199"     = "Trusted Relationship"
    "T1552"     = "Unsecured Credentials"
    "T1552.001" = "Credentials In Files"
    "T1552.002" = "Credentials in Registry"
    "T1552.003" = "Bash History"
    "T1552.004" = "Private Keys"
    "T1552.005" = "Cloud Instance Metadata API"
    "T1552.006" = "Group Policy Preferences"
    "T1552.007" = "Container API"
    "T1552.008" = "Chat Messages"
    "T1535"     = "Unused/Unsupported Cloud Regions"
    "T1550"     = "Use Alternate Authentication Material"
    "T1550.001" = "Application Access Token"
    "T1550.002" = "Pass the Hash"
    "T1550.003" = "Pass the Ticket"
    "T1550.004" = "Web Session Cookie"
    "T1204"     = "User Execution"
    "T1204.001" = "Malicious Link"
    "T1204.002" = "Malicious File"
    "T1204.003" = "Malicious Image"
    "T1078"     = "Valid Accounts"
    "T1078.001" = "Default Accounts"
    "T1078.002" = "Domain Accounts"
    "T1078.003" = "Local Accounts"
    "T1078.004" = "Cloud Accounts"
    "T1125"     = "Video Capture"
    "T1497"     = "Virtualization/Sandbox Evasion"
    "T1497.001" = "System Checks"
    "T1497.002" = "User Activity Based Checks"
    "T1497.003" = "Time Based Evasion"
    "T1600"     = "Weaken Encryption"
    "T1600.001" = "Reduce Key Space"
    "T1600.002" = "Disable Crypto Hardware"
    "T1102"     = "Web Service"
    "T1102.001" = "Dead Drop Resolver"
    "T1102.002" = "Bidirectional Communication"
    "T1102.003" = "One-Way Communication"
    "T1047"     = "Windows Management Instrumentation"
    "T1220"     = "XSL Script Processing"
    "T1626"     = "Abuse Elevation Control Mechanism"
    "T1626.001" = "Device Administrator Permissions"
    "T1517"     = "Access Notifications"
    "T1640"     = "Account Access Removal"
    "T1638"     = "Adversary-in-the-Middle"
    "T1437"     = "Application Layer Protocol"
    "T1437.001" = "Web Protocols"
    "T1661"     = "Application Versioning"
    "T1532"     = "Archive Collected Data"
    "T1429"     = "Audio Capture"
    "T1398"     = "Boot or Logon Initialization Scripts"
    "T1616"     = "Call Control"
    "T1414"     = "Clipboard Data"
    "T1623"     = "Command and Scripting Interpreter"
    "T1623.001" = "Unix Shell"
    "T1577"     = "Compromise Application Executable"
    "T1645"     = "Compromise Client Software Binary"
    "T1634"     = "Credentials from Password Store"
    "T1634.001" = "Keychain"
    "T1662"     = "Data Destruction"
    "T1471"     = "Data Encrypted for Impact"
    "T1533"     = "Data from Local System"
    "T1641"     = "Data Manipulation"
    "T1641.001" = "Transmitted Data Manipulation"
    "T1407"     = "Download New Code at Runtime"
    "T1456"     = "Drive-By Compromise"
    "T1637"     = "Dynamic Resolution"
    "T1637.001" = "Domain Generation Algorithms"
    "T1521"     = "Encrypted Channel"
    "T1521.001" = "Symmetric Cryptography"
    "T1521.002" = "Asymmetric Cryptography"
    "T1521.003" = "SSL Pinning"
    "T1642"     = "Endpoint Denial of Service"
    "T1624"     = "Event Triggered Execution"
    "T1624.001" = "Broadcast Receivers"
    "T1627"     = "Execution Guardrails"
    "T1627.001" = "Geofencing"
    "T1639"     = "Exfiltration Over Alternative Protocol"
    "T1639.001" = "Exfiltration Over Unencrypted Non-C2 Protocol"
    "T1646"     = "Exfiltration Over C2 Channel"
    "T1658"     = "Exploitation for Client Execution"
    "T1664"     = "Exploitation for Initial Access"
    "T1404"     = "Exploitation for Privilege Escalation"
    "T1428"     = "Exploitation of Remote Services"
    "T1420"     = "File and Directory Discovery"
    "T1541"     = "Foreground Persistence"
    "T1643"     = "Generate Traffic from Victim"
    "T1628"     = "Hide Artifacts"
    "T1628.001" = "Suppress Application Icon"
    "T1628.002" = "User Evasion"
    "T1628.003" = "Conceal Multimedia Files"
    "T1625"     = "Hijack Execution Flow"
    "T1625.001" = "System Runtime API Hijacking"
    "T1617"     = "Hooking"
    "T1629"     = "Impair Defenses"
    "T1629.001" = "Prevent Application Removal"
    "T1629.002" = "Device Lockout"
    "T1629.003" = "Disable or Modify Tools"
    "T1630"     = "Indicator Removal on Host"
    "T1630.001" = "Uninstall Malicious Application"
    "T1630.002" = "File Deletion"
    "T1630.003" = "Disguise Root/Jailbreak Indicators"
    "T1544"     = "Ingress Tool Transfer"
    "T1417"     = "Input Capture"
    "T1417.001" = "Keylogging"
    "T1417.002" = "GUI Input Capture"
    "T1516"     = "Input Injection"
    "T1430"     = "Location Tracking"
    "T1430.001" = "Remote Device Management Services"
    "T1430.002" = "Impersonate SS7 Nodes"
    "T1461"     = "Lockscreen Bypass"
    "T1655"     = "Masquerading"
    "T1655.001" = "Match Legitimate Name or Location"
    "T1575"     = "Native API"
    "T1464"     = "Network Denial of Service"
    "T1423"     = "Network Service Scanning"
    "T1509"     = "Non-Standard Port"
    "T1406"     = "Obfuscated Files or Information"
    "T1406.001" = "Steganography"
    "T1406.002" = "Software Packing"
    "T1644"     = "Out of Band Data"
    "T1660"     = "Phishing"
    "T1424"     = "Process Discovery"
    "T1631"     = "Process Injection"
    "T1631.001" = "Ptrace System Calls"
    "T1636"     = "Protected User Data"
    "T1636.001" = "Calendar Entries"
    "T1636.002" = "Call Log"
    "T1636.003" = "Contact List"
    "T1636.004" = "SMS Messages"
    "T1604"     = "Proxy Through Victim"
    "T1663"     = "Remote Access Software"
    "T1458"     = "Replication Through Removable Media"
    "T1603"     = "Scheduled Task/Job"
    "T1513"     = "Screen Capture"
    "T1582"     = "SMS Control"
    "T1418"     = "Software Discovery"
    "T1418.001" = "Security Software Discovery"
    "T1635"     = "Steal Application Access Token"
    "T1635.001" = "URI Hijacking"
    "T1409"     = "Stored Application Data"
    "T1632"     = "Subvert Trust Controls"
    "T1632.001" = "Code Signing Policy Modification"
    "T1474"     = "Supply Chain Compromise"
    "T1474.001" = "Compromise Software Dependencies and Development Tools"
    "T1474.002" = "Compromise Hardware Supply Chain"
    "T1474.003" = "Compromise Software Supply Chain"
    "T1426"     = "System Information Discovery"
    "T1422"     = "System Network Configuration Discovery"
    "T1422.001" = "Internet Connection Discovery"
    "T1422.002" = "Wi-Fi Discovery"
    "T1421"     = "System Network Connections Discovery"
    "T1512"     = "Video Capture"
    "T1633"     = "Virtualization/Sandbox Evasion"
    "T1633.001" = "System Checks"
    "T1481"     = "Web Service"
    "T1481.001" = "Dead Drop Resolver"
    "T1481.002" = "Bidirectional Communication"
    "T1481.003" = "One-Way Communication"
    "T0800"     = "Activate Firmware Update Mode"
    "T0830"     = "Adversary-in-the-Middle"
    "T0878"     = "Alarm Suppression"
    "T0802"     = "Automated Collection"
    "T0895"     = "Autorun Image"
    "T0803"     = "Block Command Message"
    "T0804"     = "Block Reporting Message"
    "T0805"     = "Block Serial COM"
    "T0806"     = "Brute Force I/O"
    "T0892"     = "Change Credential"
    "T0858"     = "Change Operating Mode"
    "T0807"     = "Command-Line Interface"
    "T0885"     = "Commonly Used Port"
    "T0884"     = "Connection Proxy"
    "T0879"     = "Damage to Property"
    "T0809"     = "Data Destruction"
    "T0811"     = "Data from Information Repositories"
    "T0893"     = "Data from Local System"
    "T0812"     = "Default Credentials"
    "T0813"     = "Denial of Control"
    "T0814"     = "Denial of Service"
    "T0815"     = "Denial of View"
    "T0868"     = "Detect Operating Mode"
    "T0816"     = "Device Restart/Shutdown"
    "T0817"     = "Drive-by Compromise"
    "T0871"     = "Execution through API"
    "T0819"     = "Exploit Public-Facing Application"
    "T0820"     = "Exploitation for Evasion"
    "T0890"     = "Exploitation for Privilege Escalation"
    "T0866"     = "Exploitation of Remote Services"
    "T0822"     = "External Remote Services"
    "T0823"     = "Graphical User Interface"
    "T0891"     = "Hardcoded Credentials"
    "T0874"     = "Hooking"
    "T0877"     = "I/O Image"
    "T0872"     = "Indicator Removal on Host"
    "T0883"     = "Internet Accessible Device"
    "T0867"     = "Lateral Tool Transfer"
    "T0826"     = "Loss of Availability"
    "T0827"     = "Loss of Control"
    "T0828"     = "Loss of Productivity and Revenue"
    "T0837"     = "Loss of Protection"
    "T0880"     = "Loss of Safety"
    "T0829"     = "Loss of View"
    "T0835"     = "Manipulate I/O Image"
    "T0831"     = "Manipulation of Control"
    "T0832"     = "Manipulation of View"
    "T0849"     = "Masquerading"
    "T0838"     = "Modify Alarm Settings"
    "T0821"     = "Modify Controller Tasking"
    "T0836"     = "Modify Parameter"
    "T0889"     = "Modify Program"
    "T0839"     = "Module Firmware"
    "T0801"     = "Monitor Process State"
    "T0834"     = "Native API"
    "T0840"     = "Network Connection Enumeration"
    "T0842"     = "Network Sniffing"
    "T0861"     = "Point & Tag Identification"
    "T0843"     = "Program Download"
    "T0845"     = "Program Upload"
    "T0873"     = "Project File Infection"
    "T0886"     = "Remote Services"
    "T0846"     = "Remote System Discovery"
    "T0888"     = "Remote System Information Discovery"
    "T0847"     = "Replication Through Removable Media"
    "T0848"     = "Rogue Master"
    "T0851"     = "Rootkit"
    "T0852"     = "Screen Capture"
    "T0853"     = "Scripting"
    "T0881"     = "Service Stop"
    "T0865"     = "Spearphishing Attachment"
    "T0856"     = "Spoof Reporting Message"
    "T0869"     = "Standard Application Layer Protocol"
    "T0862"     = "Supply Chain Compromise"
    "T0894"     = "System Binary Proxy Execution"
    "T0857"     = "System Firmware"
    "T0882"     = "Theft of Operational Information"
    "T0864"     = "Transient Cyber Asset"
    "T0855"     = "Unauthorized Command Message"
    "T0863"     = "User Execution"
    "T0859"     = "Valid Accounts"
    "T0860"     = "Wireless Compromise"
    "T0887"     = "Wireless Sniffing"
}

$techniqueDescriptionHash = @{
    T1548 = "Adversaries may circumvent mechanisms designed to control elevate privileges to gain higher-level permissions. Most modern systems contain native elevation control mechanisms that are intended to limit privileges that a user can perform on a machine. Authorization has to be granted to specific users in order to perform tasks that can be considered of higher risk. An adversary can perform several methods to take advantage of built-in control mechanisms in order to escalate privileges on a system."
    T1134 = "Adversaries may modify access tokens to operate under a different user or system security context to perform actions and bypass access controls. Windows uses access tokens to determine the ownership of a running process. A user can manipulate access tokens to make a running process appear as though it is the child of a different process or belongs to someone other than the user that started the process. When this occurs, the process also takes on the security context associated with the new token."
    T1531 = "Adversaries may interrupt availability of system and network resources by inhibiting access to accounts utilized by legitimate users. Accounts may be deleted, locked, or manipulated (ex= changed credentials) to remove access to accounts. Adversaries may also subsequently log off and/or perform a System Shutdown/Reboot to set malicious changes into place."
    T1087 = "Adversaries may attempt to get a listing of valid accounts, usernames, or email addresses on a system or within a compromised environment. This information can help adversaries determine which accounts exist, which can aid in follow-on behavior such as brute-forcing, spear-phishing attacks, or account takeovers (e.g., Valid Accounts)."
    T1098 = "Adversaries may manipulate accounts to maintain and/or elevate access to victim systems. Account manipulation may consist of any action that preserves or modifies adversary access to a compromised account, such as modifying credentials or permission groups. These actions could also include account activity designed to subvert security policies, such as performing iterative password updates to bypass password duration policies and preserve the life of compromised credentials."
    T1650 = "Adversaries may purchase or otherwise acquire an existing access to a target system or network. A variety of online services and initial access broker networks are available to sell access to previously compromised systems. In some cases, adversary groups may form partnerships to share compromised systems with each other."
    T1583 = "Adversaries may buy, lease, rent, or obtain infrastructure that can be used during targeting. A wide variety of infrastructure exists for hosting and orchestrating adversary operations. Infrastructure solutions include physical or cloud servers, domains, and third-party web services. Some infrastructure providers offer free trial periods, enabling infrastructure acquisition at limited to no cost. Additionally, botnets are available for rent or purchase."
    T1595 = "Adversaries may execute active reconnaissance scans to gather information that can be used during targeting. Active scans are those where the adversary probes victim infrastructure via network traffic, as opposed to other forms of reconnaissance that do not involve direct interaction."
    T1557 = "Adversaries may attempt to position themselves between two or more networked devices using an adversary-in-the-middle (AiTM) technique to support follow-on behaviors such as Network Sniffing, Transmitted Data Manipulation, or replay attacks (Exploitation for Credential Access). By abusing features of common networking protocols that can determine the flow of network traffic (e.g. ARP, DNS, LLMNR, etc.), adversaries may force a device to communicate through an adversary controlled system so they can collect information or perform additional actions."
    T1071 = "Adversaries may communicate using OSI application layer protocols to avoid detection/network filtering by blending in with existing traffic. Commands to the remote system, and often the results of those commands, will be embedded within the protocol traffic between the client and server."
    T1010 = "Adversaries may attempt to get a listing of open application windows. Window listings could convey information about how the system is used. For example, information about application windows could be used identify potential data to collect as well as identifying security tooling (Security Software Discovery) to evade."
    T1560 = "An adversary may compress and/or encrypt data that is collected prior to exfiltration. Compressing the data can help to obfuscate the collected data and minimize the amount of data sent over the network. Encryption can be used to hide information that is being exfiltrated from detection or make exfiltration less conspicuous upon inspection by a defender."
    T1123 = "An adversary can leverage a computer's peripheral devices (e.g., microphones and webcams) or applications (e.g., voice and video call services) to capture audio recordings for the purpose of listening into sensitive conversations to gather information."
    T1119 = "Once established within a system or network, an adversary may use automated techniques for collecting internal data. Methods for performing this technique could include use of a Command and Scripting Interpreter to search for and copy information fitting set criteria such as file type, location, or name at specific time intervals."
    T1020 = "Adversaries may exfiltrate data, such as sensitive documents, through the use of automated processing after being gathered during Collection."
    T1197 = "Adversaries may abuse BITS jobs to persistently execute code and perform various background tasks. Windows Background Intelligent Transfer Service (BITS) is a low-bandwidth, asynchronous file transfer mechanism exposed through Component Object Model (COM). BITS is commonly used by updaters, messengers, and other applications preferred to operate in the background (using available idle bandwidth) without interrupting other networked applications. File transfer tasks are implemented as BITS jobs, which contain a queue of one or more file operations."
    T1547 = "Adversaries may configure system settings to automatically execute a program during system boot or logon to maintain persistence or gain higher-level privileges on compromised systems. Operating systems may have mechanisms for automatically running a program on system boot or account logon. These mechanisms may include automatically executing programs that are placed in specially designated directories or are referenced by repositories that store configuration information, such as the Windows Registry. An adversary may achieve the same goal by modifying or extending features of the kernel."
    T1037 = "Adversaries may use scripts automatically executed at boot or logon initialization to establish persistence. Initialization scripts can be used to perform administrative functions, which may often execute other programs or send information to an internal logging server. These scripts can vary based on operating system and whether applied locally or remotely."
    T1176 = "Adversaries may abuse Internet browser extensions to establish persistent access to victim systems. Browser extensions or plugins are small programs that can add functionality and customize aspects of Internet browsers. They can be installed directly or through a browser's app store and generally have access and permissions to everything that the browser can access."
    T1217 = "Adversaries may enumerate information about browsers to learn more about compromised environments. Data saved by browsers (such as bookmarks, accounts, and browsing history) may reveal a variety of personal information about users (e.g., banking sites, relationships/interests, social media, etc.) as well as details about internal network resources such as servers, tools/dashboards, or other related infrastructure."
    T1185 = "Adversaries may take advantage of security vulnerabilities and inherent functionality in browser software to change content, modify user-behaviors, and intercept information as part of various browser session hijacking techniques."
    T1110 = "Adversaries may use brute force techniques to gain access to accounts when passwords are unknown or when password hashes are obtained. Without knowledge of the password for an account or set of accounts, an adversary may systematically guess the password using a repetitive or iterative mechanism. Brute forcing passwords can take place via interaction with a service that will check the validity of those credentials or offline against previously acquired credential data, such as password hashes."
    T1612 = "Adversaries may build a container image directly on a host to bypass defenses that monitor for the retrieval of malicious images from a public registry. A remote build request may be sent to the Docker API that includes a Dockerfile that pulls a vanilla base image, such as alpine, from a public or local registry and then builds a custom image upon it."
    T1115 = "Adversaries may collect data stored in the clipboard from users copying information within or between applications."
    T1651 = "Adversaries may abuse cloud management services to execute commands within virtual machines. Resources such as AWS Systems Manager, Azure RunCommand, and Runbooks allow users to remotely run scripts in virtual machines by leveraging installed virtual machine agents."
    T1580 = "An adversary may attempt to discover infrastructure and resources that are available within an infrastructure-as-a-service (IaaS) environment. This includes compute service resources such as instances, virtual machines, and snapshots as well as resources of other services including the storage and database services."
    T1538 = "An adversary may use a cloud service dashboard GUI with stolen credentials to gain useful information from an operational cloud environment, such as specific services, resources, and features. For example, the GCP Command Center can be used to view all assets, findings of potential security risks, and to run additional queries, such as finding public IP addresses and open ports."
    T1526 = "An adversary may attempt to enumerate the cloud services running on a system after gaining access. These methods can differ from platform-as-a-service (PaaS), to infrastructure-as-a-service (IaaS), or software-as-a-service (SaaS). Many services exist throughout the various cloud providers and can include Continuous Integration and Continuous Delivery (CI/CD), Lambda Functions, Entra ID, etc. They may also include security services, such as AWS GuardDuty and Microsoft Defender for Cloud, and logging services, such as AWS CloudTrail and Google Cloud Audit Logs."
    T1619 = "Adversaries may enumerate objects in cloud storage infrastructure. Adversaries may use this information during automated discovery to shape follow-on behaviors, including requesting all or specific objects from cloud storage.  Similar to File and Directory Discovery on a local host, after identifying available storage services (i.e. Cloud Infrastructure Discovery) adversaries may access the contents/objects stored in cloud infrastructure."
    T1059 = "Adversaries may abuse command and script interpreters to execute commands, scripts, or binaries. These interfaces and languages provide ways of interacting with computer systems and are a common feature across many different platforms. Most systems come with some built-in command-line interface and scripting capabilities, for example, macOS and Linux distributions include some flavor of Unix Shell while Windows installations include the Windows Command Shell and PowerShell."
    T1092 = "Adversaries can perform command and control between compromised hosts on potentially disconnected networks using removable media to transfer commands from system to system. Both systems would need to be compromised, with the likelihood that an Internet-connected system was compromised first and the second through lateral movement by Replication Through Removable Media. Commands and files would be relayed from the disconnected system to the Internet-connected system to which the adversary has direct access."
    T1586 = "Adversaries may compromise accounts with services that can be used during targeting. For operations incorporating social engineering, the utilization of an online persona may be important. Rather than creating and cultivating accounts (i.e. Establish Accounts), adversaries may compromise existing accounts. Utilizing an existing persona may engender a level of trust in a potential victim if they have a relationship, or knowledge of, the compromised persona."
    T1554 = "Adversaries may modify host software binaries to establish persistent access to systems. Software binaries/executables provide a wide range of system commands or services, programs, and libraries. Common software binaries are SSH clients, FTP clients, email clients, web browsers, and many other user or server applications."
    T1584 = "Adversaries may compromise third-party infrastructure that can be used during targeting. Infrastructure solutions include physical or cloud servers, domains, network devices, and third-party web and DNS services. Instead of buying, leasing, or renting infrastructure an adversary may compromise infrastructure and use it during other phases of the adversary lifecycle. Additionally, adversaries may compromise numerous machines to form a botnet they can leverage."
    T1609 = "Adversaries may abuse a container administration service to execute commands within a container. A container administration service such as the Docker daemon, the Kubernetes API server, or the kubelet may allow remote management of containers within an environment."
    T1613 = "Adversaries may attempt to discover containers and other resources that are available within a containers environment. Other resources may include images, deployments, pods, nodes, and other information such as the status of a cluster."
    T1659 = "Adversaries may gain access and continuously communicate with victims by injecting malicious content into systems through online network traffic. Rather than luring victims to malicious payloads hosted on a compromised website (i.e., Drive-by Target followed by Drive-by Compromise), adversaries may initially access victims through compromised data-transfer channels where they can manipulate traffic and/or inject their own content. These compromised online network channels may also be used to deliver additional payloads (i.e., Ingress Tool Transfer) and other data to already compromised systems."
    T1136 = "Adversaries may create an account to maintain access to victim systems. With a sufficient level of access, creating such accounts may be used to establish secondary credentialed access that do not require persistent remote access tools to be deployed on the system."
    T1543 = "Adversaries may create or modify system-level processes to repeatedly execute malicious payloads as part of persistence. When operating systems boot up, they can start processes that perform background system functions. On Windows and Linux, these system processes are referred to as services. On macOS, launchd processes known as Launch Daemon and Launch Agent are run to finish system initialization and load user specific parameters."
    T1555 = "Adversaries may search for common password storage locations to obtain user credentials. Passwords are stored in several places on a system, depending on the operating system or application holding the credentials. There are also specific applications and services that store passwords to make them easier for users to manage and maintain, such as password managers and cloud secrets vaults. Once credentials are obtained, they can be used to perform lateral movement and access restricted information."
    T1485 = "Adversaries may destroy data and files on specific systems or in large numbers on a network to interrupt availability to systems, services, and network resources. Data destruction is likely to render stored data irrecoverable by forensic techniques through overwriting files or data on local and remote drives. Common operating system file deletion commands such as del and rm often only remove pointers to files without wiping the contents of the files themselves, making the files recoverable by proper forensic methodology. This behavior is distinct from Disk Content Wipe and Disk Structure Wipe because individual files are destroyed rather than sections of a storage disk or the disk's logical structure."
    T1132 = "Adversaries may encode data to make the content of command and control traffic more difficult to detect. Command and control (C2) information can be encoded using a standard data encoding system. Use of data encoding may adhere to existing protocol specifications and includes use of ASCII, Unicode, Base64, MIME, or other binary-to-text and character encoding systems.  Some data encoding systems may also result in data compression, such as gzip."
    T1486 = "Adversaries may encrypt data on target systems or on large numbers of systems in a network to interrupt availability to system and network resources. They can attempt to render stored data inaccessible by encrypting files or data on local and remote drives and withholding access to a decryption key. This may be done in order to extract monetary compensation from a victim in exchange for decryption or a decryption key (ransomware) or to render data permanently inaccessible in cases where the key is not saved or transmitted."
    T1530 = "Adversaries may access data from cloud storage."
    T1602 = "Adversaries may collect data related to managed devices from configuration repositories. Configuration repositories are used by management systems in order to configure, manage, and control data on remote systems. Configuration repositories may also facilitate remote access and administration of devices."
    T1213 = "Adversaries may leverage information repositories to mine valuable information. Information repositories are tools that allow for storage of information, typically to facilitate collaboration or information sharing between users, and can store a wide variety of data that may aid adversaries in further objectives, such as Credential Access, Lateral Movement, or Defense Evasion, or direct access to the target information. Adversaries may also abuse external sharing features to share sensitive documents with recipients outside of the organization (i.e., Transfer Data to Cloud Account)."
    T1005 = "Adversaries may search local system sources, such as file systems and configuration files or local databases, to find files of interest and sensitive data prior to Exfiltration."
    T1039 = "Adversaries may search network shares on computers they have compromised to find files of interest. Sensitive data can be collected from remote systems via shared network drives (host shared directory, network file server, etc.) that are accessible from the current system prior to Exfiltration. Interactive command shells may be in use, and common functionality within cmd may be used to gather information."
    T1025 = "Adversaries may search connected removable media on computers they have compromised to find files of interest. Sensitive data can be collected from any removable media (optical disk drive, USB memory, etc.) connected to the compromised system prior to Exfiltration. Interactive command shells may be in use, and common functionality within cmd may be used to gather information."
    T1565 = "Adversaries may insert, delete, or manipulate data in order to influence external outcomes or hide activity, thus threatening the integrity of the data. By manipulating data, adversaries may attempt to affect a business process, organizational understanding, or decision making."
    T1001 = "Adversaries may obfuscate command and control traffic to make it more difficult to detect. Command and control (C2) communications are hidden (but not necessarily encrypted) in an attempt to make the content more difficult to discover or decipher and to make the communication less conspicuous and hide commands from being seen. This encompasses many methods, such as adding junk data to protocol traffic, using steganography, or impersonating legitimate protocols."
    T1074 = "Adversaries may stage collected data in a central location or directory prior to Exfiltration. Data may be kept in separate files or combined into one file through techniques such as Archive Collected Data. Interactive command shells may be used, and common functionality within cmd and bash may be used to copy data into a staging location."
    T1030 = "An adversary may exfiltrate data in fixed size chunks instead of whole files or limit packet sizes below certain thresholds. This approach may be used to avoid triggering network data transfer threshold alerts."
    T1622 = "Adversaries may employ various means to detect and avoid debuggers. Debuggers are typically used by defenders to trace and/or analyze the execution of potential malware payloads."
    T1491 = "Adversaries may modify visual content available internally or externally to an enterprise network, thus affecting the integrity of the original content. Reasons for Defacement include delivering messaging, intimidation, or claiming (possibly false) credit for an intrusion. Disturbing or offensive images may be used as a part of Defacement in order to cause user discomfort, or to pressure compliance with accompanying messages."
    T1140 = "Adversaries may use Obfuscated Files or Information to hide artifacts of an intrusion from analysis. They may require separate mechanisms to decode or deobfuscate that information depending on how they intend to use it. Methods for doing that include built-in functionality of malware or by using utilities present on the system."
    T1610 = "Adversaries may deploy a container into an environment to facilitate execution or evade defenses. In some cases, adversaries may deploy a new container to execute processes associated with a particular image or deployment, such as processes that execute or download malware. In others, an adversary may deploy a new container configured without network rules, user limitations, etc. to bypass existing defenses within the environment. In Kubernetes environments, an adversary may attempt to deploy a privileged or vulnerable container into a specific node in order to Escape to Host and access other containers running on the node."
    T1587 = "Adversaries may build capabilities that can be used during targeting. Rather than purchasing, freely downloading, or stealing capabilities, adversaries may develop their own capabilities in-house. This is the process of identifying development requirements and building solutions such as malware, exploits, and self-signed certificates. Adversaries may develop capabilities to support their operations throughout numerous phases of the adversary lifecycle."
    T1652 = "Adversaries may attempt to enumerate local device drivers on a victim host. Information about device drivers may highlight various insights that shape follow-on behaviors, such as the function/purpose of the host, present security tools (i.e. Security Software Discovery) or other defenses (e.g., Virtualization/Sandbox Evasion), as well as potential exploitable vulnerabilities (e.g., Exploitation for Privilege Escalation)."
    T1006 = "Adversaries may directly access a volume to bypass file access controls and file system monitoring. Windows allows programs to have direct access to logical volumes. Programs with direct access may read and write files directly from the drive by analyzing file system data structures. This technique may bypass Windows file access controls as well as file system monitoring tools."
    T1561 = "Adversaries may wipe or corrupt raw disk data on specific systems or in large numbers in a network to interrupt availability to system and network resources. With direct write access to a disk, adversaries may attempt to overwrite portions of disk data. Adversaries may opt to wipe arbitrary portions of disk data and/or wipe disk structures like the master boot record (MBR). A complete wipe of all disk sectors may be attempted."
    T1484 = "Adversaries may modify the configuration settings of a domain or identity tenant to evade defenses and/or escalate privileges in centrally managed environments. Such services provide a centralized means of managing identity resources such as devices and accounts, and often include configuration settings that may apply between domains or tenants such as trust relationships, identity syncing, or identity federation."
    T1482 = "Adversaries may attempt to gather information on domain trust relationships that may be used to identify lateral movement opportunities in Windows multi-domain/forest environments. Domain trusts provide a mechanism for a domain to allow access to resources based on the authentication procedures of another domain. Domain trusts allow the users of the trusted domain to access resources in the trusting domain. The information discovered may help the adversary conduct SID-History Injection, Pass the Ticket, and Kerberoasting. Domain trusts can be enumerated using the DSEnumerateDomainTrusts() Win32 API call, .NET methods, and LDAP. The Windows utility Nltest is known to be used by adversaries to enumerate domain trusts."
    T1189 = "Adversaries may gain access to a system through a user visiting a website over the normal course of browsing. With this technique, the user's web browser is typically targeted for exploitation, but adversaries may also use compromised websites for non-exploitation behavior such as acquiring Application Access Token."
    T1568 = "Adversaries may dynamically establish connections to command and control infrastructure to evade common detections and remediations. This may be achieved by using malware that shares a common algorithm with the infrastructure the adversary uses to receive the malware's communications. These calculations can be used to dynamically adjust parameters such as the domain name, IP address, or port number the malware uses for command and control."
    T1114 = "Adversaries may target user email to collect sensitive information. Emails may contain sensitive data, including trade secrets or personal information, that can prove valuable to adversaries. Emails may also contain details of ongoing incident response operations, which may allow adversaries to adjust their techniques in order to maintain persistence or evade defenses. Adversaries can collect or forward email from mail servers or clients."
    T1573 = "Adversaries may employ an encryption algorithm to conceal command and control traffic rather than relying on any inherent protections provided by a communication protocol. Despite the use of a secure algorithm, these implementations may be vulnerable to reverse engineering if secret keys are encoded and/or generated within malware samples/configuration files."
    T1499 = "Adversaries may perform Endpoint Denial of Service (DoS) attacks to degrade or block the availability of services to users. Endpoint DoS can be performed by exhausting the system resources those services are hosted on or exploiting the system to cause a persistent crash condition. Example services include websites, email services, DNS, and web-based applications. Adversaries have been observed conducting DoS attacks for political purposes and to support other malicious activities, including distraction, hacktivism, and extortion."
    T1611 = "Adversaries may break out of a container to gain access to the underlying host. This can allow an adversary access to other containerized resources from the host level or to the host itself. In principle, containerized resources should provide a clear separation of application functionality and be isolated from the host environment."
    T1585 = "Adversaries may create and cultivate accounts with services that can be used during targeting. Adversaries can create accounts that can be used to build a persona to further operations. Persona development consists of the development of public information, presence, history and appropriate affiliations. This development could be applied to social media, website, or other publicly available information that could be referenced and scrutinized for legitimacy over the course of an operation using that persona or identity."
    T1546 = "Adversaries may establish persistence and/or elevate privileges using system mechanisms that trigger execution based on specific events. Various operating systems have means to monitor and subscribe to events such as logons or other user activity such as running specific applications/binaries. Cloud environments may also support various functions and services that monitor and can be invoked in response to specific cloud events."
    T1480 = "Adversaries may use execution guardrails to constrain execution or actions based on adversary supplied and environment specific conditions that are expected to be present on the target. Guardrails ensure that a payload only executes against an intended target and reduces collateral damage from an adversary’s campaign. Values an adversary can provide about a target system or environment to use as guardrails may include specific network share names, attached physical devices, files, joined Active Directory (AD) domains, and local/external IP addresses."
    T1048 = "Adversaries may steal data by exfiltrating it over a different protocol than that of the existing command and control channel. The data may also be sent to an alternate network location from the main command and control server."
    T1041 = "Adversaries may steal data by exfiltrating it over an existing command and control channel. Stolen data is encoded into the normal communications channel using the same protocol as command and control communications."
    T1011 = "Adversaries may attempt to exfiltrate data over a different network medium than the command and control channel. If the command and control network is a wired Internet connection, the exfiltration may occur, for example, over a WiFi connection, modem, cellular data connection, Bluetooth, or another radio frequency (RF) channel."
    T1052 = "Adversaries may attempt to exfiltrate data via a physical medium, such as a removable drive. In certain circumstances, such as an air-gapped network compromise, exfiltration could occur via a physical medium or device introduced by a user. Such media could be an external hard drive, USB drive, cellular phone, MP3 player, or other removable storage and processing device. The physical medium or device could be used as the final exfiltration point or to hop between otherwise disconnected systems."
    T1567 = "Adversaries may use an existing, legitimate external Web service to exfiltrate data rather than their primary command and control channel. Popular Web services acting as an exfiltration mechanism may give a significant amount of cover due to the likelihood that hosts within a network are already communicating with them prior to compromise. Firewall rules may also already exist to permit traffic to these services."
    T1190 = "Adversaries may attempt to exploit a weakness in an Internet-facing host or system to initially access a network. The weakness in the system can be a software bug, a temporary glitch, or a misconfiguration."
    T1203 = "Adversaries may exploit software vulnerabilities in client applications to execute code. Vulnerabilities can exist in software due to unsecure coding practices that can lead to unanticipated behavior. Adversaries can take advantage of certain vulnerabilities through targeted exploitation for the purpose of arbitrary code execution. Oftentimes the most valuable exploits to an offensive toolkit are those that can be used to obtain code execution on a remote system because they can be used to gain access to that system. Users will expect to see files related to the applications they commonly used to do work, so they are a useful target for exploit research and development because of their high utility."
    T1212 = "Adversaries may exploit software vulnerabilities in an attempt to collect credentials. Exploitation of a software vulnerability occurs when an adversary takes advantage of a programming error in a program, service, or within the operating system software or kernel itself to execute adversary-controlled code."
    T1211 = "Adversaries may exploit a system or application vulnerability to bypass security features. Exploitation of a vulnerability occurs when an adversary takes advantage of a programming error in a program, service, or within the operating system software or kernel itself to execute adversary-controlled code. Vulnerabilities may exist in defensive security software that can be used to disable or circumvent them."
    T1068 = "Adversaries may exploit software vulnerabilities in an attempt to elevate privileges. Exploitation of a software vulnerability occurs when an adversary takes advantage of a programming error in a program, service, or within the operating system software or kernel itself to execute adversary-controlled code. Security constructs such as permission levels will often hinder access to information and use of certain techniques, so adversaries will likely need to perform privilege escalation to include use of software exploitation to circumvent those restrictions."
    T1210 = "Adversaries may exploit remote services to gain unauthorized access to internal systems once inside of a network. Exploitation of a software vulnerability occurs when an adversary takes advantage of a programming error in a program, service, or within the operating system software or kernel itself to execute adversary-controlled code. A common goal for post-compromise exploitation of remote services is for lateral movement to enable access to a remote system."
    T1133 = "Adversaries may leverage external-facing remote services to initially access and/or persist within a network. Remote services such as VPNs, Citrix, and other access mechanisms allow users to connect to internal enterprise network resources from external locations. There are often remote service gateways that manage connections and credential authentication for these services. Services such as Windows Remote Management and VNC can also be used externally."
    T1008 = "Adversaries may use fallback or alternate communication channels if the primary channel is compromised or inaccessible in order to maintain reliable command and control and to avoid data transfer thresholds."
    T1083 = "Adversaries may enumerate files and directories or may search in specific locations of a host or network share for certain information within a file system. Adversaries may use the information from File and Directory Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1222 = "Adversaries may modify file or directory permissions/attributes to evade access control lists (ACLs) and access protected files. File and directory permissions are commonly managed by ACLs configured by the file or directory owner, or users with the appropriate permissions. File and directory ACL implementations vary by platform, but generally explicitly designate which users or groups can perform which actions (read, write, execute, etc.)."
    T1657 = "Adversaries may steal monetary resources from targets through extortion, social engineering, technical theft, or other methods aimed at their own financial gain at the expense of the availability of these resources for victims. Financial theft is the ultimate objective of several popular campaign types including extortion by ransomware, business email compromise (BEC) and fraud, pig butchering, bank hacking, and exploiting cryptocurrency networks."
    T1495 = "Adversaries may overwrite or corrupt the flash memory contents of system BIOS or other firmware in devices attached to a system in order to render them inoperable or unable to boot, thus denying the availability to use the devices and/or the system. Firmware is software that is loaded and executed from non-volatile memory on hardware devices in order to initialize and manage device functionality. These devices may include the motherboard, hard drive, or video cards."
    T1187 = "Adversaries may gather credential material by invoking or forcing a user to automatically provide authentication information through a mechanism in which they can intercept."
    T1606 = "Adversaries may forge credential materials that can be used to gain access to web applications or Internet services. Web applications and services (hosted in cloud SaaS environments or on-premise servers) often use session cookies, tokens, or other materials to authenticate and authorize user access."
    T1592 = "Adversaries may gather information about the victim's hosts that can be used during targeting. Information about hosts may include a variety of details, including administrative data (ex= name, assigned IP, functionality, etc.) as well as specifics regarding its configuration (ex= operating system, language, etc.)."
    T1589 = "Adversaries may gather information about the victim's identity that can be used during targeting. Information about identities may include a variety of details, including personal data (ex= employee names, email addresses, security question responses, etc.) as well as sensitive details such as credentials or multi-factor authentication (MFA) configurations."
    T1590 = "Adversaries may gather information about the victim's networks that can be used during targeting. Information about networks may include a variety of details, including administrative data (ex= IP ranges, domain names, etc.) as well as specifics regarding its topology and operations."
    T1591 = "Adversaries may gather information about the victim's organization that can be used during targeting. Information about an organization may include a variety of details, including the names of divisions/departments, specifics of business operations, as well as the roles and responsibilities of key employees."
    T1615 = "Adversaries may gather information on Group Policy settings to identify paths for privilege escalation, security measures applied within a domain, and to discover patterns in domain objects that can be manipulated or used to blend in the environment. Group Policy allows for centralized management of user and computer settings in Active Directory (AD). Group policy objects (GPOs) are containers for group policy settings made up of files stored within a predictable network path <DOMAIN>SYSVOL<DOMAIN>Policies."
    T1200 = "Adversaries may introduce computer accessories, networking hardware, or other computing devices into a system or network that can be used as a vector to gain access. Rather than just connecting and distributing payloads via removable storage (i.e. Replication Through Removable Media), more robust hardware additions can be used to introduce new functionalities and/or features into a system that can then be abused."
    T1564 = "Adversaries may attempt to hide artifacts associated with their behaviors to evade detection. Operating systems may have features to hide various artifacts, such as important system files and administrative task execution, to avoid disrupting user work environments and prevent users from changing files or features on the system. Adversaries may abuse these features to hide artifacts such as files, directories, user accounts, or other system activity to evade detection."
    T1665 = "Adversaries may manipulate network traffic in order to hide and evade detection of their C2 infrastructure. This can be accomplished in various ways including by identifying and filtering traffic from defensive tools, masking malicious domains to obfuscate the true destination from both automated scanning tools and security researchers, and otherwise hiding malicious artifacts to delay discovery and prolong the effectiveness of adversary infrastructure that could otherwise be identified, blocked, or taken down entirely."
    T1574 = "Adversaries may execute their own malicious payloads by hijacking the way operating systems run programs. Hijacking execution flow can be for the purposes of persistence, since this hijacked execution may reoccur over time. Adversaries may also use these mechanisms to elevate privileges or evade defenses, such as application control or other restrictions on execution."
    T1562 = "Adversaries may maliciously modify components of a victim environment in order to hinder or disable defensive mechanisms. This not only involves impairing preventative defenses, such as firewalls and anti-virus, but also detection capabilities that defenders can use to audit activity and identify malicious behavior. This may also span both native defenses as well as supplemental capabilities installed by users and administrators."
    T1656 = "Adversaries may impersonate a trusted person or organization in order to persuade and trick a target into performing some action on their behalf. For example, adversaries may communicate with victims (via Phishing for Information, Phishing, or Internal Spearphishing) while impersonating a known sender such as an executive, colleague, or third-party vendor. Established trust can then be leveraged to accomplish an adversary’s ultimate goals, possibly against multiple victims."
    T1525 = "Adversaries may implant cloud or container images with malicious code to establish persistence after gaining access to an environment. Amazon Web Services (AWS) Amazon Machine Images (AMIs), Google Cloud Platform (GCP) Images, and Azure Images as well as popular container runtimes such as Docker can be implanted or backdoored. Unlike Upload Malware, this technique focuses on adversaries implanting an image in a registry within a victim’s environment. Depending on how the infrastructure is provisioned, this could provide persistent access if the infrastructure provisioning tool is instructed to always use the latest image."
    T1070 = "Adversaries may delete or modify artifacts generated within systems to remove evidence of their presence or hinder defenses. Various artifacts may be created by an adversary or something that can be attributed to an adversary’s actions. Typically these artifacts are used as defensive indicators related to monitored events, such as strings from downloaded files, logs that are generated from user actions, and other data analyzed by defenders. Location, format, and type of artifact (such as command or login history) are often specific to each platform."
    T1202 = "Adversaries may abuse utilities that allow for command execution to bypass security restrictions that limit the use of command-line interpreters. Various Windows utilities may be used to execute commands, possibly without invoking cmd. For example, Forfiles, the Program Compatibility Assistant (pcalua.exe), components of the Windows Subsystem for Linux (WSL), Scriptrunner.exe, as well as other utilities may invoke the execution of programs and commands from a Command and Scripting Interpreter, Run window, or via scripts."
    T1105 = "Adversaries may transfer tools or other files from an external system into a compromised environment. Tools or files may be copied from an external adversary-controlled system to the victim network through the command and control channel or through alternate protocols such as ftp. Once present, adversaries may also transfer/spread tools between victim devices within a compromised environment (i.e. Lateral Tool Transfer)."
    T1490 = "Adversaries may delete or remove built-in data and turn off services designed to aid in the recovery of a corrupted system to prevent recovery. This may deny access to available backups and recovery options."
    T1056 = "Adversaries may use methods of capturing user input to obtain credentials or collect information. During normal system usage, users often provide credentials to various different locations, such as login pages/portals or system dialog boxes. Input capture mechanisms may be transparent to the user (e.g. Credential API Hooking) or rely on deceiving the user into providing input into what they believe to be a genuine service (e.g. Web Portal Capture)."
    T1559 = "Adversaries may abuse inter-process communication (IPC) mechanisms for local code or command execution. IPC is typically used by processes to share data, communicate with each other, or synchronize execution. IPC is also commonly used to avoid situations such as deadlocks, which occurs when processes are stuck in a cyclic waiting pattern."
    T1534 = "After they already have access to accounts or systems within the environment, adversaries may use internal spearphishing to gain access to additional information or compromise other users within the same organization. Internal spearphishing is multi-staged campaign where a legitimate account is initially compromised either by controlling the user's device or by compromising the account credentials of the user. Adversaries may then attempt to take advantage of the trusted internal account to increase the likelihood of tricking more victims into falling for phish attempts, often incorporating Impersonation."
    T1570 = "Adversaries may transfer tools or other files between systems in a compromised environment. Once brought into the victim environment (i.e., Ingress Tool Transfer) files may then be copied from one system to another to stage adversary tools or other files over the course of an operation."
    T1654 = "Adversaries may enumerate system and service logs to find useful data. These logs may highlight various types of valuable insights for an adversary, such as user authentication records (Account Discovery), security or vulnerable software (Software Discovery), or hosts within a compromised network (Remote System Discovery)."
    T1036 = "Adversaries may attempt to manipulate features of their artifacts to make them appear legitimate or benign to users and/or security tools. Masquerading occurs when the name or location of an object, legitimate or malicious, is manipulated or abused for the sake of evading defenses and observation. This may include manipulating file metadata, tricking users into misidentifying the file type, and giving legitimate task or service names."
    T1556 = "Adversaries may modify authentication mechanisms and processes to access user credentials or enable otherwise unwarranted access to accounts. The authentication process is handled by mechanisms, such as the Local Security Authentication Server (LSASS) process and the Security Accounts Manager (SAM) on Windows, pluggable authentication modules (PAM) on Unix-based systems, and authorization plugins on MacOS systems, responsible for gathering, storing, and validating credentials. By modifying an authentication process, an adversary may be able to authenticate to a service or system without using Valid Accounts."
    T1578 = "An adversary may attempt to modify a cloud account's compute service infrastructure to evade defenses. A modification to the compute service infrastructure can include the creation, deletion, or modification of one or more components such as compute instances, virtual machines, and snapshots."
    T1666 = "Adversaries may attempt to modify hierarchical structures in infrastructure-as-a-service (IaaS) environments in order to evade defenses."
    T1112 = "Adversaries may interact with the Windows Registry to hide configuration information within Registry keys, remove information as part of cleaning up, or as part of other techniques to aid in persistence and execution."
    T1601 = "Adversaries may make changes to the operating system of embedded network devices to weaken defenses and provide new capabilities for themselves.  On such devices, the operating systems are typically monolithic and most of the device functionality and capabilities are contained within a single file."
    T1111 = "Adversaries may target multi-factor authentication (MFA) mechanisms, (i.e., smart cards, token generators, etc.) to gain access to credentials that can be used to access systems, services, and network resources. Use of MFA is recommended and provides a higher level of security than usernames and passwords alone, but organizations should be aware of techniques that could be used to intercept and bypass these security mechanisms."
    T1621 = "Adversaries may attempt to bypass multi-factor authentication (MFA) mechanisms and gain access to accounts by generating MFA requests sent to users."
    T1104 = "Adversaries may create multiple stages for command and control that are employed under different conditions or for certain functions. Use of multiple stages may obfuscate the command and control channel to make detection more difficult."
    T1106 = "Adversaries may interact with the native OS application programming interface (API) to execute behaviors. Native APIs provide a controlled means of calling low-level OS services within the kernel, such as those involving hardware/devices, memory, and processes. These native APIs are leveraged by the OS during system boot (when other system components are not yet initialized) as well as carrying out tasks and requests during routine operations."
    T1599 = "Adversaries may bridge network boundaries by compromising perimeter network devices or internal devices responsible for network segmentation. Breaching these devices may enable an adversary to bypass restrictions on traffic routing that otherwise separate trusted and untrusted networks."
    T1498 = "Adversaries may perform Network Denial of Service (DoS) attacks to degrade or block the availability of targeted resources to users. Network DoS can be performed by exhausting the network bandwidth services rely on. Example resources include specific websites, email services, DNS, and web-based applications. Adversaries have been observed conducting network DoS attacks for political purposes and to support other malicious activities, including distraction, hacktivism, and extortion."
    T1046 = "Adversaries may attempt to get a listing of services running on remote hosts and local network infrastructure devices, including those that may be vulnerable to remote software exploitation. Common methods to acquire this information include port and/or vulnerability scans using tools that are brought onto a system."
    T1135 = "Adversaries may look for folders and drives shared on remote systems as a means of identifying sources of information to gather as a precursor for Collection and to identify potential systems of interest for Lateral Movement. Networks often contain shared network drives and folders that enable users to access file directories on various systems across a network."
    T1040 = "Adversaries may passively sniff network traffic to capture information about an environment, including authentication material passed over the network. Network sniffing refers to using the network interface on a system to monitor or capture information sent over a wired or wireless connection. An adversary may place a network interface into promiscuous mode to passively access data in transit over the network, or use span ports to capture a larger amount of data."
    T1095 = "Adversaries may use an OSI non-application layer protocol for communication between host and C2 server or among infected hosts within a network. The list of possible protocols is extensive. Specific examples include use of network layer protocols, such as the Internet Control Message Protocol (ICMP), transport layer protocols, such as the User Datagram Protocol (UDP), session layer protocols, such as Socket Secure (SOCKS), as well as redirected/tunneled protocols, such as Serial over LAN (SOL)."
    T1571 = "Adversaries may communicate using a protocol and port pairing that are typically not associated. For example, HTTPS over port 8088 or port 587 as opposed to the traditional port 443. Adversaries may make changes to the standard port used by a protocol to bypass filtering or muddle analysis/parsing of network data."
    T1027 = "Adversaries may attempt to make an executable or file difficult to discover or analyze by encrypting, encoding, or otherwise obfuscating its contents on the system or in transit. This is common behavior that can be used across different platforms and the network to evade defenses."
    T1588 = "Adversaries may buy and/or steal capabilities that can be used during targeting. Rather than developing their own capabilities in-house, adversaries may purchase, freely download, or steal them. Activities may include the acquisition of malware, software (including licenses), exploits, certificates, and information relating to vulnerabilities. Adversaries may obtain capabilities to support their operations throughout numerous phases of the adversary lifecycle."
    T1137 = "Adversaries may leverage Microsoft Office-based applications for persistence between startups. Microsoft Office is a fairly common application suite on Windows-based operating systems within an enterprise network. There are multiple mechanisms that can be used with Office for persistence when an Office-based application is started; this can include the use of Office Template Macros and add-ins."
    T1003 = "Adversaries may attempt to dump credentials to obtain account login and credential material, normally in the form of a hash or a clear text password. Credentials can be obtained from OS caches, memory, or structures. Credentials can then be used to perform Lateral Movement and access restricted information."
    T1201 = "Adversaries may attempt to access detailed information about the password policy used within an enterprise network or cloud environment. Password policies are a way to enforce complex passwords that are difficult to guess or crack through Brute Force. This information may help the adversary to create a list of common passwords and launch dictionary and/or brute force attacks which adheres to the policy (e.g. if the minimum password length should be 8, then not trying passwords such as 'pass123'; not checking for more than 3-4 passwords per account if the lockout is set to 6 as to not lock out accounts)."
    T1120 = "Adversaries may attempt to gather information about attached peripheral devices and components connected to a computer system. Peripheral devices could include auxiliary resources that support a variety of functionalities such as keyboards, printers, cameras, smart card readers, or removable storage. The information may be used to enhance their awareness of the system and network environment or may be used for further actions."
    T1069 = "Adversaries may attempt to discover group and permission settings. This information can help adversaries determine which user accounts and groups are available, the membership of users in particular groups, and which users and groups have elevated permissions."
    T1566 = "Adversaries may send phishing messages to gain access to victim systems. All forms of phishing are electronically delivered social engineering. Phishing can be targeted, known as spearphishing. In spearphishing, a specific individual, company, or industry will be targeted by the adversary. More generally, adversaries can conduct non-targeted phishing, such as in mass malware spam campaigns."
    T1598 = "Adversaries may send phishing messages to elicit sensitive information that can be used during targeting. Phishing for information is an attempt to trick targets into divulging information, frequently credentials or other actionable information. Phishing for information is different from Phishing in that the objective is gathering data from the victim rather than executing malicious code."
    T1647 = "Adversaries may modify property list files (plist files) to enable other malicious activity, while also potentially evading and bypassing system defenses. macOS applications use plist files, such as the info.plist file, to store properties and configuration settings that inform the operating system how to handle the application at runtime. Plist files are structured metadata in key-value pairs formatted in XML based on Apple's Core Foundation DTD. Plist files can be saved in text or binary format."
    T1653 = "Adversaries may impair a system's ability to hibernate, reboot, or shut down in order to extend access to infected machines. When a computer enters a dormant state, some or all software and hardware may cease to operate which can disrupt malicious activity."
    T1542 = "Adversaries may abuse Pre-OS Boot mechanisms as a way to establish persistence on a system. During the booting process of a computer, firmware and various startup services are loaded before the operating system. These programs control flow of execution before the operating system takes control."
    T1057 = "Adversaries may attempt to get information about running processes on a system. Information obtained could be used to gain an understanding of common software/applications running on systems within the network. Administrator or otherwise elevated access may provide better process details. Adversaries may use the information from Process Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1055 = "Adversaries may inject code into processes in order to evade process-based defenses as well as possibly elevate privileges. Process injection is a method of executing arbitrary code in the address space of a separate live process. Running code in the context of another process may allow access to the process's memory, system/network resources, and possibly elevated privileges. Execution via process injection may also evade detection from security products since the execution is masked under a legitimate process."
    T1572 = "Adversaries may tunnel network communications to and from a victim system within a separate protocol to avoid detection/network filtering and/or enable access to otherwise unreachable systems. Tunneling involves explicitly encapsulating a protocol within another. This behavior may conceal malicious traffic by blending in with existing traffic and/or provide an outer layer of encryption (similar to a VPN). Tunneling could also enable routing of network packets that would otherwise not reach their intended destination, such as SMB, RDP, or other traffic that would be filtered by network appliances or not routed over the Internet."
    T1090 = "Adversaries may use a connection proxy to direct network traffic between systems or act as an intermediary for network communications to a command and control server to avoid direct connections to their infrastructure. Many tools exist that enable traffic redirection through proxies or port redirection, including HTRAN, ZXProxy, and ZXPortMap.  Adversaries use these types of proxies to manage command and control communications, reduce the number of simultaneous outbound network connections, provide resiliency in the face of connection loss, or to ride over existing trusted communications paths between victims to avoid suspicion. Adversaries may chain together multiple proxies to further disguise the source of malicious traffic."
    T1012 = "Adversaries may interact with the Windows Registry to gather information about the system, configuration, and installed software."
    T1620 = "Adversaries may reflectively load code into a process in order to conceal the execution of malicious payloads. Reflective loading involves allocating then executing payloads directly within the memory of the process, vice creating a thread or process backed by a file path on disk (e.g., Shared Modules)."
    T1219 = "An adversary may use legitimate desktop support and remote access software to establish an interactive command and control channel to target systems within networks. These services, such as VNC, Team Viewer, AnyDesk, ScreenConnect, LogMein, AmmyyAdmin, and other remote monitoring and management (RMM) tools, are commonly used as legitimate technical support software and may be allowed by application control within a target environment."
    T1563 = "Adversaries may take control of preexisting sessions with remote services to move laterally in an environment. Users may use valid credentials to log into a service specifically designed to accept remote connections, such as telnet, SSH, and RDP. When a user logs into a service, a session will be established that will allow them to maintain a continuous interaction with that service."
    T1021 = "Adversaries may use Valid Accounts to log into a service that accepts remote connections, such as telnet, SSH, and VNC. The adversary may then perform actions as the logged-on user."
    T1018 = "Adversaries may attempt to get a listing of other systems by IP address, hostname, or other logical identifier on a network that may be used for Lateral Movement from the current system. Functionality could exist within remote access tools to enable this, but utilities available on the operating system could also be used such as  Ping or net view using Net."
    T1091 = "Adversaries may move onto systems, possibly those on disconnected or air-gapped networks, by copying malware to removable media and taking advantage of Autorun features when the media is inserted into a system and executes. In the case of Lateral Movement, this may occur through modification of executable files stored on removable media or by copying malware and renaming it to look like a legitimate file to trick users into executing it on a separate system. In the case of Initial Access, this may occur through manual manipulation of the media, modification of systems used to initially format the media, or modification to the media's firmware itself."
    T1496 = "Adversaries may leverage the resources of co-opted systems to complete resource-intensive tasks, which may impact system and/or hosted service availability."
    T1207 = "Adversaries may register a rogue Domain Controller to enable manipulation of Active Directory data. DCShadow may be used to create a rogue Domain Controller (DC). DCShadow is a method of manipulating Active Directory (AD) data, including objects and schemas, by registering (or reusing an inactive registration) and simulating the behavior of a DC.  Once registered, a rogue DC may be able to inject and replicate changes into AD infrastructure for any domain object, including credentials and keys."
    T1014 = "Adversaries may use rootkits to hide the presence of programs, files, network connections, services, drivers, and other system components. Rootkits are programs that hide the existence of malware by intercepting/hooking and modifying operating system API calls that supply system information."
    T1053 = "Adversaries may abuse task scheduling functionality to facilitate initial or recurring execution of malicious code. Utilities exist within all major operating systems to schedule programs or scripts to be executed at a specified date and time. A task can also be scheduled on a remote system, provided the proper authentication is met (ex: RPC and file and printer sharing in Windows environments). Scheduling a task on a remote system typically may require being a member of an admin or otherwise privileged group on the remote system."
    T1029 = "Adversaries may schedule data exfiltration to be performed only at certain times of day or at certain intervals. This could be done to blend traffic patterns with normal activity or availability."
    T1113 = "Adversaries may attempt to take screen captures of the desktop to gather information over the course of an operation. Screen capturing functionality may be included as a feature of a remote access tool used in post-compromise operations. Taking a screenshot is also typically possible through native utilities or API calls, such as CopyFromScreen, xwd, or screencapture."
    T1597 = "Adversaries may search and gather information about victims from closed (e.g., paid, private, or otherwise not freely available) sources that can be used during targeting. Information about victims may be available for purchase from reputable private sources and databases, such as paid subscriptions to feeds of technical/threat intelligence data. Adversaries may also purchase information from less-reputable sources such as dark web or cybercrime blackmarkets."
    T1596 = "Adversaries may search freely available technical databases for information about victims that can be used during targeting. Information about victims may be available in online databases and repositories, such as registrations of domains/certificates as well as public collections of network data/artifacts gathered from traffic and/or scans."
    T1593 = "Adversaries may search freely available websites and/or domains for information about victims that can be used during targeting. Information about victims may be available in various online sites, such as social media, new sites, or those hosting information about business operations such as hiring or requested/rewarded contracts."
    T1594 = "Adversaries may search websites owned by the victim for information that can be used during targeting. Victim-owned websites may contain a variety of details, including names of departments/divisions, physical locations, and data about key employees such as names, roles, and contact info (ex: Email Addresses). These sites may also have details highlighting business operations and relationships."
    T1505 = "Adversaries may abuse legitimate extensible development features of servers to establish persistent access to systems. Enterprise server applications may include features that allow developers to write and install software or scripts to extend the functionality of the main application. Adversaries may install malicious components to extend and abuse server applications."
    T1648 = "Adversaries may abuse serverless computing, integration, and automation services to execute arbitrary code in cloud environments. Many cloud providers offer a variety of serverless resources, including compute engines, application integration services, and web servers."
    T1489 = "Adversaries may stop or disable services on a system to render those services unavailable to legitimate users. Stopping critical services or processes can inhibit or stop response to an incident or aid in the adversary's overall objectives to cause damage to the environment."
    T1129 = "Adversaries may execute malicious payloads via loading shared modules. Shared modules are executable files that are loaded into processes to provide access to reusable code, such as specific custom functions or invoking OS API functions (i.e., Native API)."
    T1072 = "Adversaries may gain access to and use centralized software suites installed within an enterprise to execute commands and move laterally through the network. Configuration management and software deployment applications may be used in an enterprise network or cloud environment for routine administration purposes. These systems may also be integrated into CI/CD pipelines. Examples of such solutions include: SCCM, HBSS, Altiris, AWS Systems Manager, Microsoft Intune, Azure Arc, and GCP Deployment Manager."
    T1518 = "Adversaries may attempt to get a listing of software and software versions that are installed on a system or in a cloud environment. Adversaries may use the information from Software Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1608 = "Adversaries may upload, install, or otherwise set up capabilities that can be used during targeting. To support their operations, an adversary may need to take capabilities they developed (Develop Capabilities) or obtained (Obtain Capabilities) and stage them on infrastructure under their control. These capabilities may be staged on infrastructure that was previously purchased/rented by the adversary (Acquire Infrastructure) or was otherwise compromised by them (Compromise Infrastructure). Capabilities may also be staged on web services, such as GitHub or Pastebin, or on Platform-as-a-Service (PaaS) offerings that enable users to easily provision applications."
    T1528 = "Adversaries can steal application access tokens as a means of acquiring credentials to access remote systems and resources."
    T1649 = "Adversaries may steal or forge certificates used for authentication to access remote systems or resources. Digital certificates are often used to sign and encrypt messages and/or files. Certificates are also used as authentication material. For example, Entra ID device certificates and Active Directory Certificate Services (AD CS) certificates bind to an identity and can be used as credentials for domain accounts."
    T1558 = "Adversaries may attempt to subvert Kerberos authentication by stealing or forging Kerberos tickets to enable Pass the Ticket. Kerberos is an authentication protocol widely used in modern Windows domain environments. In Kerberos environments, referred to as 'realms' there are three basic participants: client, service, and Key Distribution Center (KDC). Clients request access to a service and through the exchange of Kerberos tickets, originating from KDC, they are granted access after having successfully authenticated. The KDC is responsible for both authentication and ticket granting.  Adversaries may attempt to abuse Kerberos by stealing tickets or forging tickets to enable unauthorized access."
    T1539 = "An adversary may steal web application or service session cookies and use them to gain access to web applications or Internet services as an authenticated user without needing credentials. Web applications and services often use session cookies as an authentication token after a user has authenticated to a website."
    T1553 = "Adversaries may undermine security controls that will either warn users of untrusted activity or prevent execution of untrusted programs. Operating systems and security products may contain mechanisms to identify programs or websites as possessing some level of trust. Examples of such features would include a program being allowed to run because it is signed by a valid code signing certificate, a program prompting the user with a warning because it has an attribute set from being downloaded from the Internet, or getting an indication that you are about to connect to an untrusted site."
    T1195 = "Adversaries may manipulate products or product delivery mechanisms prior to receipt by a final consumer for the purpose of data or system compromise."
    T1218 = "Adversaries may bypass process and/or signature-based defenses by proxying execution of malicious content with signed, or otherwise trusted, binaries. Binaries used in this technique are often Microsoft-signed files, indicating that they have been either downloaded from Microsoft or are already native in the operating system. Binaries signed with trusted digital certificates can typically execute on Windows systems protected by digital signature validation. Several Microsoft signed binaries that are default on Windows installations can be used to proxy execution of other files or commands."
    T1082 = "An adversary may attempt to get detailed information about the operating system and hardware, including version, patches, hotfixes, service packs, and architecture. Adversaries may use the information from System Information Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1614 = "Adversaries may gather information in an attempt to calculate the geographical location of a victim host. Adversaries may use the information from System Location Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1016 = "Adversaries may look for details about the network configuration and settings, such as IP and/or MAC addresses, of systems they access or through information discovery of remote systems. Several operating system administration utilities exist that can be used to gather this information. Examples include Arp, ipconfig/ifconfig, nbtstat, and route."
    T1049 = "Adversaries may attempt to get a listing of network connections to or from the compromised system they are currently accessing or from remote systems by querying for information over the network."
    T1033 = "Adversaries may attempt to identify the primary user, currently logged in user, set of users that commonly uses a system, or whether a user is actively using the system. They may do this, for example, by retrieving account usernames or by using OS Credential Dumping. The information may be collected in a number of different ways using other Discovery techniques, because user and username details are prevalent throughout a system and include running process ownership, file/directory ownership, session information, and system logs. Adversaries may use the information from System Owner/User Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1216 = "Adversaries may use trusted scripts, often signed with certificates, to proxy the execution of malicious files. Several Microsoft signed scripts that have been downloaded from Microsoft or are default on Windows installations can be used to proxy execution of other files. This behavior may be abused by adversaries to execute malicious files that could bypass application control and signature validation on systems."
    T1007 = "Adversaries may try to gather information about registered local system services. Adversaries may obtain information about services using tools as well as OS utility commands such as sc query, tasklist /svc, systemctl --type=service, and net start."
    T1569 = "Adversaries may abuse system services or daemons to execute commands or programs. Adversaries can execute malicious content by interacting with or creating services either locally or remotely. Many services are set to run at boot, which can aid in achieving persistence (Create or Modify System Process), but adversaries can also abuse services for one-time or temporary execution."
    T1529 = "Adversaries may shutdown/reboot systems to interrupt access to, or aid in the destruction of, those systems. Operating systems may contain commands to initiate a shutdown/reboot of a machine or network device. In some cases, these commands may also be used to initiate a shutdown/reboot of a remote computer or network device via Network Device CLI (e.g. reload)."
    T1124 = "An adversary may gather the system time and/or time zone settings from a local or remote system. The system time is set and stored by services, such as the Windows Time Service on Windows or systemsetup on macOS. These time settings may also be synchronized between systems and services in an enterprise network, typically accomplished with a network time server within a domain."
    T1080 = "Adversaries may deliver payloads to remote systems by adding content to shared storage locations, such as network drives or internal code repositories. Content stored on network drives or in other shared locations may be tainted by adding malicious programs, scripts, or exploit code to otherwise valid files. Once a user opens the shared tainted content, the malicious portion can be executed to run the adversary's code on a remote system. Adversaries may use tainted shared content to move laterally."
    T1221 = "Adversaries may create or modify references in user document templates to conceal malicious code or force authentication attempts. For example, Microsoft’s Office Open XML (OOXML) specification defines an XML-based format for Office documents (.docx, xlsx, .pptx) to replace older binary formats (.doc, .xls, .ppt). OOXML files are packed together ZIP archives compromised of various XML files, referred to as parts, containing properties that collectively define how a document is rendered."
    T1205 = "Adversaries may use traffic signaling to hide open ports or other malicious functionality used for persistence or command and control. Traffic signaling involves the use of a magic value or sequence that must be sent to a system to trigger a special response, such as opening a closed port or executing a malicious task. This may take the form of sending a series of packets with certain characteristics before a port will be opened that the adversary can use for command and control. Usually this series of packets consists of attempted connections to a predefined sequence of closed ports (i.e. Port Knocking), but can involve unusual flags, specific strings, or other unique characteristics. After the sequence is completed, opening a port may be accomplished by the host-based firewall, but could also be implemented by custom software."
    T1537 = "Adversaries may exfiltrate data by transferring the data, including through sharing/syncing and creating backups of cloud environments, to another cloud account they control on the same service."
    T1127 = "Adversaries may take advantage of trusted developer utilities to proxy execution of malicious payloads. There are many utilities used for software development related tasks that can be used to execute code in various forms to assist in development, debugging, and reverse engineering. These utilities may often be signed with legitimate certificates that allow them to execute on a system and proxy execution of malicious code through a trusted process that effectively bypasses application control solutions."
    T1199 = "Adversaries may breach or otherwise leverage organizations who have access to intended victims. Access through trusted third party relationship abuses an existing connection that may not be protected or receives less scrutiny than standard mechanisms of gaining access to a network."
    T1552 = "Adversaries may search compromised systems to find and obtain insecurely stored credentials. These credentials can be stored and/or misplaced in many locations on a system, including plaintext files (e.g. Bash History), operating system or application-specific repositories (e.g. Credentials in Registry),  or other specialized files/artifacts (e.g. Private Keys)."
    T1535 = "Adversaries may create cloud instances in unused geographic service regions in order to evade detection. Access is usually obtained through compromising accounts used to manage cloud infrastructure."
    T1550 = "Adversaries may use alternate authentication material, such as password hashes, Kerberos tickets, and application access tokens, in order to move laterally within an environment and bypass normal system access controls."
    T1204 = "An adversary may rely upon specific actions by a user in order to gain execution. Users may be subjected to social engineering to get them to execute malicious code by, for example, opening a malicious document file or link. These user actions will typically be observed as follow-on behavior from forms of Phishing."
    T1078 = "Adversaries may obtain and abuse credentials of existing accounts as a means of gaining Initial Access, Persistence, Privilege Escalation, or Defense Evasion. Compromised credentials may be used to bypass access controls placed on various resources on systems within the network and may even be used for persistent access to remote systems and externally available services, such as VPNs, Outlook Web Access, network devices, and remote desktop. Compromised credentials may also grant an adversary increased privilege to specific systems or access to restricted areas of the network. Adversaries may choose not to use malware or tools in conjunction with the legitimate access those credentials provide to make it harder to detect their presence."
    T1125 = "An adversary can leverage a computer's peripheral devices (e.g., integrated cameras or webcams) or applications (e.g., video call services) to capture video recordings for the purpose of gathering information. Images may also be captured from devices or applications, potentially in specified intervals, in lieu of video files."
    T1497 = "Adversaries may employ various means to detect and avoid virtualization and analysis environments. This may include changing behaviors based on the results of checks for the presence of artifacts indicative of a virtual machine environment (VME) or sandbox. If the adversary detects a VME, they may alter their malware to disengage from the victim or conceal the core functions of the implant. They may also search for VME artifacts before dropping secondary or additional payloads. Adversaries may use the information learned from Virtualization/Sandbox Evasion during automated discovery to shape follow-on behaviors."
    T1600 = "Adversaries may compromise a network device’s encryption capability in order to bypass encryption that would otherwise protect data communications."
    T1102 = "Adversaries may use an existing, legitimate external Web service as a means for relaying data to/from a compromised system. Popular websites, cloud services, and social media acting as a mechanism for C2 may give a significant amount of cover due to the likelihood that hosts within a network are already communicating with them prior to a compromise. Using common services, such as those offered by Google, Microsoft, or Twitter, makes it easier for adversaries to hide in expected noise. Web service providers commonly use SSL/TLS encryption, giving adversaries an added level of protection."
    T1047 = "Adversaries may abuse Windows Management Instrumentation (WMI) to execute malicious commands and payloads. WMI is designed for programmers and is the infrastructure for management data and operations on Windows systems. WMI is an administration feature that provides a uniform environment to access Windows system components."
    T1220 = "Adversaries may bypass application control and obscure execution of code by embedding scripts inside XSL files. Extensible Stylesheet Language (XSL) files are commonly used to describe the processing and rendering of data within XML files. To support complex operations, the XSL standard includes support for embedded scripting in various languages."
    T1626 = "Adversaries may circumvent mechanisms designed to control elevated privileges to gain higher-level permissions. Most modern systems contain native elevation control mechanisms that are intended to limit privileges that a user can gain on a machine. Authorization has to be granted to specific users in order to perform tasks that are designated as higher risk. An adversary can use several methods to take advantage of built-in control mechanisms in order to escalate privileges on a system."
    T1517 = "Adversaries may collect data within notifications sent by the operating system or other applications. Notifications may contain sensitive data such as one-time authentication codes sent over SMS, email, or other mediums. In the case of Credential Access, adversaries may attempt to intercept one-time code sent to the device. Adversaries can also dismiss notifications to prevent the user from noticing that the notification has arrived and can trigger action buttons contained within notifications."
    T1640 = "Adversaries may interrupt availability of system and network resources by inhibiting access to accounts utilized by legitimate users. Accounts may be deleted, locked, or manipulated (ex: credentials changed) to remove access to accounts."
    T1638 = "Adversaries may attempt to position themselves between two or more networked devices to support follow-on behaviors such as Transmitted Data Manipulation or Endpoint Denial of Service."
    T1437 = "Adversaries may communicate using application layer protocols to avoid detection/network filtering by blending in with existing traffic. Commands to the mobile device, and often the results of those commands, will be embedded within the protocol traffic between the mobile device and server."
    T1661 = "An adversary may push an update to a previously benign application to add malicious code. This can be accomplished by pushing an initially benign, functional application to a trusted application store, such as the Google Play Store or the Apple App Store. This allows the adversary to establish a trusted userbase that may grant permissions to the application prior to the introduction of malicious code. Then, an application update could be pushed to introduce malicious code."
    T1532 = "Adversaries may compress and/or encrypt data that is collected prior to exfiltration. Compressing data can help to obfuscate its contents and minimize use of network resources. Encryption can be used to hide information that is being exfiltrated from detection or make exfiltration less conspicuous upon inspection by a defender."
    T1429 = "Adversaries may capture audio to collect information by leveraging standard operating system APIs of a mobile device. Examples of audio information adversaries may target include user conversations, surroundings, phone calls, or other sensitive information."
    T1398 = "Adversaries may use scripts automatically executed at boot or logon initialization to establish persistence. Initialization scripts are part of the underlying operating system and are not accessible to the user unless the device has been rooted or jailbroken."
    T1616 = "Adversaries may make, forward, or block phone calls without user authorization. This could be used for adversary goals such as audio surveillance, blocking or forwarding calls from the device owner, or C2 communication."
    T1414 = "Adversaries may abuse clipboard manager APIs to obtain sensitive information copied to the device clipboard. For example, passwords being copied and pasted from a password manager application could be captured by a malicious application installed on the device."
    T1623 = "Adversaries may abuse command and script interpreters to execute commands, scripts, or binaries. These interfaces and languages provide ways of interacting with computer systems and are a common feature across many different platforms. Most systems come with some built-in command-line interface and scripting capabilities, for example, Android is a UNIX-like OS and includes a basic Unix Shell that can be accessed via the Android Debug Bridge (ADB) or Java’s Runtime package."
    T1577 = "Adversaries may modify applications installed on a device to establish persistent access to a victim. These malicious modifications can be used to make legitimate applications carry out adversary tasks when these applications are in use."
    T1645 = "Adversaries may modify system software binaries to establish persistent access to devices. System software binaries are used by the underlying operating system and users over adb or terminal emulators."
    T1634 = "Adversaries may search common password storage locations to obtain user credentials. Passwords can be stored in several places on a device, depending on the operating system or application holding the credentials. There are also specific applications that store passwords to make it easier for users to manage and maintain. Once credentials are obtained, they can be used to perform lateral movement and access restricted information."
    T1662 = "Adversaries may destroy data and files on specific devices or in large numbers to interrupt availability to systems, services, and network resources. Data destruction is likely to render stored data irrecoverable by forensic techniques through overwriting files or data on local and remote drives."
    T1471 = "An adversary may encrypt files stored on a mobile device to prevent the user from accessing them. This may be done in order to extract monetary compensation from a victim in exchange for decryption or a decryption key (ransomware) or to render data permanently inaccessible in cases where the key is not saved or transmitted."
    T1533 = "Adversaries may search local system sources, such as file systems or local databases, to find files of interest and sensitive data prior to exfiltration."
    T1641 = "Adversaries may insert, delete, or alter data in order to manipulate external outcomes or hide activity. By manipulating data, adversaries may attempt to affect a business process, organizational understanding, or decision making."
    T1407 = "Adversaries may download and execute dynamic code not included in the original application package after installation. This technique is primarily used to evade static analysis checks and pre-publication scans in official app stores. In some cases, more advanced dynamic or behavioral analysis techniques could detect this behavior. However, in conjunction with Execution Guardrails techniques, detecting malicious code downloaded after installation could be difficult."
    T1456 = "Adversaries may gain access to a system through a user visiting a website over the normal course of browsing. With this technique, the user's web browser is typically targeted for exploitation, but adversaries may also use compromised websites for non-exploitation behavior such as acquiring an Application Access Token."
    T1637 = "Adversaries may dynamically establish connections to command and control infrastructure to evade common detections and remediations. This may be achieved by using malware that shares a common algorithm with the infrastructure the adversary uses to receive the malware's communications. This algorithm can be used to dynamically adjust parameters such as the domain name, IP address, or port number the malware uses for command and control."
    T1521 = "Adversaries may explicitly employ a known encryption algorithm to conceal command and control traffic rather than relying on any inherent protections provided by a communication protocol. Despite the use of a secure algorithm, these implementations may be vulnerable to reverse engineering if necessary secret keys are encoded and/or generated within malware samples/configuration files."
    T1642 = "Adversaries may perform Endpoint Denial of Service (DoS) attacks to degrade or block the availability of services to users."
    T1624 = "Adversaries may establish persistence using system mechanisms that trigger execution based on specific events. Mobile operating systems have means to subscribe to events such as receiving an SMS message, device boot completion, or other device activities."
    T1627 = "Adversaries may use execution guardrails to constrain execution or actions based on adversary supplied and environment specific conditions that are expected to be present on the target. Guardrails ensure that a payload only executes against an intended target and reduces collateral damage from an adversary’s campaign. Values an adversary can provide about a target system or environment to use as guardrails may include environment information such as location."
    T1639 = "Adversaries may steal data by exfiltrating it over a different protocol than that of the existing command and control channel. The data may also be sent to an alternate network location from the main command and control server."
    T1646 = "Adversaries may steal data by exfiltrating it over an existing command and control channel. Stolen data is encoded into the normal communications channel using the same protocol as command and control communications."
    T1658 = "Adversaries may exploit software vulnerabilities in client applications to execute code. Vulnerabilities can exist in software due to insecure coding practices that can lead to unanticipated behavior. Adversaries may take advantage of certain vulnerabilities through targeted exploitation for the purpose of arbitrary code execution. Oftentimes the most valuable exploits to an offensive toolkit are those that can be used to obtain code execution on a remote system because they can be used to gain access to that system. Users will expect to see files related to the applications they commonly used to do work, so they are a useful target for exploit research and development because of their high utility."
    T1664 = "Adversaries may exploit software vulnerabilities to gain initial access to a mobile device."
    T1404 = "Adversaries may exploit software vulnerabilities in order to elevate privileges. Exploitation of a software vulnerability occurs when an adversary takes advantage of a programming error in an application, service, within the operating system software, or kernel itself to execute adversary-controlled code. Security constructions, such as permission levels, will often hinder access to information and use of certain techniques. Adversaries will likely need to perform privilege escalation to include use of software exploitation to circumvent those restrictions."
    T1428 = "Adversaries may exploit remote services of enterprise servers, workstations, or other resources to gain unauthorized access to internal systems once inside of a network. Adversaries may exploit remote services by taking advantage of a mobile device’s access to an internal enterprise network through local connectivity or through a Virtual Private Network (VPN). Exploitation of a software vulnerability occurs when an adversary takes advantage of a programming error in a program, service, or within the operating system software or kernel itself to execute adversary-controlled code. A common goal for post-compromise exploitation of remote services is for lateral movement to enable access to a remote system."
    T1420 = "Adversaries may enumerate files and directories or search in specific device locations for desired information within a filesystem. Adversaries may use the information from File and Directory Discovery during automated discovery to shape follow-on behaviors, including deciding if the adversary should fully infect the target and/or attempt specific actions."
    T1541 = "Adversaries may abuse Android's startForeground() API method to maintain continuous sensor access. Beginning in Android 9, idle applications running in the background no longer have access to device sensors, such as the camera, microphone, and gyroscope. Applications can retain sensor access by running in the foreground, using Android’s startForeground() API method. This informs the system that the user is actively interacting with the application, and it should not be killed. The only requirement to start a foreground service is showing a persistent notification to the user."
    T1643 = "Adversaries may generate outbound traffic from devices. This is typically performed to manipulate external outcomes, such as to achieve carrier billing fraud or to manipulate app store rankings or ratings. Outbound traffic is typically generated as SMS messages or general web traffic, but may take other forms as well."
    T1628 = "Adversaries may attempt to hide artifacts associated with their behaviors to evade detection. Mobile operating systems have features and developer APIs to hide various artifacts, such as an application’s launcher icon. These APIs have legitimate usages, such as hiding an icon to avoid application drawer clutter when an application does not have a usable interface. Adversaries may abuse these features and APIs to hide artifacts from the user to evade detection."
    T1625 = "Adversaries may execute their own malicious payloads by hijacking the way operating systems run applications. Hijacking execution flow can be for the purposes of persistence since this hijacked execution may reoccur over time."
    T1617 = "Adversaries may utilize hooking to hide the presence of artifacts associated with their behaviors to evade detection. Hooking can be used to modify return values or data structures of system APIs and function calls. This process typically involves using 3rd party root frameworks, such as Xposed or Magisk, with either a system exploit or pre-existing root access. By including custom modules for root frameworks, adversaries can hook system APIs and alter the return value and/or system data structures to alter functionality/visibility of various aspects of the system."
    T1629 = "Adversaries may maliciously modify components of a victim environment in order to hinder or disable defensive mechanisms. This not only involves impairing preventative defenses, such as anti-virus, but also detection capabilities that defenders can use to audit activity and identify malicious behavior. This may span both native defenses as well as supplemental capabilities installed by users or mobile endpoint administrators."
    T1630 = "Adversaries may delete, alter, or hide generated artifacts on a device, including files, jailbreak status, or the malicious application itself. These actions may interfere with event collection, reporting, or other notifications used to detect intrusion activity. This may compromise the integrity of mobile security solutions by causing notable events or information to go unreported."
    T1544 = "Adversaries may transfer tools or other files from an external system onto a compromised device to facilitate follow-on actions. Files may be copied from an external adversary-controlled system through the command and control channel  or through alternate protocols with another tool such as FTP."
    T1417 = "Adversaries may use methods of capturing user input to obtain credentials or collect information. During normal device usage, users often provide credentials to various locations, such as login pages/portals or system dialog boxes. Input capture mechanisms may be transparent to the user (e.g. Keylogging) or rely on deceiving the user into providing input into what they believe to be a genuine application prompt (e.g. GUI Input Capture)."
    T1516 = "A malicious application can inject input to the user interface to mimic user interaction through the abuse of Android's accessibility APIs."
    T1430 = "Adversaries may track a device’s physical location through use of standard operating system APIs via malicious or exploited applications on the compromised device."
    T1461 = "An adversary with physical access to a mobile device may seek to bypass the device’s lockscreen. Several methods exist to accomplish this, including:"
    T1655 = "Adversaries may attempt to manipulate features of their artifacts to make them appear legitimate or benign to users and/or security tools. Masquerading occurs when the name, location, or appearance of an object, legitimate or malicious, is manipulated or abused for the sake of evading defenses and observation. This may include manipulating file metadata, tricking users into misidentifying the file type, and giving legitimate task or service names."
    T1575 = "Adversaries may use Android’s Native Development Kit (NDK) to write native functions that can achieve execution of binaries or functions. Like system calls on a traditional desktop operating system, native code achieves execution on a lower level than normal Android SDK calls."
    T1464 = "Adversaries may perform Network Denial of Service (DoS) attacks to degrade or block the availability of targeted resources to users. Network DoS can be performed by exhausting the network bandwidth that services rely on, or by jamming the signal going to or coming from devices."
    T1423 = "Adversaries may attempt to get a listing of services running on remote hosts, including those that may be vulnerable to remote software exploitation. Methods to acquire this information include port scans and vulnerability scans from the mobile device. This technique may take advantage of the mobile device's access to an internal enterprise network either through local connectivity or through a Virtual Private Network (VPN)."
    T1509 = "Adversaries may generate network traffic using a protocol and port pairing that are typically not associated. For example, HTTPS over port 8088 or port 587 as opposed to the traditional port 443. Adversaries may make changes to the standard port used by a protocol to bypass filtering or muddle analysis/parsing of network data."
    T1406 = "Adversaries may attempt to make a payload or file difficult to discover or analyze by encrypting, encoding, or otherwise obfuscating its contents on the device or in transit. This is common behavior that can be used across different platforms and the network to evade defenses."
    T1644 = "Adversaries may communicate with compromised devices using out of band data streams. This could be done for a variety of reasons, including evading network traffic monitoring, as a backup method of command and control, or for data exfiltration if the device is not connected to any Internet-providing networks (i.e. cellular or Wi-Fi). Several out of band data streams exist, such as SMS messages, NFC, and Bluetooth."
    T1660 = "Adversaries may send malicious content to users in order to gain access to their mobile devices. All forms of phishing are electronically delivered social engineering. Adversaries can conduct both non-targeted phishing, such as in mass malware spam campaigns, as well as more targeted phishing tailored for a specific individual, company, or industry, known as 'spearphishing'.  Phishing often involves social engineering techniques, such as posing as a trusted source, as well as evasion techniques, such as removing or manipulating emails or metadata/headers from compromised accounts being abused to send messages."
    T1424 = "Adversaries may attempt to get information about running processes on a device. Information obtained could be used to gain an understanding of common software/applications running on devices within a network. Adversaries may use the information from Process Discovery during automated discovery to shape follow-on behaviors, including whether or not the adversary fully infects the target and/or attempts specific actions."
    T1631 = "Adversaries may inject code into processes in order to evade process-based defenses or even elevate privileges. Process injection is a method of executing arbitrary code in the address space of a separate live process. Running code in the context of another process may allow access to the process's memory, system/network resources, and possibly elevated privileges. Execution via process injection may also evade detection from security products since the execution is masked under a legitimate process."
    T1636 = "Adversaries may utilize standard operating system APIs to collect data from permission-backed data stores on a device, such as the calendar or contact list. These permissions need to be declared ahead of time. On Android, they must be included in the application’s manifest. On iOS, they must be included in the application’s Info.plist file."
    T1604 = "Adversaries may use a compromised device as a proxy server to the Internet. By utilizing a proxy, adversaries hide the true IP address of their C2 server and associated infrastructure from the destination of the network traffic. This masquerades an adversary’s traffic as legitimate traffic originating from the compromised device, which can evade IP-based restrictions and alerts on certain services, such as bank accounts and social media websites."
    T1663 = "Adversaries may use legitimate remote access software, such as VNC, TeamViewer, AirDroid, AirMirror, etc., to establish an interactive command and control channel to target mobile devices."
    T1458 = "Adversaries may move onto devices by exploiting or copying malware to devices connected via USB. In the case of Lateral Movement, adversaries may utilize the physical connection of a device to a compromised or malicious charging station or PC to bypass application store requirements and install malicious applications directly. In the case of Initial Access, adversaries may attempt to exploit the device via the connection to gain access to data stored on the device. Examples of this include:"
    T1603 = "Adversaries may abuse task scheduling functionality to facilitate initial or recurring execution of malicious code. On Android and iOS, APIs and libraries exist to facilitate scheduling tasks to execute at a specified date, time, or interval."
    T1513 = "Adversaries may use screen capture to collect additional information about a target device, such as applications running in the foreground, user data, credentials, or other sensitive information. Applications running in the background can capture screenshots or videos of another application running in the foreground by using the Android MediaProjectionManager (generally requires the device user to grant consent). Background applications can also use Android accessibility services to capture screen contents being displayed by a foreground application. An adversary with root access or Android Debug Bridge (adb) access could call the Android screencap or screenrecord commands."
    T1582 = "Adversaries may delete, alter, or send SMS messages without user authorization. This could be used to hide C2 SMS messages, spread malware, or various external effects."
    T1418 = "Adversaries may attempt to get a listing of applications that are installed on a device. Adversaries may use the information from Software Discovery during automated discovery to shape follow-on behaviors, including whether or not to fully infect the target and/or attempts specific actions."
    T1635 = "Adversaries can steal user application access tokens as a means of acquiring credentials to access remote systems and resources. This can occur through social engineering or URI hijacking and typically requires user action to grant access, such as through a system 'Open With' dialogue."
    T1409 = "Adversaries may try to access and collect application data resident on the device. Adversaries often target popular applications, such as Facebook, WeChat, and Gmail."
    T1632 = "Adversaries may undermine security controls that will either warn users of untrusted activity or prevent execution of untrusted applications. Operating systems and security products may contain mechanisms to identify programs or websites as possessing some level of trust. Examples of such features include: an app being allowed to run because it is signed by a valid code signing certificate; an OS prompt alerting the user that an app came from an untrusted source; or getting an indication that you are about to connect to an untrusted site. The method adversaries use will depend on the specific mechanism they seek to subvert."
    T1474 = "Adversaries may manipulate products or product delivery mechanisms prior to receipt by a final consumer for the purpose of data or system compromise."
    T1426 = "Adversaries may attempt to get detailed information about a device’s operating system and hardware, including versions, patches, and architecture. Adversaries may use the information from System Information Discovery during automated discovery to shape follow-on behaviors, including whether or not to fully infects the target and/or attempts specific actions."
    T1422 = "Adversaries may look for details about the network configuration and settings, such as IP and/or MAC addresses, of devices they access or through information discovery of remote systems."
    T1421 = "Adversaries may attempt to get a listing of network connections to or from the compromised device they are currently accessing or from remote systems by querying for information over the network."
    T1512 = "An adversary can leverage a device’s cameras to gather information by capturing video recordings. Images may also be captured, potentially in specified intervals, in lieu of video files."
    T1633 = "Adversaries may employ various means to detect and avoid virtualization and analysis environments. This may include changing behaviors after checking for the presence of artifacts indicative of a virtual machine environment (VME) or sandbox. If the adversary detects a VME, they may alter their malware’s behavior to disengage from the victim or conceal the core functions of the payload. They may also search for VME artifacts before dropping further payloads. Adversaries may use the information learned from Virtualization/Sandbox Evasion during automated discovery to shape follow-on behaviors."
    T1481 = "Adversaries may use an existing, legitimate external Web service as a means for relaying data to/from a compromised system. Popular websites and social media, acting as a mechanism for C2, may give a significant amount of cover. This is due to the likelihood that hosts within a network are already communicating with them prior to a compromise. Using common services, such as those offered by Google or Twitter, makes it easier for adversaries to hide in expected noise. Web service providers commonly use SSL/TLS encryption, giving adversaries an added level of protection."
    T0800 = "Adversaries may activate firmware update mode on devices to prevent expected response functions from engaging in reaction to an emergency or process malfunction. For example, devices such as protection relays may have an operation mode designed for firmware installation. This mode may halt process monitoring and related functions to allow new firmware to be loaded. A device left in update mode may be placed in an inactive holding state if no firmware is provided to it. By entering and leaving a device in this mode, the adversary may deny its usual functionalities."
    T0830 = "Adversaries with privileged network access may seek to modify network traffic in real time using adversary-in-the-middle (AiTM) attacks.  This type of attack allows the adversary to intercept traffic to and/or from a particular device on the network. If a AiTM attack is established, then the adversary has the ability to block, log, modify, or inject traffic into the communication stream. There are several ways to accomplish this attack, but some of the most-common are Address Resolution Protocol (ARP) poisoning and the use of a proxy."
    T0878 = "Adversaries may target protection function alarms to prevent them from notifying operators of critical conditions. Alarm messages may be a part of an overall reporting system and of particular interest for adversaries. Disruption of the alarm system does not imply the disruption of the reporting system as a whole."
    T0802 = "Adversaries may automate collection of industrial environment information using tools or scripts. This automated collection may leverage native control protocols and tools available in the control systems environment. For example, the OPC protocol may be used to enumerate and gather information. Access to a system or interface with these native protocols may allow collection and enumeration of other attached, communicating servers and devices."
    T0895 = "Adversaries may leverage AutoRun functionality or scripts to execute malicious code. Devices configured to enable AutoRun functionality or legacy operating systems may be susceptible to abuse of these features to run malicious code stored on various forms of removeable media (i.e., USB, Disk Images [.ISO]). Commonly, AutoRun or AutoPlay are disabled in many operating systems configurations to mitigate against this technique. If a device is configured to enable AutoRun or AutoPlay, adversaries may execute code on the device by mounting the removable media to the device, either through physical or virtual means. This may be especially relevant for virtual machine environments where disk images may be dynamically mapped to a guest system on a hypervisor."
    T0803 = "Adversaries may block a command message from reaching its intended target to prevent command execution. In OT networks, command messages are sent to provide instructions to control system devices. A blocked command message can inhibit response functions from correcting a disruption or unsafe condition."
    T0804 = "Adversaries may block or prevent a reporting message from reaching its intended target. In control systems, reporting messages contain telemetry data (e.g., I/O values) pertaining to the current state of equipment and the industrial process. By blocking these reporting messages, an adversary can potentially hide their actions from an operator."
    T0805 = "Adversaries may block access to serial COM to prevent instructions or configurations from reaching target devices. Serial Communication ports (COM) allow communication with control system devices. Devices can receive command and configuration messages over such serial COM. Devices also use serial COM to send command and reporting messages. Blocking device serial COM may also block command messages and block reporting messages."
    T0806 = "Adversaries may repetitively or successively change I/O point values to perform an action. Brute Force I/O may be achieved by changing either a range of I/O point values or a single point value repeatedly to manipulate a process function. The adversary's goal and the information they have about the target environment will influence which of the options they choose. In the case of brute forcing a range of point values, the adversary may be able to achieve an impact without targeting a specific point. In the case where a single point is targeted, the adversary may be able to generate instability on the process function associated with that particular point."
    T0892 = "Adversaries may modify software and device credentials to prevent operator and responder access. Depending on the device, the modification or addition of this password could prevent any device configuration actions from being accomplished and may require a factory reset or replacement of hardware. These credentials are often built-in features provided by the device vendors as a means to restrict access to management interfaces."
    T0858 = "Adversaries may change the operating mode of a controller to gain additional access to engineering functions such as Program Download.   Programmable controllers typically have several modes of operation that control the state of the user program and control access to the controllers API. Operating modes can be physically selected using a key switch on the face of the controller but may also be selected with calls to the controllers API. Operating modes and the mechanisms by which they are selected often vary by vendor and product line. Some commonly implemented operating modes are described below:"
    T0807 = "Adversaries may utilize command-line interfaces (CLIs) to interact with systems and execute commands. CLIs provide a means of interacting with computer systems and are a common feature across many types of platforms and devices within control systems environments.  Adversaries may also use CLIs to install and run new software, including malicious tools that may be installed over the course of an operation."
    T0885 = "Adversaries may communicate over a commonly used port to bypass firewalls or network detection systems and to blend in with normal network activity, to avoid more detailed inspection. They may use the protocol associated with the port, or a completely different protocol. They may use commonly open ports, such as the examples provided below."
    T0884 = "Adversaries may use a connection proxy to direct network traffic between systems or act as an intermediary for network communications."
    T0879 = "Adversaries may cause damage and destruction of property to infrastructure, equipment, and the surrounding environment when attacking control systems. This technique may result in device and operational equipment breakdown, or represent tangential damage from other techniques used in an attack. Depending on the severity of physical damage and disruption caused to control processes and systems, this technique may result in Loss of Safety. Operations that result in Loss of Control may also cause damage to property, which may be directly or indirectly motivated by an adversary seeking to cause impact in the form of Loss of Productivity and Revenue."
    T0809 = "Adversaries may perform data destruction over the course of an operation. The adversary may drop or create malware, tools, or other non-native files on a target system to accomplish this, potentially leaving behind traces of malicious activities. Such non-native files and other data may be removed over the course of an intrusion to maintain a small footprint or as a standard part of the post-intrusion cleanup process."
    T0811 = "Adversaries may target and collect data from information repositories. This can include sensitive data such as specifications, schematics, or diagrams of control system layouts, devices, and processes. Examples of information repositories include reference databases in the process environment, as well as databases in the corporate network that might contain information about the ICS."
    T0893 = "Adversaries may target and collect data from local system sources, such as file systems, configuration files, or local databases. This can include sensitive data such as specifications, schematics, or diagrams of control system layouts, devices, and processes."
    T0812 = "Adversaries may leverage manufacturer or supplier set default credentials on control system devices. These default credentials may have administrative permissions and may be necessary for initial configuration of the device. It is general best practice to change the passwords for these accounts as soon as possible, but some manufacturers may have devices that have passwords or usernames that cannot be changed."
    T0813 = "Adversaries may cause a denial of control to temporarily prevent operators and engineers from interacting with process controls. An adversary may attempt to deny process control access to cause a temporary loss of communication with the control device or to prevent operator adjustment of process controls. An affected process may still be operating during the period of control loss, but not necessarily in a desired state."
    T0814 = "Adversaries may perform Denial-of-Service (DoS) attacks to disrupt expected device functionality. Examples of DoS attacks include overwhelming the target device with a high volume of requests in a short time period and sending the target device a request it does not know how to handle. Disrupting device state may temporarily render it unresponsive, possibly lasting until a reboot can occur. When placed in this state, devices may be unable to send and receive requests, and may not perform expected response functions in reaction to other events in the environment."
    T0815 = "Adversaries may cause a denial of view in attempt to disrupt and prevent operator oversight on the status of an ICS environment. This may manifest itself as a temporary communication failure between a device and its control source, where the interface recovers and becomes available once the interference ceases."
    T0868 = "Adversaries may gather information about a PLCs or controllers current operating mode. Operating modes dictate what change or maintenance functions can be manipulated and are often controlled by a key switch on the PLC (e.g.,  run, prog [program], and remote). Knowledge of these states may be valuable to an adversary to determine if they are able to reprogram the PLC. Operating modes and the mechanisms by which they are selected often vary by vendor and product line. Some commonly implemented operating modes are described below:"
    T0816 = "Adversaries may forcibly restart or shutdown a device in an ICS environment to disrupt and potentially negatively impact physical processes. Methods of device restart and shutdown exist in some devices as built-in, standard functionalities. These functionalities can be executed using interactive device web interfaces, CLIs, and network protocol commands."
    T0817 = "Adversaries may gain access to a system during a drive-by compromise, when a user visits a website as part of a regular browsing session. With this technique, the user's web browser is targeted and exploited simply by visiting the compromised website."
    T0871 = "Adversaries may attempt to leverage Application Program Interfaces (APIs) used for communication between control software and the hardware. Specific functionality is often coded into APIs which can be called by software to engage specific functions on a device or other software."
    T0819 = "Adversaries may leverage weaknesses to exploit internet-facing software for initial access into an industrial network. Internet-facing software may be user applications, underlying networking implementations, an assets operating system, weak defenses, etc. Targets of this technique may be intentionally exposed for the purpose of remote management and visibility."
    T0820 = "Adversaries may exploit a software vulnerability to take advantage of a programming error in a program, service, or within the operating system software or kernel itself to evade detection. Vulnerabilities may exist in software that can be used to disable or circumvent security features."
    T0890 = "Adversaries may exploit software vulnerabilities in an attempt to elevate privileges. Exploitation of a software vulnerability occurs when an adversary takes advantage of a programming error in a program, service, or within the operating system software or kernel itself to execute adversary-controlled code. Security constructs such as permission levels will often hinder access to information and use of certain techniques, so adversaries will likely need to perform privilege escalation to include use of software exploitation to circumvent those restrictions."
    T0866 = "Adversaries may exploit a software vulnerability to take advantage of a programming error in a program, service, or within the operating system software or kernel itself to enable remote service abuse. A common goal for post-compromise exploitation of remote services is for initial access into and lateral movement throughout the ICS environment to enable access to targeted systems."
    T0822 = "Adversaries may leverage external remote services as a point of initial access into your network. These services allow users to connect to internal network resources from external locations. Examples are VPNs, Citrix, and other access mechanisms. Remote service gateways often manage connections and credential authentication for these services."
    T0823 = "Adversaries may attempt to gain access to a machine via a Graphical User Interface (GUI) to enhance execution capabilities. Access to a GUI allows a user to interact with a computer in a more visual manner than a CLI. A GUI allows users to move a cursor and click on interface objects, with a mouse and keyboard as the main input devices, as opposed to just using the keyboard."
    T0891 = "Adversaries may leverage credentials that are hardcoded in software or firmware to gain an unauthorized interactive user session to an asset. Examples credentials that may be hardcoded in an asset include:"
    T0874 = "Adversaries may hook into application programming interface (API) functions used by processes to redirect calls for execution and privilege escalation means. Windows processes often leverage these API functions to perform tasks that require reusable system resources. Windows API functions are typically stored in dynamic-link libraries (DLLs) as exported functions."
    T0877 = "Adversaries may seek to capture process values related to the inputs and outputs of a PLC. During the scan cycle, a PLC reads the status of all inputs and stores them in an image table.  The image table is the PLCs internal storage location where values of inputs/outputs for one scan are stored while it executes the user program. After the PLC has solved the entire logic program, it updates the output image table. The contents of this output image table are written to the corresponding output points in I/O Modules."
    T0872 = "Adversaries may attempt to remove indicators of their presence on a system in an effort to cover their tracks. In cases where an adversary may feel detection is imminent, they may try to overwrite, delete, or cover up changes they have made to the device."
    T0883 = "Adversaries may gain access into industrial environments through systems exposed directly to the internet for remote access rather than through External Remote Services. Internet Accessible Devices are exposed to the internet unintentionally or intentionally without adequate protections. This may allow for adversaries to move directly into the control system network. Access onto these devices is accomplished without the use of exploits, these would be represented within the Exploit Public-Facing Application technique."
    T0867 = "Adversaries may transfer tools or other files from one system to another to stage adversary tools or other files over the course of an operation.  Copying of files may also be performed laterally between internal victim systems to support Lateral Movement with remote Execution using inherent file sharing protocols such as file sharing over SMB to connected network shares."
    T0826 = "Adversaries may attempt to disrupt essential components or systems to prevent owner and operator from delivering products or services."
    T0827 = "Adversaries may seek to achieve a sustained loss of control or a runaway condition in which operators cannot issue any commands even if the malicious interference has subsided."
    T0828 = "Adversaries may cause loss of productivity and revenue through disruption and even damage to the availability and integrity of control system operations, devices, and related processes. This technique may manifest as a direct effect of an ICS-targeting attack or tangentially, due to an IT-targeting attack against non-segregated environments."
    T0837 = "Adversaries may compromise protective system functions designed to prevent the effects of faults and abnormal conditions. This can result in equipment damage, prolonged process disruptions and hazards to personnel."
    T0880 = "Adversaries may compromise safety system functions designed to maintain safe operation of a process when unacceptable or dangerous conditions occur. Safety systems are often composed of the same elements as control systems but have the sole purpose of ensuring the process fails in a predetermined safe manner."
    T0829 = "Adversaries may cause a sustained or permanent loss of view where the ICS equipment will require local, hands-on operator intervention; for instance, a restart or manual operation. By causing a sustained reporting or visibility loss, the adversary can effectively hide the present state of operations. This loss of view can occur without affecting the physical processes themselves."
    T0835 = "Adversaries may manipulate the I/O image of PLCs through various means to prevent them from functioning as expected. Methods of I/O image manipulation may include overriding the I/O table via direct memory manipulation or using the override function used for testing PLC programs.  During the scan cycle, a PLC reads the status of all inputs and stores them in an image table.  The image table is the PLCs internal storage location where values of inputs/outputs for one scan are stored while it executes the user program. After the PLC has solved the entire logic program, it updates the output image table. The contents of this output image table are written to the corresponding output points in I/O Modules."
    T0831 = "Adversaries may manipulate physical process control within the industrial environment. Methods of manipulating control can include changes to set point values, tags, or other parameters. Adversaries may manipulate control systems devices or possibly leverage their own, to communicate with and command physical control processes. The duration of manipulation may be temporary or longer sustained, depending on operator detection."
    T0832 = "Adversaries may attempt to manipulate the information reported back to operators or controllers. This manipulation may be short term or sustained. During this time the process itself could be in a much different state than what is reported."
    T0849 = "Adversaries may use masquerading to disguise a malicious application or executable as another file, to avoid operator and engineer suspicion. Possible disguises of these masquerading files can include commonly found programs, expected vendor executables and configuration files, and other commonplace application and naming conventions. By impersonating expected and vendor-relevant files and applications, operators and engineers may not notice the presence of the underlying malicious content and possibly end up running those masquerading as legitimate functions."
    T0838 = "Adversaries may modify alarm settings to prevent alerts that may inform operators of their presence or to prevent responses to dangerous and unintended scenarios. Reporting messages are a standard part of data acquisition in control systems. Reporting messages are used as a way to transmit system state information and acknowledgements that specific actions have occurred. These messages provide vital information for the management of a physical process, and keep operators, engineers, and administrators aware of the state of system devices and physical processes."
    T0821 = "Adversaries may modify the tasking of a controller to allow for the execution of their own programs. This can allow an adversary to manipulate the execution flow and behavior of a controller."
    T0836 = "Adversaries may modify parameters used to instruct industrial control system devices. These devices operate via programs that dictate how and when to perform actions based on such parameters. Such parameters can determine the extent to which an action is performed and may specify additional options. For example, a program on a control system device dictating motor processes may take a parameter defining the total number of seconds to run that motor."
    T0889 = "Adversaries may modify or add a program on a controller to affect how it interacts with the physical process, peripheral devices and other hosts on the network. Modification to controller programs can be accomplished using a Program Download in addition to other types of program modification such as online edit and program append."
    T0839 = "Adversaries may install malicious or vulnerable firmware onto modular hardware devices. Control system devices often contain modular hardware devices. These devices may have their own set of firmware that is separate from the firmware of the main control system equipment."
    T0801 = "Adversaries may gather information about the physical process state. This information may be used to gain more information about the process itself or used as a trigger for malicious actions. The sources of process state information may vary such as, OPC tags, historian data, specific PLC block information, or network traffic."
    T0834 = "Adversaries may directly interact with the native OS application programming interface (API) to access system functions. Native APIs provide a controlled means of calling low-level OS services within the kernel, such as those involving hardware/devices, memory, and processes.  These native APIs are leveraged by the OS during system boot (when other system components are not yet initialized) as well as carrying out tasks and requests during routine operations."
    T0840 = "Adversaries may perform network connection enumeration to discover information about device communication patterns. If an adversary can inspect the state of a network connection with tools, such as Netstat, in conjunction with System Firmware, then they can determine the role of certain devices on the network  . The adversary can also use Network Sniffing to watch network traffic for details about the source, destination, protocol, and content."
    T0842 = "Network sniffing is the practice of using a network interface on a computer system to monitor or capture information  regardless of whether it is the specified destination for the information."
    T0861 = "Adversaries may collect point and tag values to gain a more comprehensive understanding of the process environment. Points may be values such as inputs, memory locations, outputs or other process specific variables.  Tags are the identifiers given to points for operator convenience."
    T0843 = "Adversaries may perform a program download to transfer a user program to a controller."
    T0845 = "Adversaries may attempt to upload a program from a PLC to gather information about an industrial process. Uploading a program may allow them to acquire and study the underlying logic. Methods of program upload include vendor software, which enables the user to upload and read a program running on a PLC. This software can be used to upload the target program to a workstation, jump box, or an interfacing device."
    T0873 = "Adversaries may attempt to infect project files with malicious code. These project files may consist of objects, program organization units, variables such as tags, documentation, and other configurations needed for PLC programs to function.  Using built in functions of the engineering software, adversaries may be able to download an infected program to a PLC in the operating environment enabling further Execution and Persistence techniques."
    T0886 = "Adversaries may leverage remote services to move between assets and network segments. These services are often used to allow operators to interact with systems remotely within the network, some examples are RDP, SMB, SSH, and other similar mechanisms."
    T0846 = "Adversaries may attempt to get a listing of other systems by IP address, hostname, or other logical identifier on a network that may be used for subsequent Lateral Movement or Discovery techniques. Functionality could exist within adversary tools to enable this, but utilities available on the operating system or vendor software could also be used."
    T0888 = "An adversary may attempt to get detailed information about remote systems and their peripherals, such as make/model, role, and configuration. Adversaries may use information from Remote System Information Discovery to aid in targeting and shaping follow-on behaviors. For example, the system's operational role and model information can dictate whether it is a relevant target for the adversary's operational objectives. In addition, the system's configuration may be used to scope subsequent technique usage."
    T0847 = "Adversaries may move onto systems, such as those separated from the enterprise network, by copying malware to removable media which is inserted into the control systems environment. The adversary may rely on unknowing trusted third parties, such as suppliers or contractors with access privileges, to introduce the removable media. This technique enables initial access to target devices that never connect to untrusted networks, but are physically accessible."
    T0848 = "Adversaries may setup a rogue master to leverage control server functions to communicate with outstations. A rogue master can be used to send legitimate control messages to other control system devices, affecting processes in unintended ways. It may also be used to disrupt network communications by capturing and receiving the network traffic meant for the actual master. Impersonating a master may also allow an adversary to avoid detection."
    T0851 = "Adversaries may deploy rootkits to hide the presence of programs, files, network connections, services, drivers, and other system components. Rootkits are programs that hide the existence of malware by intercepting and modifying operating-system API calls that supply system information. Rootkits or rootkit-enabling functionality may reside at the user or kernel level in the operating system, or lower."
    T0852 = "Adversaries may attempt to perform screen capture of devices in the control system environment. Screenshots may be taken of workstations, HMIs, or other devices that display environment-relevant process, device, reporting, alarm, or related data. These device displays may reveal information regarding the ICS process, layout, control, and related schematics. In particular, an HMI can provide a lot of important industrial process information.  Analysis of screen captures may provide the adversary with an understanding of intended operations and interactions between critical devices."
    T0853 = "Adversaries may use scripting languages to execute arbitrary code in the form of a pre-written script or in the form of user-supplied code to an interpreter. Scripting languages are programming languages that differ from compiled languages, in that scripting languages use an interpreter, instead of a compiler. These interpreters read and compile part of the source code just before it is executed, as opposed to compilers, which compile each and every line of code to an executable file. Scripting allows software developers to run their code on any system where the interpreter exists. This way, they can distribute one package, instead of precompiling executables for many different systems. Scripting languages, such as Python, have their interpreters shipped as a default with many Linux distributions."
    T0881 = "Adversaries may stop or disable services on a system to render those services unavailable to legitimate users. Stopping critical services can inhibit or stop response to an incident or aid in the adversary's overall objectives to cause damage to the environment.   Services may not allow for modification of their data stores while running. Adversaries may stop services in order to conduct Data Destruction."
    T0865 = "Adversaries may use a spearphishing attachment, a variant of spearphishing, as a form of a social engineering attack against specific targets. Spearphishing attachments are different from other forms of spearphishing in that they employ malware attached to an email. All forms of spearphishing are electronically delivered and target a specific individual, company, or industry. In this scenario, adversaries attach a file to the spearphishing email and usually rely upon User Execution to gain execution and access."
    T0856 = "Adversaries may spoof reporting messages in control system environments for evasion and to impair process control. In control systems, reporting messages contain telemetry data (e.g., I/O values) pertaining to the current state of equipment and the industrial process. Reporting messages are important for monitoring the normal operation of a system or identifying important events such as deviations from expected values."
    T0869 = "Adversaries may establish command and control capabilities over commonly used application layer protocols such as HTTP(S), OPC, RDP, telnet, DNP3, and modbus. These protocols may be used to disguise adversary actions as benign network traffic. Standard protocols may be seen on their associated port or in some cases over a non-standard port.  Adversaries may use these protocols to reach out of the network for command and control, or in some cases to other infected devices within the network."
    T0862 = "Adversaries may perform supply chain compromise to gain control systems environment access by means of infected products, software, and workflows. Supply chain compromise is the manipulation of products, such as devices or software, or their delivery mechanisms before receipt by the end consumer. Adversary compromise of these products and mechanisms is done for the goal of data or system compromise, once infected products are introduced to the target environment."
    T0894 = "Adversaries may bypass process and/or signature-based defenses by proxying execution of malicious content with signed, or otherwise trusted, binaries. Binaries used in this technique are often Microsoft-signed files, indicating that they have been either downloaded from Microsoft or are already native in the operating system.  Binaries signed with trusted digital certificates can typically execute on Windows systems protected by digital signature validation. Several Microsoft signed binaries that are default on Windows installations can be used to proxy execution of other files or commands. Similarly, on Linux systems adversaries may abuse trusted binaries such as split to proxy execution of malicious commands."
    T0857 = "System firmware on modern assets is often designed with an update feature. Older device firmware may be factory installed and require special reprograming equipment. When available, the firmware update feature enables vendors to remotely patch bugs and perform upgrades. Device firmware updates are often delegated to the user and may be done using a software update package. It may also be possible to perform this task over the network."
    T0882 = "Adversaries may steal operational information on a production environment as a direct mission outcome for personal gain or to inform future operations. This information may include design documents, schedules, rotational data, or similar artifacts that provide insight on operations.    In the Bowman Dam incident, adversaries probed systems for operational data."
    T0864 = "Adversaries may target devices that are transient across ICS networks and external networks. Normally, transient assets are brought into an environment by authorized personnel and do not remain in that environment on a permanent basis.  Transient assets are commonly needed to support management functions and may be more common in systems where a remotely managed asset is not feasible, external connections for remote access do not exist, or 3rd party contractor/vendor access is required."
    T0855 = "Adversaries may send unauthorized command messages to instruct control system assets to perform actions outside of their intended functionality, or without the logical preconditions to trigger their expected function. Command messages are used in ICS networks to give direct instructions to control systems devices. If an adversary can send an unauthorized command message to a control system, then it can instruct the control systems device to perform an action outside the normal bounds of the device's actions. An adversary could potentially instruct a control systems device to perform an action that will cause an Impact."
    T0863 = "Adversaries may rely on a targeted organizations user interaction for the execution of malicious code. User interaction may consist of installing applications, opening email attachments, or granting higher permissions to documents."
    T0859 = "Adversaries may steal the credentials of a specific user or service account using credential access techniques. In some cases, default credentials for control system devices may be publicly available. Compromised credentials may be used to bypass access controls placed on various resources on hosts and within the network, and may even be used for persistent access to remote systems. Compromised and default credentials may also grant an adversary increased privilege to specific systems and devices or access to restricted areas of the network. Adversaries may choose not to use malware or tools, in conjunction with the legitimate access those credentials provide, to make it harder to detect their presence or to control devices and send legitimate commands in an unintended way."
    T0860 = "Adversaries may perform wireless compromise as a method of gaining communications and unauthorized access to a wireless network. Access to a wireless network may be gained through the compromise of a wireless device.   Adversaries may also utilize radios and other wireless communication devices on the same frequency as the wireless network. Wireless compromise can be done as an initial access vector from a remote distance."
    T0887 = "Adversaries may seek to capture radio frequency (RF) communication used for remote control and reporting in distributed environments. RF communication frequencies vary between 3 kHz to 300 GHz, although are commonly between 300 MHz to 6 GHz.   The wavelength and frequency of the signal affect how the signal propagates through open air, obstacles (e.g. walls and trees) and the type of radio required to capture them. These characteristics are often standardized in the protocol and hardware and may have an effect on how the signal is captured. Some examples of wireless protocols that may be found in cyber-physical environments are: WirelessHART, Zigbee, WIA-FA, and 700 MHz Public Safety Spectrum."
}

Function Add-AllMitre ( $workbook) {

    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "MITRE Coverage"

    Write-Host "MITRE coverage: " -NoNewline
    
    $row = 1
    $worksheet.Cells.Item($row, 1) = "Tactic"
    $worksheet.Cells.Item($row, 2) = "Tactic Description"
    $worksheet.Cells.Item($row, 3) = "Technique"
    $worksheet.Cells.Item($row, 4) = "Count"
    $worksheet.Cells.Item($row, 5) = "Name"
    $worksheet.Cells.Item($row, 6) = "Description"
    $row++

    try {

        $url = $baseUrl + "securityMLAnalyticsSettings?api-version=2022-05-01-preview"
        $anomalyRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
        Write-Host("Anomoly Rules: " + $anomalyRules.count)

        $url = $baseUrl + "alertrules?api-version=2023-12-01-preview"
        $analyticRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
        Write-Host ("Analytic Rules: " + $analyticRules.count)

        #Determine the count for tactics and techniques
        foreach ($rule in $anomalyRules) {
            $tactics = $rule.properties.tactics
            $techniques = $rule.properties.techniques
            foreach ($tactic in  $tactics) {
                foreach ($technique in $techniques) {
                    if ($tacticsAndTechniques[$tactic].Contains($technique)) {
                        $tacticsAndTechniques[$tactic][$technique] += 1
                    }
                }
            }
        }
        foreach ($rule in $analyticRules) {
            $tactics = $rule.properties.tactics
            $techniques = $rule.properties.techniques
            foreach ($tactic in  $tactics) {
                foreach ($technique in $techniques) {
                    if ($tacticsAndTechniques[$tactic].Contains($technique)) {
                        $tacticsAndTechniques[$tactic][$technique] += 1
                    }
                }
            }
        }

        $StatusBox.text += "MITRE entries (236): "


        foreach ($tactic in $tacticsAndTechniques.Keys) {
            $StatusBox.text += "."
            $worksheet.Cells.Item($row, 1) = $tacticNameHash[$tactic]
            $worksheet.Cells.Item($row, 2) = $tacticDescriptionHash[$tactic]
            $row++

            foreach ($technique in $tacticsAndTechniques[$tactic].Keys) {
                if ("none" -eq $technique) {
                    $worksheet.Cells.Item($row, 3) = "none selected"
                    $worksheet.Cells.Item($row, 4) = $tacticsAndTechniques[$tactic][$technique]
                    $worksheet.Cells.Item($row, 5) = "No technique selected"
                    $worksheet.Cells.Item($row, 6) = "No description available"
                    $row++
                }
                else {
                    $worksheet.Cells.Item($row, 3) = $technique
                    $worksheet.Cells.Item($row, 4) = $tacticsAndTechniques[$tactic][$technique]
                    $worksheet.Cells.Item($row, 5) = $techniqueNameHash[$technique] 
                    $worksheet.Cells.Item($row, 6) = $techniqueDescriptionHash[$technique] 
                    $row++
                }
            
            }

        }

        $worksheet = $workbook.Worksheets.Add()
        $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
        $worksheet.Name = "MITRE Grid"

        $column = 0
        foreach ($tactic in $tacticsAndTechniques.Keys) {
            $row = 1
            $column++
            $StatusBox.text += "."
            $worksheet.Cells.Item($row, $column) = $tacticNameHash[$tactic]
            $row++

            foreach ($technique in $tacticsAndTechniques[$tactic].Keys) {
                if ("none" -ne $technique) {
                    $countLength = [string]$tacticsAndTechniques[$tactic][$technique].length
                    $worksheet.Cells.Item($row, $column) = [string]$tacticsAndTechniques[$tactic][$technique] + "`r`n" + $technique
                    $cell = $worksheet.Cells.Item($row, $column)
                    #Mark the count as bold
                    $cell.Characters(0, $countLength).Font.Bold = $true
                    # $columnLetter = Convert-ColumnNumberToLetter($column)
                    # Write-Host ($columnLetter + [string]$row)
                    # $selectCell = $worksheet.Range($columnLetter + [string]$row)
                    # $validation = $selectCell.validation
                    # $validation.Delete()
                    # $validation.Add(3, 1, 1, "Option1")
                    # $validation.InputTitle = $techniqueNameHash[$technique] 
                    # $validation.InputMessage = $techniqueDescriptionHash[$technique] 
                    $row++
                }
            }
        }
    
        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering MITRE: " + $errorReturn
        $StatusBox.text += "`r`n"

    }
}

function Convert-ColumnNumberToLetter {
    param (
        [int]$ColumnNumber
    )
    $ColumnLetter = ""
    while ($ColumnNumber -gt 0) {
        $ColumnNumber--
        $ColumnLetter = [char](65 + ($ColumnNumber % 26)) + $ColumnLetter
        $ColumnNumber = [math]::Floor($ColumnNumber / 26)
    }
    return $ColumnLetter
}

# Example usage
$ColumnNumber = 28
$ColumnLetter = Convert-ColumnNumberToLetter -ColumnNumber $ColumnNumber
Write-Output "Column $ColumnNumber corresponds to letter $ColumnLetter"

Function Add-AllAutomation ($analyticRules, $worksheet) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Automation Rules"

    Write-Host "Automation Rules: " -NoNewline
    

    try {

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Order"
        $worksheet.Cells.Item($row, 2) = "Display Name"
        $worksheet.Cells.Item($row, 3) = "Trigger"
        $worksheet.Cells.Item($row, 4) = "Analytic Rule Name"
        $worksheet.Cells.Item($row, 5) = "Actions"
        $worksheet.Cells.Item($row, 5) = "Expiration Date"
        $row++

        $url = $baseUrl + "automationRules" + $apiVersion
        $automationRules = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "Automation Rules (" + $automationRules.count + "): "

        
        $count = 1
        foreach ($automationRule in $automationRules | Sort-Object { $_.properties.order }) {
            $count++
            $worksheet.Cells.Item($row, 1) = $automationRule.properties.order.toString()
            $worksheet.Cells.Item($row, 2) = $automationRule.properties.displayName
            $trigger = $automationRule.properties.triggeringLogic.triggersOn + " " + $automationRule.properties.triggeringLogic.triggersWhen
            $worksheet.Cells.Item($row, 3) = $trigger
            if ($automationRule.properties.triggeringLogic.conditions[0].conditionProperties.propertyName -eq "IncidentRelatedAnalyticRuleIds") {
                $ruleNames = ""
                foreach ($rule in $automationRule.properties.triggeringLogic.conditions[0].conditionProperties.propertyValues) {
                    $ruleDescription = ($analyticRules | Where-Object -Property Id -eq $rule).properties.displayName
                    $ruleNames += $ruleDescription + "`n"
                }
                $worksheet.Cells.Item($row, 4) = $ruleNames
            }
            else {
                $worksheet.Cells.Item($row, 4) = "All"
            }
            Write-Host "." -NoNewline
            $StatusBox.text += "."
        
            $worksheet.Cells.Item($row, 5) = $automationRule.properties.displayNAme
            $expiration = $automationRule.properties.expirationTimeUtc
            if ($null -eq $expiration) {
                $worksheet.Cells.Item($row, 6) = "Indefinite"
            }
            else {
                $worksheet.Cells.Item($row, 6) = $expiration.toString()
            }
            $row++
        }
        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Automation Rules: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllPlaybooks ($workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Playbooks"

    Write-Host "Playbooks: " -NoNewline
    
    try {

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Status"
        $worksheet.Cells.Item($row, 3) = "Plan"
        $worksheet.Cells.Item($row, 4) = "Trigger kind"
        $worksheet.Cells.Item($row, 5) = "Resource Group"
        $worksheet.Cells.Item($row, 6) = "Tags"
        $row++

        $body = @{
            "query"         = "Resources  | where type in~ ('Microsoft.Logic/workflows') | project id, name, type, location, properties, tags, kind"
            "subscriptions" = @("$SubscriptionId")
        } 

        $url = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2019-04-01"
        $consumptionPlaybooks = Invoke-RestMethod -Method "POST" -Uri $url -Headers $authHeader  -Body ($body | ConvertTo-Json -EnumsAsStrings -Depth 5)

        $body = @{
            "query"         = "AppServiceResources| where type in~ ('microsoft.web/sites/workflows') | project id, name, type, location, properties, tags, kind"
            "subscriptions" = @("$SubscriptionId")
        } 
        $standardPlaybooks = Invoke-RestMethod -Method "POST" -Uri $url -Headers $authHeader  -Body ($body | ConvertTo-Json -EnumsAsStrings -Depth 5)

        # $url = $baseUrl + "contenttemplates?api-version=2023-04-01-preview&%24filter=(properties%2FcontentKind%20eq%20'Playbook')"
        # $playbookTemplates = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "Playbooks (" + ($consumptionPlaybooks.data.rows.count + $standardPlaybooks.count ) + "): "

        foreach ($playbook in $consumptionPlaybooks.data.rows) {
            #We only want playbooks
            if ($playbook[4].definition.triggers -match "Microsoft_Sentinel") {
                $worksheet.Cells.Item($row, 1) = $playbook[1]
                $worksheet.Cells.Item($row, 2) = $playbook[4].state
                $worksheet.Cells.Item($row, 3) = "Consumption"
                
                $triggers = $playbook[4].definition.triggers | ConvertTo-Json -Depth 5 | ConvertFrom-Json
                $triggerKey = $triggers.PSObject.Properties.Name
               
                switch ($triggerKey) {
                    "Microsoft_Sentinel_incident" { $worksheet.Cells.Item($row, 4) = "Microsoft Sentinel Incident" }
                    "Microsoft_Sentinel_alert" { $worksheet.Cells.Item($row, 4) = "Microsoft Sentinel Alert" }
                    "Microsoft_Sentinel_entity" { $worksheet.Cells.Item($row, 4) = "Microsoft Sentinel Entity" }
                    Default { $worksheet.Cells.Item($row, 4) = "Unknown" }
                }
                $worksheet.Cells.Item($row, 5) = $playbook[0].split('/')[4]
                
                if ($null -ne $playbook[5]) {
                    $tags = $playbook[5] | ConvertTo-Json | ConvertFrom-Json
                    $keys = $tags.PSObject.Properties.Name
                    $values = $tags.PSObject.Properties.Value
                    for ($i = 0; $i -le $keys.count - 1; $i++) {
                        if ($keys[$i] -notmatch "hidden") {
                            $worksheet.Cells.Item($row, 6) = ($keys[$i] + ": " + $values[$i])
                            if ($i -ne $keys.count - 1) {
                                $row++
                            }
                        }
                    }
                }
                $row++
                $StatusBox.text += "."
            }
        }

        foreach ($playbook in $standardPlaybooks.data.rows) {
            #We only want playbooks
            if ($playbook[4].Files."workflow.json".definition.triggers -match "Microsoft_Sentinel") {
                $worksheet.Cells.Item($row, 1) = $playbook[1]
                $worksheet.Cells.Item($row, 2) = $playbook[4].FlowState
                $worksheet.Cells.Item($row, 3) = "Standard"
               
                $triggers = $playbook[4].Files."workflow.json".definition.triggers | ConvertTo-Json -Depth 5 | ConvertFrom-Json
                $triggerKey = $triggers.PSObject.Properties.Name
                switch ($triggerKey) {
                    "Microsoft_Sentinel_incident" { $worksheet.Cells.Item($row, 4) = "Microsoft Sentinel Incident" }
                    "Microsoft_Sentinel_alert" { $worksheet.Cells.Item($row, 4) = "Microsoft Sentinel Alert" }
                    "Microsoft_Sentinel_entity" { $worksheet.Cells.Item($row, 4) = "Microsoft Sentinel Entity" }
                    Default { $worksheet.Cells.Item($row, 4) = "Unknown" }
                }
                $worksheet.Cells.Item($row, 5) = $playbook[0].split('/')[4]
                
                if ($null -ne $playbook[5]) {
                    $tags = $playbook[5] | ConvertTo-Json | ConvertFrom-Json
                    $keys = $tags.PSObject.Properties.Name
                    $values = $tags.PSObject.Properties.Value
                    for ($i = 0; $i -le $keys.count - 1; $i++) {
                        if ($keys[$i] -notmatch "hidden") {
                            $worksheet.Cells.Item($row, 6) = ( $keys[$i] + ": " + $values[$i])
                            if ($i -ne $keys.count - 1) {
                                $row++
                            }
                        }
                    }
                }
                $row++
                $StatusBox.text += "."
            }
        }

        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Playbooks: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllWatchlists ($workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Watchlists"

    Write-Host "Watchlists: " -NoNewline

    try {
        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Alias"
        $worksheet.Cells.Item($row, 3) = "Source"
        $worksheet.Cells.Item($row, 4) = "Created Time"
        $worksheet.Cells.Item($row, 5) = "Last Updated"
        $row++

        $url = $baseUrl + "watchlists" + $apiVersion
        $watchlists = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "Watchlists (" + $watchlists.count + "): "

        $count = 1
        foreach ($watchlist in $watchlists | Sort-Object { $_.properties.displayName }) {
            $count++
            Write-Host "." -NoNewline

            $StatusBox.text += "."
            $worksheet.Cells.Item($row, 1) = $watchlist.properties.displayName
            $worksheet.Cells.Item($row, 2) = $watchlist.properties.watchlistAlias
            $worksheet.Cells.Item($row, 3) = $watchlist.properties.source
            $worksheet.Cells.Item($row, 4) = $watchlist.properties.created.toString()
            $worksheet.Cells.Item($row, 5) = $watchlist.properties.updated.toString()
            $row++
        }
        Write-Host " "
        $StatusBox.text += "`r`n"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Watchlists: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllAnalyticRules ($analyticRules, $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Analytic Rules"

    try {
        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Severity"
        $worksheet.Cells.Item($row, 3) = "Rule Type"
        $worksheet.Cells.Item($row, 4) = "Status"
        $worksheet.Cells.Item($row, 5) = "Tactics & Techniques"
        $row++

        Write-Host "Analytic Rules: " -NoNewline
        $StatusBox.text += "Analytic Rule (" + $analyticRules.count + "): "

        foreach ($analyticRule in $analyticRules) {
            $worksheet.Cells.Item($row, 1) = $analyticRule.properties.displayName
            $worksheet.Cells.Item($row, 2) = $analyticRule.properties.Severity
            $worksheet.Cells.Item($row, 3) = $analyticRule.kind
            
            if ($analyticRule.properties.enabled -eq "True") {
                $worksheet.Cells.Item($row, 4) = "Enabled"
            }
            else {
                $worksheet.Cells.Item($row, 4) = "Disabled"
            }
           
            
            foreach ($tactic in $analyticRule.properties.tactics) {
                $found = $false
                $tacticRow = $tacticsAndTechniques[$tactic]
                foreach ($technique in $analyticRule.properties.Techniques) {
                    if ($null -ne $tacticRow[$technique]) {
                        $worksheet.Cells.Item($row, 5) = $tactic + " - " + $technique
                        $row++
                        $found = $true
                    }
                }
                if (!$found) {
                    $worksheet.Cells.Item($row, 5) = $tactic 
                    $row++
                }
            }
            
            Write-Host "." -NoNewline
            $StatusBox.text += "."
        }
        Write-Host " "
        $StatusBox.text += "`r`n"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Analytic Rules: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllDataConnectors ($solutions, $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Data Connectors"

    Write-Host "Data Connectors: " -NoNewline
    try {

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $row++

        $url = $baseUrl + "dataConnectors" + $apiVersion
        $dataConnectors = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "Data Connectors (" + $dataConnectors.count + "): "
        #Doing some translations
        foreach ($dataConnector in $dataConnectors) {
            if ($dataConnector.properties.connectorUiConfig.title -eq "Office 365") {
                $dataConnector.properties.connectorUiConfig.title = "Microsoft 365 (formerly, Office 365)"
            }
            if ($dataConnector.properties.connectorUiConfig.title -eq "SAP") {
                $dataConnector.properties.connectorUiConfig.title = "Microsoft Sentinel for SAP"
            }

        }
        foreach ($dataConnector in $dataConnectors | Sort-Object { $_.properties.connectorUiConfig.title }) {
            if ($null -ne $dataConnector.Properties.connectorUiConfig.title) {
                $worksheet.Cells.Item($row, 1) = $dataConnector.Properties.connectorUiConfig.title
                $row++
                Write-Host "." -NoNewline
                $StatusBox.text += "."
            }
        }
        Write-Host ""
        $StatusBox.text += "`r`n"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Data Connectors: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllRepositories ($workbook) {
    $url = $baseUrl + "sourcecontrols" + $apiVersion
    $repos = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Repositories"

    try {

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Description"
        $worksheet.Cells.Item($row, 3) = "Source Control"
        $worksheet.Cells.Item($row, 4) = "Repository URL"
        $worksheet.Cells.Item($row, 5) = "Deploy Analytic Rules"
        $worksheet.Cells.Item($row, 6) = "Deploy Automation Rules"
        $worksheet.Cells.Item($row, 7) = "Deploy Hunting Queries"
        $worksheet.Cells.Item($row, 8) = "Deploy Parsers"
        $worksheet.Cells.Item($row, 9) = "Deploy Playbooks"
        $worksheet.Cells.Item($row, 10) = "Deploy Workbooks"
        $row++
        Write-Host "Repositories: " -NoNewline
        $StatusBox.text += "Repositories: "

        foreach ($repo in $repos) {
            $worksheet.Cells.Item($row, 1) = $repo.properties.displayName
            $worksheet.Cells.Item($row, 2) = $repo.properties.description
            $worksheet.Cells.Item($row, 3) = $repo.properties.repoType
            $worksheet.Cells.Item($row, 4) = $repo.properties.repository.url
            
            $itemStatus = @{
                "AnalyticsRule"  = "No"
                "AutomationRule" = "No"
                "HuntingQuery"   = "No"
                "Parser"         = "No"
                "Playbook"       = "No"
                "Workbook"       = "No"
            }
            foreach ($type in $repo.properties.contentTypes) {
                $itemStatus[$type] = "Yes"

            }
            $worksheet.Cells.Item($row, 5) = $itemStatus["AnalyticsRule"]
            $worksheet.Cells.Item($row, 6) = $itemStatus["AutomationRule"]
            $worksheet.Cells.Item($row, 7) = $itemStatus["HuntingQuery"]
            $worksheet.Cells.Item($row, 8) = $itemStatus["Parser"]
            $worksheet.Cells.Item($row, 9) = $itemStatus["Playbook"]
            $worksheet.Cells.Item($row, 10) = $itemStatus["Workbook"]
            $row++

            Write-Host "." -NoNewline
            $StatusBox.text += "."
        }
        Write-Host " "
        $StatusBox.text += "`r`n"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Repositories: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllHunts($workook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Hunts"

    $url = $baseUrl + "hunts" + $apiVersion
    $hunts = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

    try {
        Write-Host "Hunts: " -NoNewline
        $StatusBox.text += "Hunts (" + $hunts.count + "): "

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Description"
        $worksheet.Cells.Item($row, 3) = "Status"
        $worksheet.Cells.Item($row, 4) = "Hypothesis"
        $worksheet.Cells.Item($row, 5) = "Assigned To"
        $row++

        foreach ($hunt in $hunts | Sort-Object { $_.properties.displayName }) {
            $worksheet.Cells.Item($row, 1) = $hunt.properties.displayName
            $worksheet.Cells.Item($row, 2) = $hunt.properties.description
            $worksheet.Cells.Item($row, 3) = $hunt.properties.status
            $worksheet.Cells.Item($row, 4) = $hunt.properties.hypothesisStatus
            #$row++
            if ($null -ne $hunt.properties.owner.assignedTo) {
                $worksheet.Cells.Item($row, 1) = $hunt.properties.owner.assignedTo
            }
            else {
                $worksheet.Cells.Item($row, 1) = "<unassigned>"
            }
            Write-Host "." -NoNewline
            $StatusBox.text += "."
            $row++
        }
        Write-Host ""
        $StatusBox.text += "`r`n"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Hunts: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllWorkbooks ( $metadata, $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Custom Workbooks"


    Write-Host "Custom Workbooks: " -NoNewline
    try {
        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Source"
        $row++
        #Show "MyWorkbooks"
        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/workbooks?api-version=2018-06-17-preview&canFetchContent=false&%24filter=sourceId%20eq%20'%2Fsubscriptions%2F$SubscriptionId%2Fresourcegroups%2F$ResourceGroupName%2Fproviders%2Fmicrosoft.operationalinsights%2Fworkspaces%2F$WorkspaceName'&category=sentinel"
        $customWorkbooks = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value

        $StatusBox.text += "My Workbooks (" + $customWorkbooks.count + "): "
   
        foreach ($singleBook in $customWorkbooks | Sort-Object { $_.properties.displayName }) {
            $worksheet.Cells.Item($row, 1) = $singleBook.properties.displayName
           
            $foundTemplate = $metadata | Where-Object { $_.name -eq "workbook-" + $singleBook.name }
            if ($null -ne $foundTemplate) {
                $worksheet.Cells.Item($row, 2) = $foundTemplate.properties.source.name
            }
            else {
                $worksheet.Cells.Item($row, 2) = "Custom"
            }
            Write-Host "." -NoNewline
            $StatusBox.text += "."
            $row++
        }

        $worksheet = $workbook.Worksheets.Add()
        $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
        $worksheet.Name = "Workbook Templates"

        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Source"
        $row++

        $StatusBox.text += "`r`n"

        Write-Host " " 
        Write-Host "Workbook Templates: " -NoNewline

        #Show Templates
        #Filter to get only the workbook tempalates
        $url = $baseUrl + "/contenttemplates?api-version=2023-10-01-preview&%24filter=(properties%2FcontentKind%20eq%20'Workbook')"
        #$workbookTemplates = $solutionTemplates | Where-Object { $_.properties.contentKind -eq "Workbook" }
        $workbookTemplates = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
    
        $StatusBox.text += "Workbook Templates (" + $workbookTemplates.count + "): "

        #Go through all the workbook templates in alphabetical order
        foreach ($singleTemplate in $workbookTemplates | Sort-Object { $_.properties.displayName }) {
            
            $worksheet.Cells.Item($row, 1) = $singleTemplate.properties.displayName
            $worksheet.Cells.Item($row, 2) = $singleTemplate.properties.packageKind
            
            Write-Host "." -NoNewline
            $StatusBox.text += "."
            $row++
        }
        Write-Host ""
        $StatusBox.text += "`r`n"
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Workbooks: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Add-AllSolutions($solutions, $workbook) {
    $worksheet = $workbook.Worksheets.Add()
    $worksheet.Move([System.Type]::Missing, $worksheets.Item($worksheets.Count))
    $worksheet.Name = "Installed Solutions"

    
    try {
        $row = 1
        $worksheet.Cells.Item($row, 1) = "Name"
        $worksheet.Cells.Item($row, 2) = "Version"
        $worksheet.Cells.Item($row, 3) = "Type"
        $worksheet.Cells.Item($row, 4) = "Short Description"
        $worksheet.Cells.Item($row, 5) = "Data Connectors"
        $worksheet.Cells.Item($row, 6) = "Workbooks"
        $worksheet.Cells.Item($row, 7) = "Analytic Rules"
        $worksheet.Cells.Item($row, 8) = "Hunting Queries"
        $worksheet.Cells.Item($row, 9) = "Azure Functions "
        $worksheet.Cells.Item($row, 10) = "Playbooks"
        $worksheet.Cells.Item($row, 11) = "Parsers"
        $row++

        Write-Host "Solutions: " -NoNewline
        $StatusBox.text += "Solutions: (" + $solutions.count + "): "
        
        #Just used for testing and to show how many solutions we have worked on
        $count = 1
        #Go through and get each solution alphabetically
        foreach ($solution in $solutions | Sort-Object { $_.properties.displayName }) {
            Write-Host "." -NoNewline
            $StatusBox.text += "."
            Add-SingleSolution $solution $worksheet     #Load one solution
            $count = $count + 1
            $row++
            <# }
    else {
        break;
    }  #>
        }
        $StatusBox.text += "`r`n"
        Write-Host ""
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering Solutions: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

#Work with a single solutions
Function Add-SingleSolution ($solution, $worksheet) {

    try {
        #We need to load the solution's template information, which is stored in a separate file.  Note that
        #some solutions have multiple plans associated with them and we will only work with the first one.
        # $uri = $baseUrl + "contentPackages/" + $solution.contentId + $apiVersion
        # $solutionData = (Invoke-RestMethod -Method "Get" -Uri $uri -Headers $authHeader ).value
        #Load the solution's data

        #Output the Solution information into the Excel Document
        $worksheet.Cells.Item($row, 1) = $solution.properties.displayName
        $worksheet.Cells.Item($row, 2) = $solution.properties.installedVersion
        $worksheet.Cells.Item($row, 3) = $solution.properties.contentKind
        #We are using the description rather than the Htmldescription since the Htmldescription can contain HTML formatting that
        #I cannot determine who to translate into what word can understand
        if ($null -eq $solution.properties.description) {
            $worksheet.Cells.Item($row, 4) = "<None provided>"
        }
        else {
            $worksheet.Cells.Item($row, 4) = $solution.properties.description
        }

        $dataConnectors = 0
        $workbooks = 0
        $ruleTemplates = 0
        $huntingQueries = 0
        $azureFunctions = 0
        $playBooks = 0
        $parsers = 0
    
        if ($solution.properties.contentKind -eq "StandAlone") {
            switch ($solution.properties.dependencies.criteria.kind) {
                "DataConnector" { $dataConnectors++ }
                "Workbook" { $workbooks++ }
                "AnalyticsRule" { $ruleTemplates++ }
                "HuntingQuery" { $huntingQueries++ }
                "AzureFunction" { $azureFunctions++ }
                "Playbook" { $playBooks++ }
                "Parser" { $parsers++ }
            }
        }
        else {
            $contentId = $solution.properties.contentId
            #try to load using the new way.
            $url = $baseUrl + "contentTemplates" + $apiVersion
            $url += "&%24filter=(properties%2FpackageId%20eq%20'$contentId')%20and%20" +
            "(properties%2FcontentKind%20eq%20'AnalyticsRule'%20or%20properties%2FcontentKind%20eq%20'DataConnector'%20or%20properties" +
            "%2FcontentKind%20eq%20'HuntingQuery'%20or%20properties%2FcontentKind%20eq%20'Playbook'%20or%20properties%2FcontentKind" +
            "%20eq%20'Workbook'%20or%20properties%2FcontentKind%20eq%20'Parser')"
            $singleSolutionTemplates = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader ).value
            if ("" -eq $singleSolutionTemplates) {
                #This solution was installed before the switch to solutions so we need a different way to load the data
                $body = @{
                    "subscriptions" = @(
                        "$SubscriptionId"
                    )
                    "query"         = "Resources | where type =~ 'Microsoft.Resources/templateSpecs/versions' " +
                    "| where tags['hidden-sentinelWorkspaceId'] =~ '/subscriptions/$SubscriptionId/resourcegroups/$resourceGroupName/providers/microsoft.operationalinsights/workspaces/$workspaceName' " +
                    "| extend version = name | extend parsed_version = parse_version(version)  " +
                    "| extend content_kind = tags['hidden-sentinelContentType'] " +
                    "| extend resources = parse_json(parse_json(parse_json(properties).template).resources)  " +
                    "| extend metadata = parse_json(resources[array_length(resources)-1].properties) " +
                    "| extend contentId=tostring(metadata.contentId) " +
                    "| where metadata.source.sourceId == '$contentId'  " +
                    "| extend resource = parse_json(resources[0].properties)  " +
                    "| extend displayName = case(content_kind == `"DataConnector`", resource.connectorUiConfig['title'], content_kind == `"Playbook`", properties['template']['metadata']['title'] , resource.displayName)  " +
                    "| where content_kind in ('Workbook', 'AnalyticsRule', 'DataConnector', 'Playbook', 'Parser', 'HuntingQuery')  " +
                    "| extend additional_data = case(content_kind == 'Parser', resource['functionAlias'], '')  " +
                    "| summarize arg_max(id, parsed_version, version, displayName, content_kind, properties, additional_data) by contentId, tostring(content_kind) " +
                    "| project id, contentId, version, displayName, content_kind, additional_data"
                }
                $url = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2019-04-01"
                $singleSolutionTemplates = Invoke-RestMethod -Uri $url -Method POST -Headers $authHeader -Body ($body | ConvertTo-Json -EnumsAsStrings -Depth 50)
                foreach ($row in $singleSolutionTemplates.data.rows) {
                    switch ($row[4]) {
                        "DataConnector" { $dataConnectors++ }
                        "Workbook" { $workbooks++ }
                        "AnalyticsRule" { $ruleTemplates++ }
                        "HuntingQuery" { $huntingQueries++ }
                        "AzureFunction" { $azureFunctions++ }
                        "Playbook" { $playBooks++ }
                        "Parser" { $parsers++ }
                    }
                }
            }
            else {
                $dataConnectors = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "DataConnector" }).count
                $workbooks = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "Workbook" }).count
                $ruleTemplates = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "AnalyticsRule" }).count
                $huntingQueries = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "HuntingQuery" }).count
                $azureFunctions = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "AzureFunction" }).count
                $playBooks = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "Playbook" }).count
                $parsers = ($singleSolutionTemplates | Where-Object { $_.properties.contentKind -eq "Parser" }).count
            }
        }
        #Output the summary line to the word document.  I know this is in a lot of solution's descriptions already
        #but it is in HTML and I cannot figure out how to easily translate it to something Excel can understand.
        $worksheet.Cells.Item($row, 5) = $dataConnectors
        $worksheet.Cells.Item($row, 6) = $workbooks
        $worksheet.Cells.Item($row, 7) = $ruleTemplates
        $worksheet.Cells.Item($row, 8) = $huntingQueries
        $worksheet.Cells.Item($row, 9) = $azureFunctions
        $worksheet.Cells.Item($row, 10) = $playBooks
        $worksheet.Cells.Item($row, 11) = $parsers
    }
    catch {
        $errorReturn = $_
        Write-Error $errorReturn
        $StatusBox.text += "Error occurred rendering a single solution: " + $errorReturn
        $StatusBox.text += "`r`n"
    }
}

Function Show-UserInterface() {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    if (-not (Get-AzContext)) {
        Connect-AzAccount
    }

    $HeaderLabel = New-Object Windows.Forms.Label
    $HeaderLabel.Text = "Microsoft Sentinel Documentation Excel Generator"
    $HeaderLabel.Font = New-Object Drawing.Font("Arial", 20, [Drawing.FontStyle]::Bold)
    $HeaderLabel.AutoSize = $true
    $HeaderLabel.Location = New-Object Drawing.Point(10, 10)
    $HeaderLabel.ForeColor = [System.Drawing.Color]::Black

    $WorkspaceLabel = New-Object Windows.Forms.Label
    $WorkspaceLabel.Text = "Workspace Name"
    $WorkspaceLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $WorkspaceLabel.AutoSize = $true
    $WorkspaceLabel.Location = New-Object Drawing.Point(10, 80)
    $WorkspaceLabel.ForeColor = [System.Drawing.Color]::Black

    $WorkspaceName = New-Object System.Windows.Forms.textbox
    $WorkspaceName.Text = ""
    $WorkspaceName.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $WorkspaceName.Multiline = $False
    $WorkspaceName.Size = New-Object System.Drawing.Size(250, 400)
    $WorkspaceName.Location = new-object System.Drawing.Size(230, 80)

    $ResourceGroupLabel = New-Object Windows.Forms.Label
    $ResourceGroupLabel.Text = "Resource Group Name"
    $ResourceGroupLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ResourceGroupLabel.AutoSize = $true
    $ResourceGroupLabel.Location = New-Object Drawing.Point(10, 120)
    $ResourceGroupLabel.ForeColor = [System.Drawing.Color]::Black

    $ResourceGroupName = New-Object System.Windows.Forms.textbox
    $ResourceGroupName.Text = ""
    $ResourceGroupName.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ResourceGroupName.Multiline = $False
    $ResourceGroupName.Size = New-Object System.Drawing.Size(250, 400)
    $ResourceGroupName.Location = new-object System.Drawing.Size(230, 120)

    $FileNameLabel = New-Object Windows.Forms.Label
    $FileNameLabel.Text = "File Name"
    $FileNameLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $FileNameLabel.AutoSize = $true
    $FileNameLabel.Location = New-Object Drawing.Point(10, 160)
    $FileNameLabel.ForeColor = [System.Drawing.Color]::Black

    $FileName = New-Object System.Windows.Forms.textbox
    $FileName.Text = "MicrosoftSentinelReport.xlsx"
    $FileName.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $FileName.Multiline = $False
    $FileName.Size = New-Object System.Drawing.Size(250, 800)
    $FileName.Location = new-object System.Drawing.Size(230, 160)

    $CreateButton = New-Object System.Windows.Forms.Button
    $CreateButton.Location = New-Object System.Drawing.Size (500, 120)
    $CreateButton.Size = New-Object System.Drawing.Size(180, 30)
    $CreateButton.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Regular)
    $CreateButton.BackColor = "LightGray"
    $CreateButton.Text = "Generate"
    $CreateButton.Enabled = $true
    $CreateButton.Add_Click({
            Export-AzSentinelConfigurationToExcel $FileName.text
        })


    $IncludeLabel = New-Object Windows.Forms.Label
    $IncludeLabel.Text = "Include the selected sections"
    $IncludeLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Regular)
    $IncludeLabel.AutoSize = $true
    $IncludeLabel.Location = New-Object Drawing.Point(20, 210)
    $IncludeLabel.ForeColor = [System.Drawing.Color]::Black

    #Left Column

    $ShowWorkbooks = New-Object System.Windows.Forms.CheckBox
    $ShowWorkbooks.text = "Workbooks"
    $ShowWorkbooks.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowWorkbooks.width = 100
    $ShowWorkbooks.autosize = $true
    $ShowWorkbooks.location = New-Object System.Drawing.Point(20, 250)
    $ShowWorkbooks.CheckAlign = "MiddleRight"
    $ShowWorkbooks.Checked = $true

    $ShowHunts = New-Object System.Windows.Forms.CheckBox
    $ShowHunts.text = "Hunts"
    $ShowHunts.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowHunts.width = 100
    $ShowHunts.autosize = $true
    $ShowHunts.location = New-Object System.Drawing.Point(20, 280)
    $ShowHunts.CheckAlign = "MiddleRight"
    $ShowHunts.Checked = $true

    $ShowMitre = New-Object System.Windows.Forms.CheckBox
    $ShowMitre.text = "MITRE Coverage"
    $ShowMitre.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowMitre.width = 100
    $ShowMitre.autosize = $true
    $ShowMitre.location = New-Object System.Drawing.Point(20, 310)
    $ShowMitre.CheckAlign = "MiddleRight"
    $ShowMitre.Checked = $true

    $ShowSolutions = New-Object System.Windows.Forms.CheckBox
    $ShowSolutions.text = "Solutions"
    $ShowSolutions.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowSolutions.width = 100
    $ShowSolutions.autosize = $true
    $ShowSolutions.location = New-Object System.Drawing.Point(20, 340)
    $ShowSolutions.CheckAlign = "MiddleRight"
    $ShowSolutions.Checked = $true

    $ShowRepositories = New-Object System.Windows.Forms.CheckBox
    $ShowRepositories.text = "Repositories"
    $ShowRepositories.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowRepositories.width = 100
    $ShowRepositories.autosize = $true
    $ShowRepositories.location = New-Object System.Drawing.Point(20, 370)
    $ShowRepositories.CheckAlign = "MiddleRight"
    $ShowRepositories.Checked = $true


    # Middle column

    $ShowWorkspace = New-Object System.Windows.Forms.CheckBox
    $ShowWorkspace.text = "Workspace Manager"
    $ShowWorkspace.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowWorkspace.width = 100
    $ShowWorkspace.autosize = $true
    $ShowWorkspace.location = New-Object System.Drawing.Point(260, 250)
    $ShowWorkspace.CheckAlign = "MiddleRight"
    $ShowWorkspace.Checked = $true

    $ShowDataConnectors = New-Object System.Windows.Forms.CheckBox
    $ShowDataConnectors.text = "Data Connectors"
    $ShowDataConnectors.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowDataConnectors.width = 100
    $ShowDataConnectors.autosize = $true
    $ShowDataConnectors.location = New-Object System.Drawing.Point(260, 280)
    $ShowDataConnectors.CheckAlign = "MiddleRight"
    $ShowDataConnectors.Checked = $true

    $ShowRules = New-Object System.Windows.Forms.CheckBox
    $ShowRules.text = "Analytic Rules"
    $ShowRules.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowRules.width = 100
    $ShowRules.autosize = $true
    $ShowRules.location = New-Object System.Drawing.Point(260, 310)
    $ShowRules.CheckAlign = "MiddleRight"
    $ShowRules.Checked = $true

    $ShowSummary = New-Object System.Windows.Forms.CheckBox
    $ShowSummary.text = "Summary Rules"
    $ShowSummary.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowSummary.width = 100
    $ShowSummary.autosize = $true
    $ShowSummary.location = New-Object System.Drawing.Point(260, 340)
    $ShowSummary.CheckAlign = "MiddleRight"
    $ShowSummary.Checked = $true

    $ShowWatchlist = New-Object System.Windows.Forms.CheckBox
    $ShowWatchlist.text = "Watchlists"
    $ShowWatchlist.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowWatchlist.width = 100
    $ShowWatchlist.autosize = $true
    $ShowWatchlist.location = New-Object System.Drawing.Point(260, 370)
    $ShowWatchlist.CheckAlign = "MiddleRight"
    $ShowWatchlist.Checked = $true


    # Right column
    $ShowAutomation = New-Object System.Windows.Forms.CheckBox
    $ShowAutomation.text = "Automation"
    $ShowAutomation.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowAutomation.width = 100
    $ShowAutomation.autosize = $true
    $ShowAutomation.location = New-Object System.Drawing.Point(500, 250)
    $ShowAutomation.CheckAlign = "MiddleRight"
    $ShowAutomation.Checked = $true

    $ShowPlaybooks = New-Object System.Windows.Forms.CheckBox
    $ShowPlaybooks.text = "Playbooks"
    $ShowPlaybooks.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowPlaybooks.width = 100
    $ShowPlaybooks.autosize = $true
    $ShowPlaybooks.location = New-Object System.Drawing.Point(500, 280)
    $ShowPlaybooks.CheckAlign = "MiddleRight"
    $ShowPlaybooks.Checked = $true

    $ShowSettings = New-Object System.Windows.Forms.CheckBox
    $ShowSettings.text = "Settings"
    $ShowSettings.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowSettings.width = 100
    $ShowSettings.autosize = $true
    $ShowSettings.location = New-Object System.Drawing.Point(500, 310)
    $ShowSettings.CheckAlign = "MiddleRight"
    $ShowSettings.Checked = $true


    $ShowTables = New-Object System.Windows.Forms.CheckBox
    $ShowTables.text = "Table Configuration"
    $ShowTables.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowTables.width = 100
    $ShowTables.autosize = $true
    $ShowTables.location = New-Object System.Drawing.Point(500, 340)
    $ShowTables.CheckAlign = "MiddleRight"
    $ShowTables.Checked = $true

    $ShowRBAC = New-Object System.Windows.Forms.CheckBox
    $ShowRBAC.text = "RBAC"
    $ShowRBAC.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $ShowRBAC.width = 100
    $ShowRBAC.autosize = $true
    $ShowRBAC.location = New-Object System.Drawing.Point(500, 370)
    $ShowRBAC.CheckAlign = "MiddleRight"
    $ShowRBAC.Checked = $true


    ## Status
    $StatusLabel = New-Object Windows.Forms.Label
    $StatusLabel.Text = "Status"
    $StatusLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Regular)
    $StatusLabel.AutoSize = $true
    $StatusLabel.Location = New-Object Drawing.Point(10, 410)
    $StatusLabel.ForeColor = [System.Drawing.Color]::Black

    $StatusBox = New-Object System.Windows.Forms.textbox
    $StatusBox.Text = ""
    $StatusBox.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
    $StatusBox.Multiline = $True
    $StatusBox.ScrollBars = "Vertical"
    #$StatusBox.Dock = "Fill"
    $StatusBox.Size = New-Object System.Drawing.Size(600, 430)
    $StatusBox.Location = new-object System.Drawing.Size(10, 440)

    ##Close form
    $CloseButton = New-Object System.Windows.Forms.Button
    $CloseButton.Location = New-Object System.Drawing.Size (630, 835)
    $CloseButton.Size = New-Object System.Drawing.Size(80, 30)
    $CloseButton.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Regular)
    $CloseButton.BackColor = "LightGray"
    $CloseButton.Text = "Close"
    $CloseButton.Enabled = $true
    $CloseButton.Add_Click({
            $form.Close()
        })


    ##Form
    $Form = New-Object Windows.Forms.Form
    $Form.Text = "MS Sentinel Documentation Creator"
    $Form.Width = 750
    $Form.Height = 930
    $Form.BackColor = "LightBlue"

    $Form.Add_Paint({
            param($sender, $e)
            # Define the rectangle's dimensions
            $rectangle = New-Object System.Drawing.Rectangle(10, 200, 710, 200)
            # Define the pen for drawing
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 3)
            # Draw the rectangle
            $e.Graphics.DrawRectangle($pen, $rectangle)
            # Dispose of the pen to free resources
            $pen.Dispose()
        })

    
    $Form.Controls.add($HeaderLabel)
    $Form.Controls.add($WorkspaceLabel)
    $Form.Controls.add($WorkspaceName)
    $Form.Controls.add($ResourceGroupLabel)
    $Form.Controls.add($ResourceGroupName)
    $Form.Controls.add($FileNameLabel)
    $Form.Controls.add($FileName)
    $Form.Controls.add($IncludeLabel)
    $Form.Controls.add($CreateButton)
    $Form.Controls.add($ShowSolutions)
    $Form.Controls.add($ShowWorkbooks)
    $Form.Controls.add($ShowHunts)
    $Form.Controls.add($ShowRepositories)
    $Form.Controls.add($ShowWorkspace)
    $Form.Controls.add($ShowDataConnectors)
    $Form.Controls.add($ShowRules)
    $Form.Controls.add($ShowWatchlist)
    $Form.Controls.add($ShowAutomation)
    $Form.Controls.add($ShowPlaybooks)
    $Form.Controls.add($ShowSettings)
    $Form.Controls.add($ShowSearch)
    $Form.Controls.add($ShowMitre)
    $Form.Controls.add($ShowTables)
    $Form.Controls.add($ShowSummary)
    $Form.Controls.add($StatusLabel)
    $Form.Controls.add($StatusBox)
    $Form.Controls.add($ShowRBAC)
    $Form.Controls.add($CloseButton)
    $Form.Add_Shown({ $Form.Activate() })
    $Form.ShowDialog()
}

#Execute the code
Show-UserInterface

