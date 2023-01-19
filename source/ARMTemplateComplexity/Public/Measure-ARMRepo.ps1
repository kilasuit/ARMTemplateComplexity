function Measure-ARMRepo {
    [CmdletBinding()]
    [Alias('marmr')]
    param (
        # Specifies a path to one or more locations.
        [Parameter( Mandatory = $true,
            Position = 0,
            ParameterSetName = "Default",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string]
        $RepoPath,

        # Parameter help description
        [Parameter(Mandatory = $false,
            Position = 0,
            ParameterSetName = "Default",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Acceptable filenames")]
        [String[]]
        $fileNames,

        [Parameter(Mandatory = $false)]
        [int]
        [alias('no')]
        $NumberOfTemplatesToTest,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'All', 'AzDeployOrMainTemplate')]
        [string]
        [Alias('ttt')]
        $TemplateTestType,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Serial', 'Parallel')]
        [string]
        [Alias('ttp')]
        $TemplateTestingPreference
    )
    # Get all files where not matching parameters as not all ARM templates are called AzureDeploy (nor should they be!)

    if ($TemplateTestType -eq 'Default') {
        $files = Get-ChildItem $RepoPath -Filter *.json -Recurse | Where-Object BaseName -NotMatch 'metadata|parameters|settings|createUiDefinition' 
    }
    elseif ($TemplateTestType -eq 'AzDeployOrMainTemplate') {
        $files = Get-ChildItem $RepoPath -Filter *.json -Recurse | Where-Object BaseName -Match 'AzureDeploy|MainTemplate' | Where-Object BaseName -NotMatch 'parameters'
    }
    elseif ($TemplateTestType -eq 'All') { 
        $files = Get-ChildItem $RepoPath -Filter *.json -Recurse  
    }

    If ($NumberOfTemplatesToTest) {
        $files = $files | Select-Object -First $NumberOfTemplatesToTest
    }

    If ($TemplateTestingPreference -eq 'Serial') {
        $ArmReport = $files | ForEach-Object {
            Write-Information "Testing Template $($_.FullName)"
            Measure-ARMTemplate -TemplatePath $_.FullName #-RepoPath $RepoPath
        }
    }
    elseif ($TemplateTestingPreference -eq 'Parallel') {
        $CTFOfunctiondef = ${function:ConvertTo-FlatObject}.toString() 
        $MATfunctiondef = ${function:Measure-ARMTemplate}.toString() 
        # Experiment on how to make this quicker!!
        $ArmReport = $files | ForEach-Object -ThrottleLimit 50 -Parallel {
            ${function:ConvertTo-FlatObject} = $using:CTFOfunctiondef
            ${function:Measure-ARMTemplate} = $using:MATfunctiondef
            Write-Information "Testing Template $($_.FullName)"
            Measure-ARMTemplate -TemplatePath $_.FullName #-RepoPath $using:RepoPath
        }
    }
    $ArmReport
}