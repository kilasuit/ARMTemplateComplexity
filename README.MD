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