# ARMTemplateComplexity

This repo is for the tool to measure ARM Template complexity
It should be used as a guide and is a work in progess

To install it run 
```powershell
Install-Module ARMTemplateComplexity
```

Then to use it run
```powershell
Measure-ARMTemplate -TemplatePath C:\tmp\Azuredeploy.json
```

```powershell
Measure-ARMRepo -RepoPath C:\Code\Mine\Github\kilasuit\Public\azure-quickstart-templates\ -NumberOfTemplatesToTest 10 -TemplateTestType All -TemplateTestingPreference Serial 
```

or if you are feeling lazy

```powershell
marmr -RepoPath C:\Code\Mine\Github\kilasuit\Public\azure-quickstart-templates\ -no 50 -ttt All -ttp Serial 
```

This module provides object output that comprises of the json file being analysed, as either a type of `JsonFile.ARMTemplate` or  `JsonFile.OtherJsonFile` and each of these types contains the file that has been analysed so that it can be further dug into if needed. 

The `JsonFile.ARMTemplate` has the following output properties

```
ARMFunctions
ARMTemplateComplexityScore
CharsInTemplate
Content
ContentVersion
FuncsUsed
Functions
LinesOfTemplate
Outputs
Parameters
Resources
TemplateDirectory
TemplateName
TemplatePath
Variables
WordsInTemplate

```
