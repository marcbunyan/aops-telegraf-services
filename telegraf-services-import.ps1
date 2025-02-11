 # Suppress SSL certificate checks - make your own decision on this!
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11


Write-Host "Script started."

# Input prompts
$username = Read-Host "Enter your username"
Write-Host "Username: $username"

$authSource = Read-Host "Enter your authSource"
Write-Host "AuthSource: $authSource"

$password = Read-Host "Enter your password" -AsSecureString
$passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
Write-Host "Password received (securely)."

$vropsHostname = Read-Host "Enter your vROps hostname"
Write-Host "vROps Hostname: $vropsHostname"

$SourceCSV = Read-Host "Enter the path to your services.csv file"
Write-Host "CSV Path: $SourceCSV"

$VMwithAgent = Read-Host "Enter the name of the VM with the Telegraf agent"
Write-Host "VM Name: $VMwithAgent"

Start-Transcript -Path ".\$VMwithAgent.log"

Write-Host "Attempting login..."
$loginUri = "https://$vropsHostname/suite-api/api/auth/token/acquire?_no_links=true"
$loginData = @{
    username = $username
    authSource = $authSource
    password = $passwordPlainText
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $loginUri -Method POST -Body $loginData -ContentType "application/json" -Headers @{"Accept"="application/json"} -UseBasicParsing -ErrorAction Stop -Verbose
    $token = $response.token
    Write-Host "Auth Token acquired successfully."
}
catch {
    Write-Host "Error during authentication: $_"
    Stop-Transcript
    return
}

Write-Host "Auth Token: $token"

Write-Host "Attempting to retrieve Agent ID..."
$objectUri = "https://$vropsHostname/suite-api/api/resources?resourceKind=VirtualMachine&name=$VMwithAgent"

try {
    $objectResponse = Invoke-RestMethod -Uri $objectUri -Method GET -Headers @{"Accept"="application/json"; "Authorization"="vRealizeOpsToken $token"} -UseBasicParsing -ErrorAction Stop -Verbose
    $AgentID = $objectResponse.resourceList.identifier
    Write-Host "Agent ID retrieved: $AgentID"
} catch {
    Write-Host "Error retrieving Agent ID: $_"
    Stop-Transcript
    return
}

$vRopsURL = "https://$($vropsHostname)/suite-api/api/applications/agents/$($AgentID)/services?_no_links=true"

# CSV processing and $Json object creation
try {
    $columnNames = (Import-Csv $SourceCSV | Get-Member -MemberType Property | Select-Object -ExpandProperty Name)
    Write-Host "Column Names (Exact):"
    $columnNames | ForEach-Object { Write-Host $_ }

    # *** DEBUG STEP : Show the first 5 rows of data ***
    $csvData = Import-Csv $SourceCSV | Select-Object -First 5
    Write-Host "First 5 rows of CSV:"
    $csvData | Format-Table -AutoSize
    Read-Host "Press Enter to continue..."

    $Data = Import-Csv $SourceCSV

    # Initialize $Configurations *outside* the loop
    $Configurations = @()

    foreach ($item in $Data) {
        # Create the configuration object
        $config = [ordered]@{
            configName = "$($item.ServiceDisplayname) on $VMwithAgent" # Use correct column name
            isActivated = $true
            parameters = @(
                @{
                    key = "FILTER_VALUE"
                    value = "$($item.ServiceNamed)" # Use correct column name
                }
            )
        }
        # Add the $config object to the $Configurations array
        $Configurations += $config
    } # Close the foreach loop

    $PostObject = @{
        services = @(
            @{
                serviceName = "serviceavailability"
                configurations = $Configurations # Use the populated array
            }
        )
    }

    $Json = $PostObject | ConvertTo-Json -Depth 10

    Write-Host "JSON Payload:"
    Write-Host $Json

} catch {
    Write-Host "Error processing CSV: $_"
    Stop-Transcript
    return
}


$headers = @{
    "Accept" = "application/json"
    "Content-Type" = "application/json"
    "Authorization" = "vRealizeOpsToken $token"
}

Write-Host "Attempting to send API request..."
try {
    $result = Invoke-RestMethod -Method Post -Uri $vRopsURL -Body $Json -Headers $headers -UseBasicParsing -ErrorAction Stop -Verbose
    Write-Host "Service Availability configurations added successfully."
    Write-Host "API Response: $($result | ConvertTo-Json -Depth 10)"
}
catch {
    Write-Host "Error sending API request: $_"
    Stop-Transcript
    return
}

Write-Host "Service availability script finished."

Stop-Transcript 
