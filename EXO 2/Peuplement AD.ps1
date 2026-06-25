#Chargement du module Active Directory
Write-Host "[ETAPE 1] Chargement du module Active Directory..." -ForegroundColor Yellow
Import-Module ActiveDirectory
Write-Host "Module charge avec succes." -ForegroundColor Green
Write-Host ""

# Récupération des informations du domaine

# On obtient le DN du domaine pour construire les chemins des OU
Write-Host "[ETAPE 2] Recuperation des informations du domaine..." -ForegroundColor Yellow

$DomainDN = Get-ADDomain | Select-Object -ExpandProperty DistinguishedName
Write-Host "Domaine détecté : $DomainDN" -ForegroundColor Cyan
Write-Host ""


#Creation des UO

# 
Write-Host "[ETAPE 3] Creation de la structure des OU..." -ForegroundColor Yellow

# OU Racine : LaPlateforme
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'LaPlateforme'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "LaPlateforme" -Path $DomainDN
    Write-Host "  [OK] OU 'LaPlateforme' cree" -ForegroundColor Green
} else {
    Write-Host "  [OK] OU 'LaPlateforme' existe deja " -ForegroundColor Yellow
}

# UO Utilisateurs
$LaPlateformeDN = "OU=LaPlateforme,$DomainDN"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Utilisateurs'" -SearchBase $LaPlateformeDN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "Utilisateurs" -Path $LaPlateformeDN
    Write-Host "  [OK] OU 'Utilisateurs' cree" -ForegroundColor Green
} else {
    Write-Host "  [OK] OU 'Utilisateurs' existe dejÃ " -ForegroundColor Yellow
}

# UO Groupes
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Groupes'" -SearchBase $LaPlateformeDN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "Groupes" -Path $LaPlateformeDN
    Write-Host "  [OK] OU 'Groupes' cree" -ForegroundColor Green
} else {
    Write-Host "  [OK] OU 'Groupes' existe dejÃ " -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Structure des OU cree." -ForegroundColor Green
Write-Host ""


#Selection graphique du fichier CSV

Write-Host "[ETAPE 4] Ouverture de la fenetre de selection du fichier CSV..." -ForegroundColor Yellow
Write-Host ""

# Chargement du module Windows Forms
Add-Type -AssemblyName System.Windows.Forms

# Creation de la fenetre de selection de fichier
$Dialog = New-Object System.Windows.Forms.OpenFileDialog
$Dialog.Filter = "Fichiers CSV (*.csv)|*.csv|Tous les fichiers (*.*)|*.*"
$Dialog.Title = "SÃ©lectionnez le fichier CSV des utilisateurs"
$Dialog.InitialDirectory = "C:\"

# Afficher la fenetre et recuperer le choix
$Resultat = $Dialog.ShowDialog()

# Si l'utilisateur annule, fin de script
if ($Resultat -ne "OK") {
    Write-Host "ERREUR : Aucun fichier selectionne. Annulation." -ForegroundColor Red
    exit
}

$CheminCSV = $Dialog.FileName
Write-Host "Fichier selectionne : $CheminCSV" -ForegroundColor Cyan
Write-Host ""

#Definition du mot de passe par défaut

Write-Host "[ETAPE 5] Configuration du mot de passe par defaut..." -ForegroundColor Yellow

$MotDePasse = ConvertTo-SecureString -String "Azerty_2025!" -AsPlainText -Force
Write-Host "Mot de passe defini : Azerty_2025!" -ForegroundColor Green
Write-Host ""

# FONCTION : Supprimer les accents d'une chaine

function Remove-Accents {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Texte
    )
    
    #suppresion des accents

    $Normalise = $Texte.Normalize([Text.NormalizationForm]::FormD)
    $SansAccent = $Normalise -replace '\p{M}', ''
    
    return $SansAccent
}

# Import des utilisateurs depuis le CSV

Write-Host "[ETAPE 6] Importation des utilisateurs depuis le fichier CSV..." -ForegroundColor Yellow
Write-Host ""

# Importation du CSV avec separateur point-virgule et encodage UTF-8
$Utilisateurs = Import-Csv -Path $CheminCSV -Delimiter ';' -Encoding UTF8

# Compteurs pour le resume final
$NbCrees = 0
$NbExistants = 0
$GroupesCrees = 0
$GroupesExistants = 0

# Liste des groupes deja  traites (pour Ã©viter les messages redondants)
$GroupesDejaTraites = @{}

foreach ($User in $Utilisateurs) {
    # ---- Construction du SamAccountName et de l'UPN (sans accents) ----
    $PrenomClean = Remove-Accents -Texte $User.prenom
    $NomClean = Remove-Accents -Texte $User.nom
    
    # SamAccountName : prenom.nom en minuscules (ex: marc.thillot)
    $SamAccountName = ($PrenomClean + "." + $NomClean).ToLower()
    
    # UPN : prenom.nom@laplateforme.io (ex: marc.thillot@laplateforme.io)
    $UPN = $SamAccountName + "@laplateforme.io"
    
    # Nom d'affichage complet (ex: MARC THILLOT)
    $DisplayName = $User.prenom.ToUpper() + " " + $User.nom.ToUpper()
    
    # ---- Verifier si l'utilisateur existe dejÃ  ----
    $Existant = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
    
    if ($Existant) {
        # L'utilisateur existe deja , on passe au suivant
        Write-Host "  [AVERT] L'utilisateur '$SamAccountName' existe deja." -ForegroundColor Yellow
        $NbExistants++
    } else {
        # ---- Creer l'utilisateur ----
        New-ADUser `
            -Name $DisplayName `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UPN `
            -GivenName $User.prenom `
            -Surname $User.nom `
            -DisplayName $DisplayName `
            -Path "OU=Utilisateurs,OU=LaPlateforme,$DomainDN" `
            -AccountPassword $MotDePasse `
            -Enabled $true `
            -ChangePasswordAtLogon $true
        
        Write-Host "  [OK] Utilisateur '$SamAccountName' cree" -ForegroundColor Green
        $NbCrees++
    }
    
    # ---- Gestion des groupes ----
    # On parcourt les colonnes groupe1 Ã  groupe6
    $Groupes = @($User.groupe1, $User.groupe2, $User.groupe3, $User.groupe4, $User.groupe5, $User.groupe6)
    
    foreach ($Groupe in $Groupes) {
        # On ignore les groupes vides
        if ([string]::IsNullOrWhiteSpace($Groupe)) {
            continue
        }
        
        # Nettoyage du nom du groupe (suppression des accents)
        $GroupeClean = Remove-Accents -Texte $Groupe.Trim()
        $GroupeKey = $GroupeClean.ToLower()
        
        # Verifier si le groupe existe deja 
        $GroupeExistant = Get-ADGroup -Filter "Name -eq '$GroupeClean'" -SearchBase "OU=Groupes,OU=LaPlateforme,$DomainDN" -ErrorAction SilentlyContinue
        
        if (-not $GroupeExistant) {
            # Creer le groupe s'il n'existe pas encore
            if (-not $GroupesDejaTraites.ContainsKey($GroupeKey)) {
                New-ADGroup `
                    -Name $GroupeClean `
                    -Path "OU=Groupes,OU=LaPlateforme,$DomainDN" `
                    -GroupScope Global `
                    -GroupCategory Security
                
                Write-Host "    [+] Groupe '$GroupeClean' cree" -ForegroundColor Green
                $GroupesCrees++
                $GroupesDejaTraites[$GroupeKey] = $true
            }
        } else {
            if (-not $GroupesDejaTraites.ContainsKey($GroupeKey)) {
                Write-Host "    [INFO] Groupe '$GroupeClean' existe deja " -ForegroundColor Yellow
                $GroupesExistants++
                $GroupesDejaTraites[$GroupeKey] = $true
            }
        }
        
        # Ajouter l'utilisateur au groupe
        if ($SamAccountName) {
            try {
                Add-ADGroupMember -Identity $GroupeClean -Members $SamAccountName -ErrorAction Stop
            } catch {
                # L'erreur " Member already exists " est normale, on l'ignore
                if ($_.Exception.Message -notmatch "already") {
                    Write-Host "    [!] Erreur ajout '$SamAccountName' Ã  '$GroupeClean' : $_" -ForegroundColor Red
                }
            }
        }
    }
}


# Resume de l'operation

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RESULTAT DE L'IMPORTATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Utilisateurs crees    : $NbCrees" -ForegroundColor Green
Write-Host "Utilisateurs ignores  : $NbExistants" -ForegroundColor Yellow
Write-Host "Groupes crees         : $GroupesCrees" -ForegroundColor Green
Write-Host "Groupes deja  existants: $GroupesExistants" -ForegroundColor Yellow
Write-Host ""
Write-Host "Operation terminee" -ForegroundColor Green

