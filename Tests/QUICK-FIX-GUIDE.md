# Guide Rapide - Correction des Tests

**Date :** 2026-01-12
**Problème :** Classes et fonctions privées non accessibles dans les tests

---

## 🐛 Problème Identifié

Lors de l'exécution de `.\Run-Tests.ps1 -TestType Unit`, erreurs :

```
RuntimeException: Unable to find type [ArchiveInstaller].
CommandNotFoundException: The term 'Get-GitHubAssetChecksum' is not recognized...
```

### Cause
Les fonctions privées et les classes ne sont pas exportées par le module, donc non accessibles directement dans les tests même après `Import-Module`.

---

## ✅ Solution : Dot-Sourcing

Pour tester des fonctions privées ou des classes, il faut **dot-sourcer** les fichiers sources directement dans le test.

### Pattern Standard pour Tests

#### Pour Fonctions Privées

```powershell
BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the private function directly for testing
    $privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\FunctionName.ps1" -Resolve
    . $privatePath

    # Load helpers if needed
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)
}
```

#### Pour Classes

```powershell
BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the class file directly for testing
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes\ClassName.ps1" -Resolve
    . $classPath

    # Load fixtures
    . (Join-Path $PSScriptRoot "..\..\Fixtures\GitHubResponses.ps1" -Resolve)
}
```

#### Pour Fonctions Publiques

```powershell
BeforeAll {
    # Import module (fonctions publiques sont automatiquement exportées)
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Load helpers
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)
}
```

---

## 🔧 Fichiers Corrigés

### 1. Download-File.Tests.ps1 ✅
**Problème :** Fonction privée non accessible
**Solution :** Dot-source de `Private/Download-File.ps1`

### 2. Test-Checksum.Tests.ps1 ✅
**Problème :** Fonction privée non accessible
**Solution :** Dot-source de `Private/Test-Checksum.ps1`

### 3. Get-GitHubAssetChecksum.Tests.ps1 ✅
**Problème :** Fonction privée non accessible
**Solution :** Dot-source de `Private/Get-GitHubAssetChecksum.ps1`

### 4. ArchiveInstaller.Tests.ps1 ✅
**Problème :** Classe non accessible (`Unable to find type`)
**Solution :** Dot-source de `Classes/ArchiveInstaller.ps1`

---

## 📝 Points Importants

### Pourquoi Join-Path -Resolve ?

```powershell
# ❌ MAUVAIS - Peut échouer avec chemins relatifs complexes
. "$PSScriptRoot\..\..\..\ArchiveInstaller\Private\Test-Checksum.ps1"

# ✅ BON - Résout le chemin absolu et vérifie l'existence
$privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\Test-Checksum.ps1" -Resolve
. $privatePath
```

Le paramètre `-Resolve` :
- ✅ Convertit en chemin absolu
- ✅ Vérifie que le fichier existe
- ✅ Lance une erreur claire si le fichier est manquant
- ✅ Évite les problèmes de working directory

### Pourquoi Dot-Sourcing ?

```powershell
# ❌ Sans dot-sourcing
Import-Module MyModule
[MyClass]::new()  # Erreur: Unable to find type

# ✅ Avec dot-sourcing
. "$PSScriptRoot\MyClass.ps1"
[MyClass]::new()  # Fonctionne !
```

Le dot-sourcing (`. script.ps1`) :
- Charge le script dans le scope actuel
- Rend les fonctions/classes disponibles
- Nécessaire pour les éléments non exportés

---

## 🎯 Checklist pour Nouveaux Tests

Lors de la création d'un nouveau fichier de test :

### Étape 1 : Identifier le Type
- [ ] Fonction publique ? → Import-Module suffit
- [ ] Fonction privée ? → Dot-source nécessaire
- [ ] Classe ? → Dot-source nécessaire

### Étape 2 : Structure BeforeAll
```powershell
BeforeAll {
    # 1. Import module (toujours)
    $modulePath = Join-Path $PSScriptRoot "..\..\...\Module.psd1" -Resolve
    Import-Module $modulePath -Force

    # 2. Dot-source si privé/classe
    $sourcePath = Join-Path $PSScriptRoot "..\..\...\Source.ps1" -Resolve
    . $sourcePath

    # 3. Load helpers/fixtures
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)
}
```

### Étape 3 : Vérifier les Chemins
```powershell
# Structure du projet
Tests/Unit/Private/MyTest.Tests.ps1
    ↓ ..\..\..\ArchiveInstaller\ArchiveInstaller.psd1  (module)
    ↓ ..\..\..\ArchiveInstaller\Private\MyFunction.ps1  (source)
    ↓ ..\..\Helpers\MockHelpers.ps1                     (helper)
```

### Étape 4 : Tester Localement
```powershell
# Test individuel
Invoke-Pester -Path .\Unit\Private\MyTest.Tests.ps1

# Si erreurs de chemin :
# 1. Vérifier -Resolve ne lance pas d'erreur
# 2. Vérifier nombre de ..\ dans le chemin
# 3. Utiliser Get-ChildItem pour vérifier existence
```

---

## 🚀 Commandes Rapides

### Vérifier les Chemins
```powershell
# Depuis Tests/Unit/Private/
Get-ChildItem "..\..\..\ArchiveInstaller\Private" -Filter *.ps1
Get-ChildItem "..\..\Helpers" -Filter *.ps1
```

### Tester un Fichier
```powershell
# Test unique avec détails
Invoke-Pester -Path .\Unit\Private\MyTest.Tests.ps1 -Output Detailed

# Test avec résumé
Invoke-Pester -Path .\Unit\Private\MyTest.Tests.ps1 -Output Normal
```

### Re-exécuter Tous les Tests
```powershell
cd Tests
.\Run-Tests.ps1 -TestType Unit
```

---

## 📚 Exemples Complets

### Exemple 1 : Test Fonction Privée

**Fichier :** `Tests/Unit/Private/Download-File.Tests.ps1`

```powershell
BeforeAll {
    # Module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Fonction privée
    $privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\Download-File.ps1" -Resolve
    . $privatePath

    # Helpers
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)
}

Describe "Download-File" -Tag 'Unit', 'Private' {
    It "Should download file" {
        Mock Invoke-WebRequest {}
        Download-File -Url "https://test.com/file.zip" -OutFile "$TestDrive\test.zip"
    }
}
```

### Exemple 2 : Test Classe

**Fichier :** `Tests/Unit/Classes/ArchiveInstaller.Tests.ps1`

```powershell
BeforeAll {
    # Module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Classe
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes\ArchiveInstaller.ps1" -Resolve
    . $classPath

    # Fixtures
    . (Join-Path $PSScriptRoot "..\..\Fixtures\GitHubResponses.ps1" -Resolve)
}

Describe "ArchiveInstaller Class" -Tag 'Unit', 'Classes' {
    It "Should create instance" {
        $installer = [ArchiveInstaller]::new()
        $installer | Should -Not -BeNullOrEmpty
    }
}
```

### Exemple 3 : Test Fonction Publique

**Fichier :** `Tests/Unit/Public/Get-PowerShellArchive.Tests.ps1`

```powershell
BeforeAll {
    # Module (fonctions publiques déjà exportées)
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Helpers seulement
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)
}

Describe "Get-PowerShellArchive" -Tag 'Unit', 'Public' {
    It "Should download archive" {
        Mock Download-File {}
        Get-PowerShellArchive -DownloadDirectory $TestDrive
    }
}
```

---

## ⚠️ Pièges Courants

### 1. Oublier -Resolve
```powershell
# ❌ Erreur silencieuse si fichier manquant
. "$PSScriptRoot\..\..\..\File.ps1"

# ✅ Erreur claire si fichier manquant
$path = Join-Path $PSScriptRoot "..\..\..\File.ps1" -Resolve
. $path
```

### 2. Mauvais Nombre de ..\
```powershell
# Tests/Unit/Private/MyTest.Tests.ps1
# ❌ Trop de niveaux
"..\..\..\..\..\ArchiveInstaller\Module.psd1"

# ✅ Bon nombre (3 niveaux : Private → Unit → Tests)
"..\..\..\ArchiveInstaller\Module.psd1"
```

### 3. Dot-Source dans Mauvais Scope
```powershell
# ❌ Dot-source dans It (perdu après le test)
It "Should work" {
    . "$PSScriptRoot\Function.ps1"
    MyFunction  # Fonctionne
}
It "Should still work" {
    MyFunction  # ❌ Erreur !
}

# ✅ Dot-source dans BeforeAll (disponible pour tous)
BeforeAll {
    . "$PSScriptRoot\Function.ps1"
}
It "Should work" {
    MyFunction  # ✅ Fonctionne
}
```

### 4. Oublier Import-Module
```powershell
# ❌ Dépendances manquantes
BeforeAll {
    . "$PSScriptRoot\MyFunction.ps1"  # Peut dépendre d'autres fonctions !
}

# ✅ Import module d'abord
BeforeAll {
    Import-Module "$PSScriptRoot\..\Module.psd1" -Force
    . "$PSScriptRoot\MyFunction.ps1"
}
```

---

## ✅ Validation

Pour vérifier que vos corrections fonctionnent :

```powershell
# 1. Test individuel
Invoke-Pester -Path .\Unit\Private\MyTest.Tests.ps1 -Output Detailed

# 2. Tous les tests unitaires
.\Run-Tests.ps1 -TestType Unit

# 3. Vérifier aucune régression
.\Run-Tests.ps1 -TestType All
```

**Signes de succès :**
- ✅ Pas d'erreur "Unable to find type"
- ✅ Pas d'erreur "not recognized as cmdlet"
- ✅ Tests s'exécutent (même s'ils échouent sur assertions)

---

## 📖 Ressources

- **README.md** - Guide complet
- **TODO-PHASES-SUIVANTES.md** - Roadmap
- **BUG-FIX-REPORT.md** - Corrections précédentes

**Pattern à copier pour nouveaux tests :** Voir exemples ci-dessus ⬆️

---

**Résumé :** Toujours dot-sourcer les fonctions privées et classes avec `Join-Path -Resolve` dans `BeforeAll` ! ✅
