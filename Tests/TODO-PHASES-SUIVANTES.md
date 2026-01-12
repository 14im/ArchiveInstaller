# Phases Suivantes - Tests ArchiveInstaller

## État Actuel ✅

### Phase 1 : Infrastructure - TERMINÉE
- ✅ Structure de répertoires créée
- ✅ Fixtures/GitHubResponses.ps1
- ✅ Fixtures/ChecksumFiles.ps1
- ✅ Helpers/MockHelpers.ps1
- ✅ Tests/Run-Tests.ps1

### Phase 2 : Tests Prioritaires - TERMINÉE
- ✅ Unit/Private/Download-File.Tests.ps1 (30+ tests)
- ✅ Unit/Private/Test-Checksum.Tests.ps1 (25+ tests)
- ✅ Unit/Private/Get-GitHubAssetChecksum.Tests.ps1 (35+ tests)
- ✅ Unit/Classes/ArchiveInstaller.Tests.ps1 (40+ tests)

**Total : ~130 tests implémentés**

---

## Phase 3 : Classes Dérivées (5 fichiers)

### 3.1 Unit/Classes/GitArchiveInstaller.Tests.ps1

```powershell
BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\ArchiveInstaller\ArchiveInstaller.psd1"
    Import-Module $modulePath -Force
}

Describe "GitArchiveInstaller Class" -Tag 'Unit', 'Classes' {
    Context "Constructor" {
        It "Should set correct default values" {
            $installer = [GitArchiveInstaller]::new()

            $installer.GithubRepositoryOwner | Should -Be 'git-for-windows'
            $installer.GithubRepositoryName | Should -Be 'git'
            $installer.ArchiveGlob | Should -Be '*-64-bit.zip'
        }

        It "Should inherit from ArchiveInstaller" {
            $installer = [GitArchiveInstaller]::new()
            $installer -is [ArchiveInstaller] | Should -Be $true
        }
    }

    Context "GetGitHubDownloadUrl Method" {
        It "Should query git-for-windows/git repository" {
            Mock Invoke-RestMethod {
                $Uri | Should -Match "git-for-windows/git"
                return @{
                    assets = @(
                        @{ name = "Git-2.43.0-64-bit.zip"; browser_download_url = "https://example.com/git.zip" }
                    )
                }
            }

            $installer = [GitArchiveInstaller]::new()
            $url = $installer.GetGitHubDownloadUrl()

            $url | Should -Match "git.zip"
        }

        It "Should filter by 64-bit glob pattern" {
            # Test que seuls les assets 64-bit sont sélectionnés
        }
    }
}
```

**Tests à implémenter :**
- Constructor sets GithubRepositoryOwner = 'git-for-windows'
- Constructor sets GithubRepositoryName = 'git'
- Constructor sets ArchiveGlob = '*-64-bit.zip'
- Inherits all base class functionality
- GetGitHubDownloadUrl queries correct repository
- Glob pattern filters correctly for 64-bit archives

**Estimation : 8-10 tests**

---

### 3.2 Unit/Classes/PowershellArchiveInstaller.Tests.ps1

**Tests à implémenter :**
- Constructor sets GithubRepositoryOwner = 'PowerShell'
- Constructor sets GithubRepositoryName = 'PowerShell'
- Constructor sets ArchiveGlob = 'PowerShell-*-x64.zip'
- Inherits from ArchiveInstaller
- GetGitHubDownloadUrl queries PowerShell/PowerShell repository
- Glob pattern filters PowerShell x64 zip files

**Estimation : 8-10 tests**

---

### 3.3 Unit/Classes/VSCodeArchiveInstaller.Tests.ps1

**Tests à implémenter :**
- Constructor sets DownloadUrl to VS Code stable download URL
- Constructor sets ArchiveGlob = 'VSCode-win32-x64-*.zip'
- Does NOT use GitHub API (direct URL)
- Download method works with direct URL
- GetDownloadArchive resolves VS Code filename correctly

**Estimation : 8-10 tests**

---

### 3.4 Unit/Classes/WindowsTerminalArchiveInstaller.Tests.ps1

**Tests à implémenter :**
- Constructor sets GithubRepositoryOwner = 'microsoft'
- Constructor sets GithubRepositoryName = 'terminal'
- Constructor sets ArchiveGlob = 'Microsoft.WindowsTerminal_*x64.zip'
- ExtractLastLocalArchive() overridden method
- Subdirectory flattening logic (moves contents up one level)
- Removes empty subdirectory after extraction

**Estimation : 12-15 tests** (plus complexe à cause de l'override)

---

### 3.5 Unit/Classes/PowershellVSCodeExtensionArchiveInstaller.Tests.ps1

**Tests à implémenter :**
- Constructor sets GithubRepositoryOwner = 'PowerShell'
- Constructor sets GithubRepositoryName = 'vscode-powershell'
- Constructor sets ArchiveGlob = 'powershell-*.vsix'
- Downloads .vsix files (not .zip)
- Inherits base functionality

**Estimation : 8-10 tests**

---

## Phase 4 : Fonctions Publiques (10 fichiers)

### 4.1 Tests Get-*Archive (5 fichiers)

#### Unit/Public/Get-PowerShellArchive.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Get-PowerShellArchive" -Tag 'Unit', 'Public' {
    Context "Download Operations" {
        It "Should download from GitHub releases"
        It "Should skip if file exists without -Force"
        It "Should re-download with -Force"
        It "Should create DownloadDirectory if missing"
        It "Should use custom DownloadDirectory when specified"
    }

    Context "Checksum Verification" {
        It "Should verify checksum when -VerifyChecksum specified"
        It "Should throw when checksum mismatch"
        It "Should warn when checksum not found without -Strict"
        It "Should throw when checksum not found with -Strict"
        It "Should use ChecksumFile parameter if provided"
        It "Should download remote ChecksumFile if URL provided"
    }

    Context "Download Methods" {
        It "Should use FastDownload when specified"
        It "Should use standard download without FastDownload"
    }

    Context "Parameter Validation" {
        It "Should accept valid DownloadDirectory"
        It "Should work without any optional parameters"
    }

    Context "Integration with Class" {
        It "Should create PowershellArchiveInstaller instance"
        It "Should call Download-File internally"
        It "Should return file path"
    }
}
```

**Estimation : 15-18 tests**

#### Unit/Public/Get-Git.Tests.ps1
- Même structure que Get-PowerShellArchive.Tests.ps1
- Utilise GitArchiveInstaller
- **Estimation : 15-18 tests**

#### Unit/Public/Get-VSCodeArchive.Tests.ps1
- Même structure que Get-PowerShellArchive.Tests.ps1
- Utilise VSCodeArchiveInstaller
- Direct URL (pas GitHub)
- **Estimation : 12-15 tests**

#### Unit/Public/Get-WindowsTerminalArchive.Tests.ps1
- Même structure que Get-PowerShellArchive.Tests.ps1
- Utilise WindowsTerminalArchiveInstaller
- **Estimation : 15-18 tests**

#### Unit/Public/Get-PowershellVSCodeExtension.Tests.ps1
- Même structure que Get-PowerShellArchive.Tests.ps1
- Télécharge .vsix (pas .zip)
- **Estimation : 15-18 tests**

---

### 4.2 Tests Expand-*Archive (3 fichiers)

#### Unit/Public/Expand-PowerShellArchive.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Expand-PowerShellArchive" -Tag 'Unit', 'Public' {
    Context "Extraction Operations" {
        It "Should extract archive to default destination"
        It "Should skip if destination exists without -Force"
        It "Should extract with -Force when destination exists"
        It "Should create destination directory if missing"
    }

    Context "PATH Management" {
        It "Should add to PATH when -AddPath specified"
        It "Should not modify PATH without -AddPath"
        It "Should add to CurrentUser scope"
    }

    Context "WhatIf Support" {
        It "Should support -WhatIf"
        It "Should not extract with -WhatIf"
        It "Should support -Confirm"
    }

    Context "Integration" {
        It "Should call ExtractLastLocalArchive"
        It "Should call Add-Path when -AddPath specified"
        It "Should return extraction path"
    }
}
```

**Estimation : 12-15 tests**

#### Unit/Public/Expand-VSCodeArchive.Tests.ps1
- Même structure que Expand-PowerShellArchive.Tests.ps1
- **Estimation : 12-15 tests**

#### Unit/Public/Expand-WindowsTerminalArchive.Tests.ps1
- Même structure que Expand-PowerShellArchive.Tests.ps1
- Teste la logique de flattening des sous-répertoires
- **Estimation : 15-18 tests**

---

### 4.3 Tests Install-* (2 fichiers)

#### Unit/Public/Install-Git.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Install-Git" -Tag 'Unit', 'Public' {
    Context "Installation" {
        It "Should extract Git archive"
        It "Should skip if destination exists without -Force"
        It "Should extract with -Force"
    }

    Context "PATH Management" {
        It "Should add mingw64/bin to PATH when -AddPath specified"
        It "Should not modify PATH without -AddPath"
        It "Should add correct subdirectory (mingw64/bin)"
    }

    Context "WhatIf Support" {
        It "Should support -WhatIf"
        It "Should support -Confirm"
    }
}
```

**Estimation : 10-12 tests**

#### Unit/Public/Install-PowershellVSCodeExtension.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Install-PowershellVSCodeExtension" -Tag 'Unit', 'Public' {
    Context "VS Code Detection" {
        It "Should find VS Code installation automatically"
        It "Should use VSCodeDirectory parameter if provided"
        It "Should throw if VS Code not found"
        It "Should validate code.cmd launcher exists"
    }

    Context "VSIX Processing" {
        It "Should read VSIX manifest"
        It "Should extract extension ID from manifest"
        It "Should check if extension already installed"
        It "Should skip if installed without -Force"
        It "Should reinstall with -Force"
    }

    Context "Portable Mode" {
        It "Should create data directory with -Portable"
        It "Should not create data directory without -Portable"
    }

    Context "Installation" {
        It "Should call code.cmd --install-extension"
        It "Should pass correct VSIX path"
        It "Should return extension ID"
    }

    Context "WhatIf Support" {
        It "Should support -WhatIf"
        It "Should not install with -WhatIf"
    }
}
```

**Estimation : 18-20 tests**

---

### 4.4 Unit/Private/Add-Path.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Add-Path" -Tag 'Unit', 'Private' {
    Context "User Scope" {
        It "Should add path to HKCU registry"
        It "Should read current PATH from HKCU"
        It "Should append new path with semicolon"
        It "Should skip if path already exists"
        It "Should update $env:Path in current session"
        It "Should trigger environment variable notification"
    }

    Context "Machine Scope" {
        It "Should add path to HKLM registry when admin"
        It "Should throw when not admin for Machine scope"
        It "Should check admin privileges"
    }

    Context "Scope Parameter" {
        It "Should accept 'User' scope"
        It "Should accept 'CurrentUser' scope"
        It "Should accept 'Machine' scope"
        It "Should accept 'LocalMachine' scope"
    }

    Context "Path Handling" {
        It "Should handle paths with spaces"
        It "Should deduplicate existing paths"
        It "Should split PATH by semicolon"
        It "Should remove empty entries"
    }

    Context "Error Handling" {
        It "Should validate LiteralPath parameter is mandatory"
        It "Should throw if directory does not exist"
    }
}
```

**Estimation : 20-22 tests**

---

## Phase 5 : Tests d'Intégration (4 fichiers)

### 5.1 Integration/Download-Flow.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Download Flow Integration" -Tag 'Integration' {
    Context "Complete Download Workflow" {
        It "Should: GitHub API → Download-File → Save to disk"
        It "Should fallback through BITS → HttpClient → WebRequest"
        It "Should handle GitHub API rate limiting"
    }

    Context "Download with Checksum" {
        It "Should: Download archive → Download checksum → Verify"
        It "Should fail on checksum mismatch"
        It "Should warn on missing checksum"
    }

    Context "Force Download" {
        It "Should skip existing file without -Force"
        It "Should re-download with -Force"
    }
}
```

**Estimation : 12-15 tests**

---

### 5.2 Integration/Checksum-Flow.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Checksum Verification Flow" -Tag 'Integration' {
    Context "End-to-End Checksum" {
        It "Should: Get-GitHubAssetChecksum → Download checksum file → Parse → Test-Checksum"
        It "Should handle various checksum file formats"
        It "Should validate hash format (64 hex chars)"
    }

    Context "Checksum Sources" {
        It "Should use ChecksumFile parameter if provided (local)"
        It "Should download ChecksumFile if URL provided"
        It "Should fallback to GitHub asset if no ChecksumFile"
    }

    Context "Strict Mode" {
        It "Should warn without -Strict when checksum missing"
        It "Should throw with -Strict when checksum missing"
    }
}
```

**Estimation : 10-12 tests**

---

### 5.3 Integration/Install-Flow.Tests.ps1

**Scénarios de test :**
```powershell
Describe "Complete Installation Flow" -Tag 'Integration' {
    Context "Full Workflow" {
        It "Should: Get-*Archive → Expand-*Archive → (optional) Add-Path"
        It "Should work for PowerShell installation"
        It "Should work for Git installation"
        It "Should work for VS Code installation"
        It "Should work for Windows Terminal installation"
    }

    Context "PATH Updates" {
        It "Should add to PATH with -AddPath"
        It "Should not duplicate PATH entries"
        It "Should update current session"
    }

    Context "Error Recovery" {
        It "Should handle partial downloads gracefully"
        It "Should not corrupt existing installations"
    }
}
```

**Estimation : 15-18 tests**

---

### 5.4 Integration/Path-Management.Tests.ps1

**Scénarios de test :**
```powershell
Describe "PATH Management Integration" -Tag 'Integration' {
    Context "User Scope PATH" {
        It "Should add path to user registry"
        It "Should persist across PowerShell sessions"
        It "Should update current session immediately"
    }

    Context "Machine Scope PATH" {
        It "Should require admin privileges"
        It "Should add to machine registry when admin"
        It "Should throw when not admin"
    }

    Context "Deduplication" {
        It "Should not add duplicate paths"
        It "Should handle paths with different casing"
        It "Should handle paths with trailing slashes"
    }

    Context "Multiple Installations" {
        It "Should handle multiple tools adding to PATH"
        It "Should preserve existing PATH entries"
    }
}
```

**Estimation : 15-18 tests**

---

## Phase 6 : Tests E2E (4 fichiers)

### 6.1 E2E/PowerShell-E2E.Tests.ps1

**Scénarios de test :**
```powershell
Describe "PowerShell End-to-End" -Tag 'E2E', 'Slow' {
    Context "Complete PowerShell Installation" {
        It "Should download PowerShell archive" -Skip:($env:CI -eq $true) {
            # Test réel - seulement en local
        }

        It "Should mock complete workflow in CI" {
            # Mock tout pour CI/CD
            $archive = Get-PowerShellArchive -DownloadDirectory $TestDrive
            $extracted = Expand-PowerShellArchive -DownloadDirectory $TestDrive

            Test-Path $archive | Should -Be $true
            Test-Path $extracted | Should -Be $true
        }

        It "Should verify checksum" {
            # Test avec vérification checksum
        }

        It "Should extract and be executable" {
            # Test que pwsh.exe existe après extraction
        }
    }
}
```

**Estimation : 8-10 tests**

---

### 6.2 E2E/Git-E2E.Tests.ps1

**Structure similaire à PowerShell-E2E.Tests.ps1**

**Scénarios spécifiques à Git :**
- Installation complète
- Vérification de mingw64/bin
- Ajout au PATH
- Test que git.exe fonctionne

**Estimation : 8-10 tests**

---

### 6.3 E2E/VSCode-E2E.Tests.ps1

**Scénarios spécifiques à VS Code :**
- Téléchargement depuis URL directe (pas GitHub)
- Extraction
- Vérification de Code.exe
- Installation d'extension PowerShell

**Estimation : 10-12 tests**

---

### 6.4 E2E/WindowsTerminal-E2E.Tests.ps1

**Scénarios spécifiques à Windows Terminal :**
- Téléchargement depuis GitHub
- Extraction avec flattening de sous-répertoires
- Vérification de wt.exe

**Estimation : 8-10 tests**

---

## Résumé des Phases

| Phase | Fichiers | Tests Estimés | Priorité |
|-------|----------|---------------|----------|
| **Phase 1** (✅) | 4 fichiers | Infrastructure | FAIT |
| **Phase 2** (✅) | 4 fichiers | ~130 tests | FAIT |
| **Phase 3** | 5 fichiers | ~50 tests | HAUTE |
| **Phase 4** | 11 fichiers | ~180 tests | HAUTE |
| **Phase 5** | 4 fichiers | ~55 tests | MOYENNE |
| **Phase 6** | 4 fichiers | ~40 tests | BASSE |
| **TOTAL** | **32 fichiers** | **~455 tests** | |

---

## Ordre d'Implémentation Recommandé

### Semaine 1 (✅ FAIT)
- ✅ Phase 1 : Infrastructure
- ✅ Phase 2 : Tests prioritaires (4 fichiers)

### Semaine 2
- Phase 3 : Classes dérivées (5 fichiers)
  - Commencer par GitArchiveInstaller et PowershellArchiveInstaller (plus simples)
  - Terminer par WindowsTerminalArchiveInstaller (plus complexe)

### Semaine 3
- Phase 4.1 : Tests Get-*Archive (5 fichiers)
- Phase 4.4 : Add-Path.Tests.ps1

### Semaine 4
- Phase 4.2 : Tests Expand-*Archive (3 fichiers)
- Phase 4.3 : Tests Install-* (2 fichiers)

### Semaine 5
- Phase 5 : Tests d'intégration (4 fichiers)

### Semaine 6
- Phase 6 : Tests E2E (4 fichiers)
- Corrections et ajustements finaux

---

## Commandes Utiles

### Exécuter les tests déjà créés
```powershell
# Tous les tests actuels
.\Tests\Run-Tests.ps1

# Seulement tests unitaires
.\Tests\Run-Tests.ps1 -TestType Unit

# Avec couverture de code
.\Tests\Run-Tests.ps1 -TestType All -CodeCoverage
```

### Créer un nouveau fichier de test
```powershell
# Template de base
$template = @"
BeforeAll {
    `$modulePath = "`$PSScriptRoot\..\..\..\ArchiveInstaller\ArchiveInstaller.psd1"
    Import-Module `$modulePath -Force
}

Describe "FunctionName" -Tag 'Unit', 'Public' {
    Context "Basic Functionality" {
        It "Should do something" {
            # Test code
        }
    }
}
"@

$template | Out-File "Tests\Unit\Public\FunctionName.Tests.ps1"
```

### Vérifier la couverture actuelle
```powershell
$config = New-PesterConfiguration
$config.Run.Path = ".\Tests\Unit"
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = ".\ArchiveInstaller"
$result = Invoke-Pester -Configuration $config
$result.CodeCoverage.CoveragePercent
```

---

## Notes d'Implémentation

### Priorités
1. **HAUTE** : Tests des classes et fonctions publiques (utilisateurs en dépendent)
2. **MOYENNE** : Tests d'intégration (validation des workflows)
3. **BASSE** : Tests E2E (validation finale, peuvent être skipped en CI)

### Conventions
- Utiliser `-Tag 'Unit'`, `-Tag 'Integration'`, ou `-Tag 'E2E'`
- Ajouter `-Tag 'Slow'` pour tests lents (>1s)
- Utiliser `BeforeAll` pour setup, `BeforeEach` pour reset entre tests
- Mock toutes les opérations externes (HTTP, file system en production)
- Utiliser `$TestDrive` pour opérations fichier
- Préfixer variables de script avec `$script:`

### Métriques de Qualité
- **Couverture cible** : >80% sur chemins critiques
- **Performance** : Tests unitaires <100ms chacun
- **Fiabilité** : Tests doivent passer 100% du temps
- **Isolation** : Chaque test doit être indépendant

---

## Fichiers Créés (État Actuel)

```
Tests/
├── ✅ Run-Tests.ps1
├── ✅ Fixtures/
│   ├── ✅ GitHubResponses.ps1
│   └── ✅ ChecksumFiles.ps1
├── ✅ Helpers/
│   └── ✅ MockHelpers.ps1
├── ✅ Unit/
│   ├── ✅ Private/
│   │   ├── ✅ Download-File.Tests.ps1
│   │   ├── ✅ Test-Checksum.Tests.ps1
│   │   └── ✅ Get-GitHubAssetChecksum.Tests.ps1
│   ├── ✅ Classes/
│   │   └── ✅ ArchiveInstaller.Tests.ps1
│   └── Public/
├── Integration/
└── E2E/
```

**Progression : 9/32 fichiers (28%)**
**Tests créés : ~130/455 (29%)**
