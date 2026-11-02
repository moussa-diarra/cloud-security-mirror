   param(
     [Parameter(Mandatory = $true)][string]$RoleArn,
     [Parameter(Mandatory = $true)][string]$MfaSerial,
     [Parameter(Mandatory = $true)][string]$Code,
     [string]$Profile = "adm-cloud"
   )

   $json = aws sts assume-role `
     --role-arn $RoleArn `
     --role-session-name terraform `
     --serial-number $MfaSerial `
     --token-code $Code `
     --duration-seconds 3600 `
     --profile $Profile

   $c = ($json | ConvertFrom-Json).Credentials
   $env:AWS_ACCESS_KEY_ID     = $c.AccessKeyId
   $env:AWS_SECRET_ACCESS_KEY = $c.SecretAccessKey
   $env:AWS_SESSION_TOKEN     = $c.SessionToken
   Write-Host "Session ouverte jusqu'à $($c.Expiration)"