#Requires -Version 7.0
<#
.SYNOPSIS
    Forge LZ Starter — pre-deployment script. Creates required Entra ID security groups.

.DESCRIPTION
    Creates two Entra ID security groups in your Azure tenant required for
    Forge LZ Starter deployment. Run this script before deploying from
    Microsoft Marketplace.

    Groups created:

      Group 1 — Platform Administrators
        Reader on rg-alz-management, rg-alz-networking, and rg-alz-security
        Key Vault Secrets Officer on the landing zone Key Vault

      Group 2 — Workload Administrators
        Contributor on rg-alz-workload
        Key Vault Reader on the landing zone Key Vault

.PARAMETER PlatformAdminGroupName
    Display name for the platform administrator group.
    Recommended CAF naming: grp-alz-platform-admins-{environment}

.PARAMETER WorkloadAdminGroupName
    Display name for the workload administrator group.
    Recommended CAF naming: grp-alz-workload-admins-{environment}

.EXAMPLE
    .\alzPreDeployment.ps1

.EXAMPLE
    .\alzPreDeployment.ps1 -PlatformAdminGroupName "grp-alz-platform-admins-prod" `
                           -WorkloadAdminGroupName "grp-alz-workload-admins-prod"

.NOTES
    Requires Azure CLI installed and signed in to the target tenant.
    Download: https://aka.ms/installazurecliwindows
#>

[CmdletBinding()]
param (
    [string]$PlatformAdminGroupName = 'grp-alz-platform-admins',
    [string]$WorkloadAdminGroupName = 'grp-alz-workload-admins'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step   { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok     { param([string]$Message) Write-Host "    [OK] $Message" -ForegroundColor Green }
function Write-Detail { param([string]$Message) Write-Host "         $Message" -ForegroundColor Gray }

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

Write-Step 'Checking prerequisites'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error 'Azure CLI (az) is not installed. Download: https://aka.ms/installazurecliwindows'
    exit 1
}

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not signed in to Azure CLI. Run 'az login' and try again."
    exit 1
}

Write-Ok 'Azure CLI signed in'
Write-Detail "Tenant : $($account.tenantId)"
Write-Detail "Account: $($account.user.name)"

Write-Host ''
Write-Host '  Target tenant: ' -NoNewline -ForegroundColor Yellow
Write-Host $account.tenantId -ForegroundColor White
Write-Host '  Press Enter to continue or Ctrl+C to cancel...' -ForegroundColor Yellow
$null = Read-Host

# ---------------------------------------------------------------------------
# Group helper — creates group if it does not already exist
# ---------------------------------------------------------------------------

function Get-OrCreateGroup {
    param(
        [string]$DisplayName,
        [string]$Description
    )

    $existingId = az ad group list `
        --filter "displayName eq '$DisplayName'" `
        --query '[0].id' -o tsv 2>$null

    if ($existingId) {
        Write-Detail "Group '$DisplayName' already exists — using existing group"
        return $existingId.Trim()
    }

    $mailNickname = $DisplayName -replace '[^a-zA-Z0-9-]', '-'

    $newId = az ad group create `
        --display-name $DisplayName `
        --mail-nickname $mailNickname `
        --description $Description `
        --query 'id' -o tsv

    return $newId.Trim()
}

# ---------------------------------------------------------------------------
# Create groups
# ---------------------------------------------------------------------------

Write-Step 'Creating security groups'

$platformOid = Get-OrCreateGroup `
    -DisplayName $PlatformAdminGroupName `
    -Description 'Forge LZ Starter — platform administrator group. Reader on rg-alz-management, rg-alz-networking, and rg-alz-security. Key Vault Secrets Officer on the landing zone Key Vault.'

Write-Ok "Platform Administrators: $PlatformAdminGroupName"
Write-Detail "Object ID: $platformOid"

$workloadOid = Get-OrCreateGroup `
    -DisplayName $WorkloadAdminGroupName `
    -Description 'Forge LZ Starter — workload administrator group. Contributor on rg-alz-workload. Key Vault Reader on the landing zone Key Vault.'

Write-Ok "Workload Administrators: $WorkloadAdminGroupName"
Write-Detail "Object ID: $workloadOid"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host '  Forge LZ Starter — Pre-Deployment Complete' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host ''
Write-Host '  Copy these Object IDs into the deployment wizard.' -ForegroundColor White
Write-Host '  You will be prompted for them in the Identity & Access step.' -ForegroundColor Gray
Write-Host ''
Write-Host '  Platform Admin Group Object ID' -ForegroundColor White
Write-Host "  $platformOid" -ForegroundColor Yellow
Write-Host ''
Write-Host '  Workload Admin Group Object ID' -ForegroundColor White
Write-Host "  $workloadOid" -ForegroundColor Yellow
Write-Host ''
Write-Host '================================================================' -ForegroundColor Green

# SIG # Begin signature block
# MII9TQYJKoZIhvcNAQcCoII9PjCCPToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAl3C62xD88HOEc
# vLwRpAEB9+ZMW5KDjITnQ3gjxT786qCCIhIwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwgga2MIIEnqADAgECAhMzAAFA9dom
# ElcivaaNAAAAAUD1MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDQwHhcNMjYwNTIxMTQyNDIwWhcNMjYwNTI0
# MTQyNDIwWjB7MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTETMBEG
# A1UEBxMKU2FjcmFtZW50bzEgMB4GA1UEChMXRnJhbWV0eXBlIFNvbHV0aW9ucyBM
# TEMxIDAeBgNVBAMTF0ZyYW1ldHlwZSBTb2x1dGlvbnMgTExDMIIBojANBgkqhkiG
# 9w0BAQEFAAOCAY8AMIIBigKCAYEAh1cWlepU4+bRggiNPxxGZE8P1K6kq6MnsUSM
# b/nA6i85xXWaMG4vy76VgU9C83VdFrYjIUqf3wuJyDX+NU+W+QGmwHqGX22evLHI
# ejHT4YRfsnHdnSoYKLn65ilk/oLmFp9a9mbUJaEmQgEivKGB3PbBwOpXpqp9AwEH
# 6C0Oud/YQ2SseV77+9gi9oZRToI+EqtCEdtDBNRiKMXub8fhnqERQYubMuiBLBEh
# 34lMiNM4qxmwPyoMYTPk6ztPM1nH9l8FDeP8STJKZ0yww0cgQ37ZBf7jaYm9XdPU
# YS+R8C8eQjCxZr4e1PZE43RhoIv0JwtU8DnB6VyoxMYEXXmHJNGRXvCDb+vJ+QUA
# L5BRwPerJHQMxRDBBlTrfKoiah8Xd2CRYjlE1eiNryC5aApm/VrmE9s/Kq1VCLgo
# 3uPgnbWOKrBn0o7NVoMfvzVCgs2VOdgrNyywEyl2XT1qahW042iU8qLNnjLvYD1u
# 0epSycb+fXZ4QyeL9NN/FcHG15vDAgMBAAGjggHSMIIBzjAMBgNVHRMBAf8EAjAA
# MA4GA1UdDwEB/wQEAwIHgDA5BgNVHSUEMjAwBgorBgEEAYI3YQEABggrBgEFBQcD
# AwYYKwYBBAGCN2HHprI72+bsOczY9zf3g7w5MB0GA1UdDgQWBBSL+bASpFyckhRd
# G0Lf/+abZDH0eTAfBgNVHSMEGDAWgBSa8VR3dQyHFjdGoKzeefn0f8F46TBnBgNV
# HR8EYDBeMFygWqBYhlZodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDA0
# LmNybDB0BggrBgEFBQcBAQRoMGYwZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmll
# ZCUyMENTJTIwRU9DJTIwQ0ElMjAwNC5jcnQwVAYDVR0gBE0wSzBJBgRVHSAAMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTANBgkqhkiG9w0BAQwFAAOCAgEAAWiQlrq18f7kA+O8
# 8vuKqYWgLul8qqPMWqIPku/JojoGiJtNcvWTUY6W1Y1ACcEpHwilDd+JVUnTASR8
# bvNLm0BdJvM+rg2HhQpRw/H5WA0t9KTq7usr1CHsHKxtgEV/jb3hToVYcB8n1lZD
# WrZGks6/DUjBekwQdn7YmeZcY/4CBFt1Yt+S3yKPu1IE056X+Tu+oz/iZhpkLh3+
# UOBZ+SaTQjPOpGRlaGKpc/T7vNlkINlC+x5Q0FdJxXRikDHDkHq+yz0F5NIy2+RU
# HGbBjw/WLAD6d3BFBDFlAuPXVutynCeQWwMOYt5PdWbFzJf3GoPZ8HjR4Pi+ck3A
# 06xO5YRmT5t7RZYlDRoaCLZZ81nX7rQgJFNaAH0eDiwMdNBwXCeAgLhJCW5syqiR
# QS8dcugNVCbcZE2hCpgAgSXTR8MYmhgrB6bafBmLvKFZkU9lzGLi5vO3hYd+aNOW
# NJm6DcQakL2HFlofVcqDaSLvcZzihpS7iVYXZK1so4C4dYleUp7l3/Ph66aB41UF
# duWxrG5cMGjR2uTN2ZK1bNchr80Ob7rGhX+fYfHsYjkML8on1BSQ3jZG2Gr4pyZ5
# YE+oDV5pris1kcFZENxNux//zYCqAuSWZkcWU5p/cYu1fVi+6dL0NNrRJ9gIarjV
# kgruEpHiTnKV10IfEs8S8z5EYd4wgga2MIIEnqADAgECAhMzAAFA9domElcivaaN
# AAAAAUD1MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJp
# ZmllZCBDUyBFT0MgQ0EgMDQwHhcNMjYwNTIxMTQyNDIwWhcNMjYwNTI0MTQyNDIw
# WjB7MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTETMBEGA1UEBxMK
# U2FjcmFtZW50bzEgMB4GA1UEChMXRnJhbWV0eXBlIFNvbHV0aW9ucyBMTEMxIDAe
# BgNVBAMTF0ZyYW1ldHlwZSBTb2x1dGlvbnMgTExDMIIBojANBgkqhkiG9w0BAQEF
# AAOCAY8AMIIBigKCAYEAh1cWlepU4+bRggiNPxxGZE8P1K6kq6MnsUSMb/nA6i85
# xXWaMG4vy76VgU9C83VdFrYjIUqf3wuJyDX+NU+W+QGmwHqGX22evLHIejHT4YRf
# snHdnSoYKLn65ilk/oLmFp9a9mbUJaEmQgEivKGB3PbBwOpXpqp9AwEH6C0Oud/Y
# Q2SseV77+9gi9oZRToI+EqtCEdtDBNRiKMXub8fhnqERQYubMuiBLBEh34lMiNM4
# qxmwPyoMYTPk6ztPM1nH9l8FDeP8STJKZ0yww0cgQ37ZBf7jaYm9XdPUYS+R8C8e
# QjCxZr4e1PZE43RhoIv0JwtU8DnB6VyoxMYEXXmHJNGRXvCDb+vJ+QUAL5BRwPer
# JHQMxRDBBlTrfKoiah8Xd2CRYjlE1eiNryC5aApm/VrmE9s/Kq1VCLgo3uPgnbWO
# KrBn0o7NVoMfvzVCgs2VOdgrNyywEyl2XT1qahW042iU8qLNnjLvYD1u0epSycb+
# fXZ4QyeL9NN/FcHG15vDAgMBAAGjggHSMIIBzjAMBgNVHRMBAf8EAjAAMA4GA1Ud
# DwEB/wQEAwIHgDA5BgNVHSUEMjAwBgorBgEEAYI3YQEABggrBgEFBQcDAwYYKwYB
# BAGCN2HHprI72+bsOczY9zf3g7w5MB0GA1UdDgQWBBSL+bASpFyckhRdG0Lf/+ab
# ZDH0eTAfBgNVHSMEGDAWgBSa8VR3dQyHFjdGoKzeefn0f8F46TBnBgNVHR8EYDBe
# MFygWqBYhlZodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNy
# b3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDA0LmNybDB0
# BggrBgEFBQcBAQRoMGYwZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENT
# JTIwRU9DJTIwQ0ElMjAwNC5jcnQwVAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYB
# BQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBv
# c2l0b3J5Lmh0bTANBgkqhkiG9w0BAQwFAAOCAgEAAWiQlrq18f7kA+O88vuKqYWg
# Lul8qqPMWqIPku/JojoGiJtNcvWTUY6W1Y1ACcEpHwilDd+JVUnTASR8bvNLm0Bd
# JvM+rg2HhQpRw/H5WA0t9KTq7usr1CHsHKxtgEV/jb3hToVYcB8n1lZDWrZGks6/
# DUjBekwQdn7YmeZcY/4CBFt1Yt+S3yKPu1IE056X+Tu+oz/iZhpkLh3+UOBZ+SaT
# QjPOpGRlaGKpc/T7vNlkINlC+x5Q0FdJxXRikDHDkHq+yz0F5NIy2+RUHGbBjw/W
# LAD6d3BFBDFlAuPXVutynCeQWwMOYt5PdWbFzJf3GoPZ8HjR4Pi+ck3A06xO5YRm
# T5t7RZYlDRoaCLZZ81nX7rQgJFNaAH0eDiwMdNBwXCeAgLhJCW5syqiRQS8dcugN
# VCbcZE2hCpgAgSXTR8MYmhgrB6bafBmLvKFZkU9lzGLi5vO3hYd+aNOWNJm6DcQa
# kL2HFlofVcqDaSLvcZzihpS7iVYXZK1so4C4dYleUp7l3/Ph66aB41UFduWxrG5c
# MGjR2uTN2ZK1bNchr80Ob7rGhX+fYfHsYjkML8on1BSQ3jZG2Gr4pyZ5YE+oDV5p
# ris1kcFZENxNux//zYCqAuSWZkcWU5p/cYu1fVi+6dL0NNrRJ9gIarjVkgruEpHi
# TnKV10IfEs8S8z5EYd4wggcoMIIFEKADAgECAhMzAAAAFydFCQuLh6/GAAAAAAAX
# MA0GCSqGSIb3DQEBDAUAMGMxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xNDAyBgNVBAMTK01pY3Jvc29mdCBJRCBWZXJpZmllZCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjEwHhcNMjYwMzI2MTgxMTMxWhcNMzEwMzI2MTgx
# MTMxWjBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ1MgRU9DIENBIDA0
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAgsdk/gMPZioBlcyfk6tD
# zJ+PRt4rSLGKW8ewpS0kRxXtURC3T3GdbCKljobEn8ussqhGqQpRh/SXvRVwNXEI
# Gb76UG5IPkCJ1S6/9BD61QQsKzPepW0SNj8TXgsFxvS7MltoRuikIIp7Q5jQgaOM
# 6QyK9++6ZVXUpYmZulAe6x8JrwZ0dNkE+rZ66lqtoocwepUSVUxM7odDmn8yDHjJ
# 2DNPsfr3uRDix3X4qvh14jH/SW+2Cx7WIMhyIiQO201i6hUixmk4e2ZW8W7C1wPd
# Tjq6BKb+zo8xbrt7ZKQvRX5QOA6dhLquPqj5sVKnxqfk19IC0SafTSTs8yC43Ew9
# 65BRRW8VL9ccoOmr4rxQy7aCgYTNk3dd/LphNaTTmnGp7kmLTxyHkB5geoWhYuuG
# rywS8E0wJv0W4rfOtHBV0e9sKvuUIeIUpnsx6ilxEVj6VQXvgD6yeCKnPmj3jJiJ
# KAlmUDtth5yzRVBUl44sMiG4L5R/yyACRKk2n088Q2YCoZS1O86+oMLKt1jaXGEC
# OjbsVp8Id1VQw8he6J0KirOS5e25XlTdGPFb6oBOOaacgW78Kjf0bp+XzAgkc92m
# DGNJGYSjvdnj+7eMx6meW0DAIGdLRNj8/429MIspFBfz3KDqqpN71S4kQ2LLer3d
# xhDDczKVFL0HLwRuOvgjiG8CAwEAAaOCAdwwggHYMA4GA1UdDwEB/wQEAwIBhjAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUmvFUd3UMhxY3RqCs3nn59H/BeOkw
# VAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTASBgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQYMBaA
# FNlBKbAPD2Ns72nX9c0pnqRIajDmMHAGA1UdHwRpMGcwZaBjoGGGX2h0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIwVmVy
# aWZpZWQlMjBDb2RlJTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3JsMH0GCCsGAQUF
# BwEBBHEwbzBtBggrBgEFBQcwAoZhaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ29kZSUyMFNp
# Z25pbmclMjBQQ0ElMjAyMDIxLmNydDANBgkqhkiG9w0BAQwFAAOCAgEAkHVaGf1N
# Jt/JdoimmRZbMWr6baaDi8mkdWvWStk0hdZDpxSYTA7HuipAoLL3qIhI101XOl7f
# OiCh5++jZOamQdAV79ojEUNoIgCZmL2XJrLaGanwdjNynecJyYVCTrRf2+h7Kknp
# WOp4axdOs6K9ZQ5g0IsQWXCwfc0dfkSkLKNY3pDcWLlJPh2jd5NUue6pNDv/2G5M
# FNJhCwltODebyAjGceU+XOzav+7i721YQnQ+39m2aQOFO7zpAdaKAeAGhEd6Y6Cd
# DGneSxcoujWvafWbv4ay3jo1ORSLUuWMbKr5X18QE4Sde+gppGLLSkZsrUh2eyYS
# kX1envWX7ZPzg2/wiuKRlQFarDn+N9+20BqzhxwkNyLzfYJp1Lg4fCXb24XqFjx8
# SDdRgebFImOfOLVze8XQ/CwkrEaib0PHu2t4GVk4FYroEbNUFqvjdBvTY3uiR5Td
# QoyXoYHvh+TxpLSY2vo7hhK9D/rpEpHC+qmmcRUE4d0gyO9Zb1vvt25fxM3ekjvD
# fVHcPq3qMr0Rwsk4krKZWUEgU1SXT5qN6gqRrshxbT6OQgZ9/xT04qiXdzPQR6Ki
# ndBvSpoOnxnALxcJyzVwNpKL+9u8EZYy98qX6i+4gE/2J6cbpekcB0ZXDn/XQxoN
# UUb6/djT/wllVyG+vIHkdq71PzbH5rYxdcAwggeeMIIFhqADAgECAhMzAAAAB4ej
# NKN7pY4cAAAAAAAHMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJ
# ZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkg
# MjAyMDAeFw0yMTA0MDEyMDA1MjBaFw0zNjA0MDEyMDE1MjBaMGMxCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xNDAyBgNVBAMTK01p
# Y3Jvc29mdCBJRCBWZXJpZmllZCBDb2RlIFNpZ25pbmcgUENBIDIwMjEwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCy8MCvGYgo4t1UekxJbGkIVQm0Uv96
# SvjB6yUo92cXdylN65Xy96q2YpWCiTas7QPTkGnK9QMKDXB2ygS27EAIQZyAd+M8
# X+dmw6SDtzSZXyGkxP8a8Hi6EO9Zcwh5A+wOALNQbNO+iLvpgOnEM7GGB/wm5dYn
# MEOguua1OFfTUITVMIK8faxkP/4fPdEPCXYyy8NJ1fmskNhW5HduNqPZB/NkWbB9
# xxMqowAeWvPgHtpzyD3PLGVOmRO4ka0WcsEZqyg6efk3JiV/TEX39uNVGjgbODZh
# zspHvKFNU2K5MYfmHh4H1qObU4JKEjKGsqqA6RziybPqhvE74fEp4n1tiY9/ootd
# U0vPxRp4BGjQFq28nzawuvaCqUUF2PWxh+o5/TRCb/cHhcYU8Mr8fTiS15kRmwFF
# zdVPZ3+JV3s5MulIf3II5FXeghlAH9CvicPhhP+VaSFW3Da/azROdEm5sv+EUwhB
# rzqtxoYyE2wmuHKws00x4GGIx7NTWznOm6x/niqVi7a/mxnnMvQq8EMse0vwX2Cf
# qM7Le/smbRtsEeOtbnJBbtLfoAsC3TdAOnBbUkbUfG78VRclsE7YDDBUbgWt75lD
# k53yi7C3n0WkHFU4EZ83i83abd9nHWCqfnYa9qIHPqjOiuAgSOf4+FRcguEBXlD9
# mAInS7b6V0UaNwIDAQABo4ICNTCCAjEwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBTZQSmwDw9jbO9p1/XNKZ6kSGow5jBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQBgjcUAgQMHgoA
# UwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUyH7SaoUqG8oZ
# mAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3oHWGc2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZp
# Y2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5j
# cmwwgcMGCCsGAQUFBwEBBIG2MIGzMIGBBggrBgEFBQcwAoZ1aHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBJZGVudGl0eSUy
# MFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUy
# MDIwMjAuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8vb25lb2NzcC5taWNyb3NvZnQu
# Y29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAH8lKp7+1Kvq3WYK21cjTLpebJDj
# W4ZbOX3HD5ZiG84vjsFXT0OB+eb+1TiJ55ns0BHluC6itMI2vnwc5wDW1ywdCq3T
# Amx0KWy7xulAP179qX6VSBNQkRXzReFyjvF2BGt6FvKFR/imR4CEESMAG8hSkPYs
# o+GjlngM8JPn/ROUrTaeU/BRu/1RFESFVgK2wMz7fU4VTd8NXwGZBe/mFPZG6tWw
# kdmA/jLbp0kNUX7elxu2+HtHo0QO5gdiKF+YTYd1BGrmNG8sTURvn09jAhIUJfYN
# otn7OlThtfQjXqe0qrimgY4Vpoq2MgDW9ESUi1o4pzC1zTgIGtdJ/IvY6nqa80jF
# OTg5qzAiRNdsUvzVkoYP7bi4wLCj+ks2GftUct+fGUxXMdBUv5sdr0qFPLPB0b8v
# q516slCfRwaktAxK1S40MCvFbbAXXpAZnU20FaAoDwqq/jwzwd8Wo2J83r7O3onQ
# bDO9TyDStgaBNlHzMMQgl95nHBYMelLEHkUnVVVTUsgC0Huj09duNfMaJ9ogxhPN
# Thgq3i8w3DAGZ61AMeF0C1M+mU5eucj1Ijod5O2MMPeJQ3/vKBtqGZg4eTtUHt/B
# PjN74SsJsyHqAdXVS5c+ItyKWg3Eforhox9k3WgtWTpgV4gkSiS4+A09roSdOI4v
# rRw+p+fL4WrxSK5nMYIakTCCGo0CAQEwcTBaMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQg
# VmVyaWZpZWQgQ1MgRU9DIENBIDA0AhMzAAFA9domElcivaaNAAAAAUD1MA0GCWCG
# SAFlAwQCAQUAoF4wEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIFojcjI+rSOKUbv0ZaOfoAJvGF+yjoL8
# pg5/UKCYwOB6MA0GCSqGSIb3DQEBAQUABIIBgD235CLRxxGQgjIH/b3R7oTz2j4d
# ZPFDCZH0dpEKgnwwR7SR32Gtzl7YyTmmUkmwoKy86oG+jRXuDAqUzSeg20gQQJf9
# K+FrppmrT2ztYsbLY5JvLYO0mmlfrrwHoMib5/hb8ZEStLgr9Zba14gQ/M4DdxeE
# x0Aw1CdgkGB1f44hrbYkzb2M15WiLDbzK823B2PyC5601UwU6YOgmlof/Y3T8Vlp
# Et9VxeuVzWOOnxH4mKQZ3oC3gm+iA0nMP4F6hqGFyf283Momr4+IBAVny4Q47X/o
# xNWJUOCPAv5pTv2rNCI+IXIWLpJ61eoyMkF9CRkFv5HeIu75m65DFpSxbdyH0rHf
# CExx6EY21GXoPX1RBt7x1dWtg55d0fy035u6MJRi4WAeoNWzsb2xCgFrM/g7J/Dr
# 8G8F0pIyBWor9/aUwZD/y32VfxKt0wp75xd+B/5JVZazv03/AAdOTwka6MEDO4qQ
# 6iJpuCewrwizPWKMa8j98f5wclGhzDANNnAqh6GCGBEwghgNBgorBgEEAYI3AwMB
# MYIX/TCCF/kGCSqGSIb3DQEHAqCCF+owghfmAgEDMQ8wDQYJYIZIAWUDBAIBBQAw
# ggFiBgsqhkiG9w0BCRABBKCCAVEEggFNMIIBSQIBAQYKKwYBBAGEWQoDATAxMA0G
# CWCGSAFlAwQCAQUABCCxXo8lrrpuDJwurCQgYI1y8l5eUGIPoJ2YPXlg2KOVWQIG
# aeiBO0O7GBMyMDI2MDUyMjA1MzczNS4zMTRaMASAAgH0oIHhpIHeMIHbMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3Nv
# ZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046
# N0QwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRp
# bWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF5c8P
# /2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0IElk
# ZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz0RMF
# vWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5i2Cg
# GPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9KxqHyd
# ajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLkX1hy
# IWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr24qoq
# FM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaBnB60
# QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYdUmj1
# fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPgjuwN
# vE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65KcaewEJ3
# ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc6IRX
# vFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRDv09S
# vwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQBgjcV
# AQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAETTBL
# MEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMI
# MBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8wHwYD
# VR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3oHWG
# c2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRlJTIw
# QXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggrBgEF
# BQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNy
# b3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZp
# Y2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4ICAQBf
# iHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm+Jx5
# boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd1Kln
# lkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59TbXWs
# uyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3he2b
# vIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y0dgg
# Wi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0Nbwc
# 21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4fsNG
# if1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6ZObw
# tZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803jUsZc
# d4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA9S8h
# 22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQICEzMA
# AABV2d1pJij5+OIAAAAAAFUwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMCVVMx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9z
# b2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjUxMDIzMjA0
# NjQ5WhcNMjYxMDIyMjA0NjQ5WjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9u
# czEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYD
# VQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0
# eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL25H5IeWUiz9DAlFmn2
# sPymaFWbvYkMfK+ScIWb3a1IvOlIwghUDjY0Gp6yMRhfYURiGS0GedIB6ywvuH6V
# BCX3+bdOFcAclgtv21jrpOjZmk4fSaT2Q3BszUfeUJa8o3xI7ZfoMY9dszTxHQAz
# 6ZVX87fHGEVhQcfxW33IdPJOj/ae419qtYxT21MVmCfsTshgtWioQxmOW/vMC9/b
# +qgtBxSMf798vm3qfmhF6KCvFaHlivrM32hY16PGE3L0PFC+LM7vRxU7mTb+r76C
# eybvqOWk4+dbKYftPhV1t/E5S/6wwXeYmu/Y7JC7Tnh2w45G5Y4pcM3oHMb/YuPR
# dOWa0v+RC2QgmNVWqjuxDiylWscXQDuaMtb29AcdGUVV9ZsRY2M2sthAtOdZOshi
# R5ufMtaHtiCkWv0jNfgUxrHurxzYuUNneWZ6EfQDgFAw8CSCKkSOK2c9jEop4ddV
# q10xvbqxdrqMneVXvvIcXrPQAXj9j2ECpV2EwMb3Wnmpw00P78JpzPsk3Fs61ZvO
# Gd/F1RcOBu6f2TWdp7HL7+rq7tgHr13MldbfIWu4lpoYYE1gTQa1Yrg5XN4j7zs9
# klT2z3qocmPzV8DWQgIHNh+aTs7bujMEMQyI7Xt1zPxZCgcR6H0tmmzU/9BxvsWb
# RalCQ2sYGyWupTdc4e7KY7kPAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUVgRfEG3c
# CAPwyL+pyRbKwdesZbYwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk92yEw
# bAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIw
# Q0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwUHVi
# bGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDBm
# BgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wCAYG
# Z4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQBSHuGSVHvalCnFnlsqXIQefH1xP2SF
# r9g+Vz+f5P7QeywjfQb5jUlSmd1XnJUDPe/MHxL7r3TEElL+mNtG6CDPAytStSFP
# XD9tTBtBMYh8Wqo64pH9qm361yIqeBH979mzWCkMQsTd0nM6dUl9B+7qiti+ToXw
# xIl39eYqLuYYfhD2mqqePXMzUKSQzkf73yYIVHP6nLJQz4aAmaWcfG9jg78sBkDV
# 8KpW7JgktuLhphJEN1B+SVHjenPdcmrFXIUu/K4jK5ukfWaQIjuaXzSjBlNjC5tQ
# N6adPfA3GxUwHPeR4ekL5If/9vBf13tmzBW+gy+0sNGTveb9IL9GU8iX8UvywsX6
# 2nhCCPRUhTigDBKdczRUrNrntBhowbfchBDFML8avRMRc9Gmc2JvIryX336SFQ51
# //q1UU2HMSJEMhWLJSIWJVhfUowsOa+PampIzETYfFvTu2mqKJUlWZXkGYxrdCvC
# czJcqeoadpW1ul6kcdnDh228SQ8ZhDc6IRlM4iNd5SNoNgX+aom3wuGyjUaSaPZW
# xPB1G2NKiYhPLt0lPHg0Gskj1zhISY8UQkMMDr3o2JgRuT+wnJEDQUp55ddvhSkS
# oD6I9DL/s+TjIY/c9jLaW5xywJHqdKHUApRMsghv7kebSua1upmR+TquelFktDSO
# jVdSRkuya4uoxTGCB0Mwggc/AgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABV2d1pJij5+OIAAAAAAFUw
# DQYJYIZIAWUDBAIBBQCgggScMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG9w0B
# CQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDUyMjA1MzczNVow
# LwYJKoZIhvcNAQkEMSIEIE7bPYQ36bkKLHB0jL72SVA42QTcLGBYdlbPja0vFAT+
# MIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQg2Lk8l2SGYru/ff7+D2qrJnks
# wcYdK6pGKu7GGGr4/s0wfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBS
# U0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABV2d1pJij5+OIAAAAAAFUwggNe
# BgsqhkiG9w0BCRACEjGCA00wggNJoYIDRTCCA0EwggIpAgEBMIIBCaGB4aSB3jCB
# 2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMc
# TWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBU
# U1MgRVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGlj
# IFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUAHTtU
# AYJlv7bgWVeRBo4X7FeHDeqgZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDtueOw
# MCIYDzIwMjYwNTIxMjAwNDAwWhgPMjAyNjA1MjIyMDA0MDBaMHQwOgYKKwYBBAGE
# WQoEATEsMCowCgIFAO2547ACAQAwBwIBAAICA4QwBwIBAAICEl0wCgIFAO27NTAC
# AQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEK
# MAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAQYjpk0zBAxZzCTGGVKY4nf+L
# xygifeZa7vk0JWXmUL4htxWHQSxX/yg9GeSBpjt+F54NJ9ntOg8VS2Lsoi1kYvZ3
# UrbUPCdKmh9S4RJrQPzA1am8NUu+mOkGzi4zisxIziIdoCAngJbIeg9pI4v1b/2P
# MO0aKPIbvr8qyiI5LiCKBtiRWQnyQ+GH033HC3ynwoeLPoQKPZiH7cIUxDgP5RYl
# Rt5RorVbWX5F/bYyPgguxfswPCFJMJwz1Kio3apcOo73dgXT0WgLDM53qQv5kHTg
# 7GZ/bbydQqr7ACxRKdQH2cmJgUbpo8uDwDEJSJwa0j7zBFONG49JLcG+kFlIdDAN
# BgkqhkiG9w0BAQEFAASCAgB5v3T0LjRVQr1trwQkbPeIKnM6kDwZlwpeoode8Ei5
# lFjtk+MkpxCKZJyexZvewkKxAGqx4sKz6qa8Zp35Ipr/p0OzD0Lb+cMLLqs41u/0
# oFuECv1shLJZgmH3dqbqHdHhv7bjisfS74wU6+H4ypINi+Z2Tzt3Gx3SOQal9Pvx
# das0XzG/e54ns/uVz0dEP5vej0N0zBS0AzBrfFIgPwE+fdBj3O5lBuF5qBLFKFQ/
# t88wUGQEC+aZfXM9hEMwv08Aj9oIA0qcGPpJkf4FENGFnwgsLtmL3oVP4g3OgP+D
# LlQh+j3+3B0fZvh7SNYwdXPVXG16OtWjyX+CKOnCtRhsHCBkpmW/ZDhPNrqfv/aX
# i528CYaCVeKG/iqItjVElU451Lsf9A1WbFfQNSlNibxetENmCEQgv1/sbqoi3mFz
# 7W8vJYtuWjoHTlMpnlUGCpkjmdEsu3gB/xiqpYs6HKykLsUcZCTZx/Teh8+ydoqc
# pSAZkBh1SuTaZ6a01tZaxtspwNMLvHSC2P2IncDiXzEBboIyG+XlJglGMV5R4fPL
# WJfmm8GUvvooVrP/hJCwywwtqreB7ISiq8v7taIKtWpyoCBumsUVzbwN+naJ+ZA3
# X/n6fiv9oMw68yUuukfBjn1jjCqa9qSzziMFQE3kOvqTwaJLTfD6ipsYEYgOzKpK
# xw==
# SIG # End signature block
