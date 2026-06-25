# Avertissement et confirmation de l'adresse IP du serveur

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "  ATTENTION : Verifiez votre configuration IP" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "- Assurez-vous que le serveur a une IP STATIQUE configuree" -ForegroundColor Yellow
Write-Host "- Le script va recuperer automatiquement l'IP actuelle" -ForegroundColor Yellow
Write-Host "  et l'utiliser comme serveur DNS local" -ForegroundColor Yellow
Write-Host ""
Write-Host "Appuyez sur [Entree] pour continuer ou [Ctrl+C] pour annuler" -ForegroundColor Yellow
Write-Host ""


# Detection automatique et récupération de l'IP du serveur, sont exclu adresse loopback et APIPA


Write-Host "[ETAPE 2] Detection de l'adresse IP du serveur..." -ForegroundColor Cyan

$IPServeur = (Get-NetIPAddress -AddressFamily IPv4 `
    | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } `
    | Select-Object -First 1).IPAddress

Write-Host "IP detectee : $IPServeur" -ForegroundColor Green
Write-Host ""


# Configuration du DNS

Write-Host "[ETAPE 3] Configuration du serveur DNS sur l'interface active..." -ForegroundColor Cyan

$Interface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).Name
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $IPServeur

Write-Host "DNS configure sur l'interface : $Interface" -ForegroundColor Green
Write-Host ""

#Installation du role AD DS et outils d'administration AD


Write-Host "[ETAPE 4] Installation du role AD DS..." -ForegroundColor Cyan

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "Role AD DS installe avec succes." -ForegroundColor Green
Write-Host ""

# Promotion en controleur de domaine

# Parametres utilises :
#   - DomainName         : nom du domaine (laplateforme.io)
#   - SafeModeAdministratorPassword : mot de passe DSRM
#                                  (DSRM = Directory Services Restore Mode)
#   - DomainMode/ForestMode : par defaut (fonctionnels pour Server 2025)

Write-Host "[ETAPE 5] Promotion en controleur de domaine..." -ForegroundColor Cyan
Write-Host "Domaine : laplateforme.io" -ForegroundColor Yellow
Write-Host "Mot de passe DSRM : P@ssword" -ForegroundColor Yellow
Write-Host ""

$MotDePasse = ConvertTo-SecureString "P@ssword" -AsPlainText -Force

Install-ADDSForest `
    -DomainName "laplateforme.io" `
    -SafeModeAdministratorPassword $MotDePasse `
    -Force:$true

Write-Host "Promotion terminee. Le serveur redemarre." -ForegroundColor Green