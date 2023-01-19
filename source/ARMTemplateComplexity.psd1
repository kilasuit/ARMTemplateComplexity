@{
    # If authoring a script module, the RootModule is the name of your .psm1 file
    RootModule = 'ARMTemplateComplexity.psm1'

    Author = 'Ryan Yates'

    CompanyName = 'kilasuit.org'

    ModuleVersion = '0.1'

    # Use the New-Guid command to generate a GUID, and copy/paste into the next line
    GUID = '834d331d-6abb-4913-9bf5-2178df9572f5'

    Copyright = '2023 Ryan.Yates@kilasuit.org'

    Description = 'Measures the complexity of ARM Templates and gives out a score'

    # Minimum PowerShell version supported by this module (optional, recommended)
    # PowerShellVersion = ''

    # Which PowerShell Editions does this module work with? (Core, Desktop)
    CompatiblePSEditions = @('Desktop', 'Core')

    # Which PowerShell functions are exported from your module? (eg. Get-CoolObject)
    FunctionsToExport = @('Measure-ARMRepo', 'Measure-ARMTemplate')

    # Which PowerShell aliases are exported from your module? (eg. gco)
    AliasesToExport = @('marmt','marmr')

    # Which PowerShell variables are exported from your module? (eg. Fruits, Vegetables)
    VariablesToExport = @('')

    # PowerShell Gallery: Define your module's metadata
    PrivateData = @{
        PSData = @{
            # What keywords represent your PowerShell module? (eg. cloud, tools, framework, vendor)
            Tags = @('ARMTemplates', 'CodeComplexity')

            # What software license is your code being released under? (see https://opensource.org/licenses)
            LicenseUri = 'https://github.com/kilasuit/ARMTemplateComplexity/blob/main/LICENSE'

            # What is the URL to your project's website?
            ProjectUri = 'https://github.com/kilasuit/ARMTemplateComplexity'

            # What is the URI to a custom icon file for your project? (optional)
            IconUri = ''

            # What new features, bug fixes, or deprecated features, are part of this release?
            ReleaseNotes = @'
            Initial Realease to the world
'@
        }
    }

    # If your module supports updatable help, what is the URI to the help archive? (optional)
    # HelpInfoURI = ''
}