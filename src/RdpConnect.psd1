#
# Module manifest for module 'RdpConnect'
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'RdpConnect.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = 'ef073fd7-239d-47e0-bb77-7d862cb14783'

    # Author of this module
    Author = 'hunandy14'

    # Company or vendor of this module
    CompanyName = 'Personal'

    # Copyright statement for this module
    Copyright = '(c) 2025 hunandy14. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'RDP connection manager with automatic resolution scaling, DPI-aware window positioning, and password clipboard support. Supports multiple connection modes (default ratio, maximized, full screen, custom) and CSV-based server management.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Connect-RdpSession',
        'Show-RdpServerList',
        'Show-RdpManager',
        'Install-RdpConnectModule',
        'Export-RdpBatchLauncher'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @(
        'rdpConnect',
        'rdpMgr',
        'rdpManager',
        'Install',
        'WrapUp2Bat'
    )

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
                'RDP',
                'RemoteDesktop',
                'Windows',
                'Connection',
                'Resolution',
                'Scaling',
                'DPI',
                'Automation',
                'Password',
                'Clipboard',
                'CSV',
                'PSEdition_Desktop'
            )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/hunandy14/rdpConnect/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/hunandy14/rdpConnect'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 2.0.0 (2025-01-28)

### Breaking Changes
- Renamed all functions to follow PowerShell Verb-Noun naming conventions
- Restructured to standard PowerShell module layout (Public/Private separation)
- Aliases provided for backward compatibility (rdpConnect, rdpMgr, Install, WrapUp2Bat)

### New Features
- Modular architecture with Public/Private function separation
- Multiple build modes: Standard module, Merged module, Standalone script
- Enhanced Comment-Based Help for all functions
- Verbose logging support for troubleshooting
- Improved error handling and validation

### Improvements
- Better DPI scaling algorithm documentation
- Enhanced encoding handling for international characters
- Cleaner code organization (one function per file)
- Prepared for PowerShell Gallery publication

### Bug Fixes
- Fixed taskbar height calculation with manual adjustment
- Corrected encoding issues in BAT launcher
- Improved template loading fallback mechanisms

### Migration Guide
Old function names still work via aliases - no code changes required for existing scripts.

New names:
- rdpConnect → Connect-RdpSession (alias: rdpConnect)
- rdpMgr → Show-RdpServerList (alias: rdpMgr)
- Install → Install-RdpConnectModule (alias: Install)
- WrapUp2Bat → Export-RdpBatchLauncher (alias: WrapUp2Bat)

For full documentation, visit: https://github.com/hunandy14/rdpConnect
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
