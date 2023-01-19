function Measure-ARMTemplate {
    [CmdletBinding()]
    [Alias('marmt')]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "ARM",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to a template")]
        [ValidateNotNullOrEmpty()]
        #[ValidatePattern('metadata|parameters|settings')]
        #[ValidateScript]
        [string]
        $TemplatePath,

        # 
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "Bicep",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to a template")]
        [ValidateNotNullOrEmpty()]
        #[ValidatePattern('metadata|parameters|settings')]
        #[ValidateScript]
        [hashtable]
        $TemplateAsHashtable

    )
    #region HelperVariables
    # Hardcoded for now until I can work out a nicer way to extract these another way.
    $armfunctions = 'add', 'and', 'array', 'base64', 'base64ToJson', 'base64ToString', 'bool', 'coalesce', 'concat', 'contains', 'copyIndex', 'createArray', 'createObject', 'dataUri', 'dataUriToString', 'dateTimeAdd', 'deployment', 'div', 'empty', 'endsWith', 'environment', 'equals', 'extensionResourceId', 'false', 'first', 'float', 'format', 'greater', 'greaterOrEquals', 'guid', 'if', 'indexOf', 'int', 'intersection', 'json', 'last', 'lastIndexOf', 'length', 'less', 'lessOrEquals', 'list', 'listAccountSas', 'listAdminKeys', 'listAuthKeys', 'listCallbackUrl', 'listChannelWithKeys', 'listClusterAdminCredential', 'listConnectionStrings', 'listCredentials', 'listCredential', 'listKeys', 'listKeyValue', 'listPackage', 'listQueryKeys', 'listSecrets', 'listServiceSas', 'listSyncFunctionTriggerStatus', 'max', 'min', 'mod', 'mul', 'newGuid', 'not', 'null', 'or', 'padLeft', 'parameters', 'pickZones', 'providers', 'range', 'reference', 'replace', 'resourceGroup', 'resourceId', 'skip', 'split', 'startsWith', 'string', 'sub', 'subscription', 'subscriptionResourceId', 'substring', 'take', 'tenantResourceId', 'toLower', 'toUpper', 'trim', 'true', 'union', 'uniqueString', 'uri', 'uriComponent', 'uriComponentToString', 'utcNow', 'variables'
    # TODO - Export this to a configuration file elsewhere to allow for more flexible complexity scoring models in future as this is just a starter model.
    $baseScore = 10
    
    $parameterScore = 10
    $defaultValueScore = 5
    $minValueScore = 5
    $maxValueScore = 5
    $allowedValuesScore = 10
    $objectTypeScore = 10
    $arrayTypeScore = 5
    $secureTypeScore = 10
    $totalParamScore = 0
    
    $ARMFunctionScore = 10 
    $VariableStringScore = 5
    $VariableObjectScore = 10

    $ResourceScore = 10
    $ResourceParameterScore = 5
    $outputScore = 10
    
    $customFunctionScore = 50
    #endregion HelperVaraibles
    
    if ($TemplatePath) {
        $JsonTemplate = Get-Item $TemplatePath
        $content = Get-Content $JsonTemplate.FullName 
        $json = $content | ConvertFrom-Json #-Depth 100 
        $measures = $content | Measure-Object -Line -Word -Character
    }
    elseif ($TemplateAsHashtable) {
        $json = $TemplateAsHashtable
    }
    if ($json.'$schema' -match 'schema.management.azure.com') { 
            
        $TemplateComplexityScore = $baseScore
        $param = $json.parameters
        # Parameters aren't actually an array of objects - they are sub properties of the parameters object for reasons
        $parameters = [System.Collections.Generic.List[PSCustomObject]]::New()
            
        $var = $json.variables 
        # Variables aren't actually an array of objects - they are sub properties/objects of the variables object for reasons
        $variables = [System.Collections.Generic.List[PSCustomObject]]::New() 
            
        $out = $json.outputs
        # Outputs aren't actually an array of objects - they are sub objects of the Outputs object for reasons
        $outputs = [System.Collections.Generic.List[PSCustomObject]]::New()
            
        #Resources & functions are actually an array already - so we have no need to "transform" these
        $res = $json.resources
        $func = $json.functions

        #region Calculation
        $azfunctions = Foreach ($arm in $armfunctions) {
            [PSCustomObject]@{
                PSTypeName = 'ARMTemplate.ARMFunction'
                Function   = $arm 
                Count      = ( -split ($content | Out-String) | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count                
            }
        }
        If ($param) {
            $totalParamScore = 0
            $param | Get-Member | Where-Object MemberType -EQ 'NoteProperty' | ForEach-Object {   
                $CurrentParam = $param.$($_.Name)
                $ParamName = $($_.Name)
                $calculatedParamScore = 0
                    
                $newParamObject = [PSCustomObject]@{
                    ParameterName  = $($ParamName)
                    ParameterValue = [pscustomobject]@{ 
                        type     = $CurrentParam.type
                        metadata = [pscustomobject]@{
                            description         = if ($CurrentParam.metadata.description) { $CurrentParam.metadata.description } else { '' } 
                            parameterComplexity = 0
                        }
                    }
                }
                $calculatedParamScore = $calculatedParamScore + $parameterScore ; 
                if (! $CurrentParam.metadata.description ) { $calculatedParamScore = $calculatedParamScore + 3 }
                if ($CurrentParam.defaultValue) {
                    $calculatedParamScore = $calculatedParamScore + $defaultValueScore 
                    $newParamObject.ParameterValue | Add-Member -Name defaultValue -Type NoteProperty -Value $CurrentParam.defaultValue 
                    if ($CurrentParam.defaultValue.gettype().Name -notmatch 'Boolean|Int') {
                        $paramArmFunctions = Foreach ($arm in $armfunctions) {
                            [PSCustomObject]@{
                                PSTypeName = 'ARMTemplate.ARMFunction'
                                Function   = $arm 
                                Count      = ( $CurrentParam.defaultValue | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count
                            }
                        }
                        $paramArmFunctions.where{ $_.count -gt 0 }.foreach{ $calculatedParamScore = $calculatedParamScore + $ARMFunctionScore }
                    }
                }
                if ($CurrentParam.minValue) {
                    $calculatedParamScore = $calculatedParamScore + $minValueScore
                    $newParamObject.ParameterValue | Add-Member -Name minValue -Type NoteProperty -Value $CurrentParam.minValue  
                }
                if ($CurrentParam.maxValue) {
                    $calculatedParamScore = $calculatedParamScore + $maxValueScore 
                    $newParamObject.ParameterValue | Add-Member -Name maxValue -Type NoteProperty -Value  $CurrentParam.maxValue
                }
                if ($CurrentParam.minLength) {
                    $calculatedParamScore = $calculatedParamScore + $minValueScore 
                    $newParamObject.ParameterValue | Add-Member -Name minLength -Type NoteProperty -Value  $CurrentParam.minLength
                }
                if ($CurrentParam.maxLength) {
                    $calculatedParamScore = $calculatedParamScore + $maxValueScore 
                    $newParamObject.ParameterValue | Add-Member -Name maxLength -Type NoteProperty -Value  $CurrentParam.maxLength
                }
                if ($CurrentParam.allowedValues) {
                    $calculatedParamScore = $calculatedParamScore + $allowedValuesScore; 
                    $CurrentParam.allowedValues.foreach{ 
                        $calculatedParamScore = $calculatedParamScore + 1
                    }
                    $newParamObject.ParameterValue | Add-Member -Name allowedValues -Type NoteProperty -Value $CurrentParam.allowedValues
                }
                # Check object type and for each 
                if ($CurrentParam.type -imatch 'object') { $calculatedParamScore = $calculatedParamScore + $objectTypeScore }
                if ($CurrentParam.type -imatch 'array') { $calculatedParamScore = $calculatedParamScore + $arrayTypeScore }
                if ($CurrentParam.type -imatch 'secure') { $calculatedParamScore = $calculatedParamScore + $secureTypeScore }

                $newParamObject.ParameterValue.metadata.parameterComplexity = $calculatedParamScore
                $newParamObject.ParameterValue.metadata | Add-Member -Name parameterARMFunctions -Type NoteProperty -Value ($paramArmFunctions | Where-Object Count -GT 0)
                # Update total score for all parameters
                $totalParamScore = $totalParamScore + $calculatedParamScore
                $parameters.Add($newParamObject)
                #$CurrentParam,$newParamObject,$paramArmFunctions = $null
            }
            $TemplateComplexityScore = $TemplateComplexityScore + $totalParamScore
        }
        If ($var) {
            $totalVarScore = 0
            $var | Get-Member | Where-Object MemberType -EQ 'NoteProperty' | ForEach-Object {
                $currentVar = $var.$($_.Name)
                $varName = $($_.Name)
                $calculatedVarScore = 0
                $calculatedVarScore = $calculatedVarScore + $VariableScore
                $isInt = ((($content | Select-String -Pattern $varName -List | Select-Object -First 1) -split ':')[-1].Trim().GetType().Name) -match 'Int|Long|Double' 
                $isObject = (($content | Select-String -Pattern $varName -List | Select-Object -First 1) -split ':')[-1].Trim().StartsWith('{')
                $isString = (($content | Select-String -Pattern $varName -List | Select-Object -First 1) -split ':')[-1].Trim().StartsWith('"')

                switch ($true) {
                    $isInt { $variableType = 'int' ; $calculatedVarScore = $calculatedVarScore + 1 }
                    $isString { $variableType = 'string' ; $calculatedVarScore = $calculatedVarScore + $VariableStringScore }
                    $isObject { $variableType = 'object' ; $calculatedVarScore = $calculatedVarScore + $VariableObjectScore }
                    Default { $variableType = 'unknown' ; $calculatedVarScore = $calculatedVarScore + 1 }
                }

                $newVarObject = [PSCustomObject]@{
                    VariableName         = $($varName)
                    VariableValue        = $currentVar
                    VariableType         = $variableType
                    VariableARMFunctions = [PSCustomObject]@{ }
                    VariableComplexity   = 0
                }

                if ($variableType -eq 'string') {
                    $varArmFunctions = Foreach ($arm in $armfunctions) {
                        [PSCustomObject]@{
                            PSTypeName = 'ARMTemplate.ARMFunction'
                            Function   = $arm 
                            Count      = ( $currentVar | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count                
                        }
                            
                    }
                    $varArmFunctions = $varArmFunctions | Where-Object Count -GT 0
                    $varArmFunctions.foreach{
                        $calculatedVarScore = $calculatedVarScore + $_.Count 
                    }
                    $newVarObject.VariableARMFunctions = $varArmFunctions
                }
                if ($variableType -eq 'object') {
                    $varObjectARMFunctions = [System.Collections.Generic.List[PSCustomObject]]::New()
                    $flatVarObject = ConvertTo-FlatObject $currentVar
                    $reportingObject = $flatVarObject
                    $flatVarObject |
                        Get-Member -MemberType NoteProperty | 
                            ForEach-Object { $propName = $_.Name ; 
                                If (! $flatVarObject.$propName -eq $null) {
                                    If ($flatVarObject.$propName.gettype().Name -match 'string') {
                                        $propValue = $flatVarObject.$propName
                                        $varPropArmFunctions = Foreach ($arm in $armfunctions) {
                                            [PSCustomObject]@{
                                                PSTypeName = 'ARMTemplate.ARMFunction'
                                                Function   = $arm 
                                                Count      = ( $propValue | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count                
                                            }
                                        } 
                                        $varPropArmFunctions = $varPropArmFunctions | Where-Object Count -GT 0
                                        $varPropArmFunctions.foreach{
                                            $calculatedVarPropScore = $calculatedVarPropScore + $_.Count 
                                        }
                                        $reportingObject | Add-Member -Name ($propName + '.Complexity') -Type NoteProperty -Value $calculatedVarPropScore
                                    } 
                                    $varObjectARMFunctions.Add($varPropARMFunctions)
                                }
                            }
                            $varObjectARMFunctions = $varObjectARMFunctions | Where-Object Count -GT 0
                            $varObjectARMFunctions.foreach{
                                $calculatedVarScore = $calculatedVarScore + $_.Count 
                            }
                            $newVarObject.VariableARMFunctions = $varObjectARMFunctions
                            $newVarObject | Add-Member -Name VarProp -Type NoteProperty -Value $reportingObject 
                        }
                        $newVarObject.VariableComplexity = $calculatedVarScore
                        $totalVarScore = $totalVarScore + $calculatedVarscore

                        $variables.Add($newVarObject)
                    }
                    $TemplateComplexityScore = $TemplateComplexityScore + $totalVarScore
                }
        if($func)  {
                ## TODO Properly
                $totalFuncScore = 0
                $func.Foreach{
                    $currentFunction = $_
                    $FunctionName = $func.$($_.Name)
                    $calculatedFuncScore = 0
                    $totalFuncScore = $calculatedFuncScore + $totalFuncScore + $customFunctionScore
                }
            }
        # Resources
        If ($res) {
                    $totalResScore = 0
                    $res.Foreach{
                        $currentResource = $_
                        $ResourceName = $Res.$($_.Name)
                        $calculatedResScore = 0
                        $calculatedResScore = $calculatedResScore + $ResourceScore
                        $flatResObject = ConvertTo-FlatObject $currentResource
                        $resObjectARMFunctions = [System.Collections.Generic.List[PSCustomObject]]::New()
                        $flatResObject |
                            Get-Member -MemberType NoteProperty | 
                                # We wont use the .properties objects as we have the properties of these objects already exposed in the flat object
                                Where-Object { $_.name -Match '.*(?<!properties)$' } |
                                    ForEach-Object { $propName = $_.Name ; 
                                        $calculatedResParamScore = 0
                                        $calculatedResParamScore = $calculatedResParamScore + $ResourceParameterScore
                                        Write-Information "Working on $propname"
                                        If (! $flatResObject.$propName -eq $null) {
                                            If ($flatResObject.$propName.gettype().Name -match 'string') {
                                                $propValue = $flatResObject.$propName
                                                $resPropArmFunctions = Foreach ($arm in $armfunctions) {
                                                    [PSCustomObject]@{
                                                        PSTypeName = 'ARMTemplate.ARMFunction'
                                                        Function   = $arm 
                                                        Count      = ( $propValue | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count
                                                    }
                                                } 
                                                $resPropArmFunctions = $resPropArmFunctions | Where-Object Count -GT 0
                                                $resPropArmFunctions.foreach{
                                                    $calculatedResPropScore = $calculatedResPropScore + $_.Count 
                                                }
                                                $flatResObject | Add-Member -Name ($propName + '.Complexity') -Type NoteProperty -Value $calculatedResPropScore
                                            }
                                        }
                                        $ResObjectARMFunctions.Add($ResPropARMFunctions)
                                        $calculatedResScore = $calculatedResScore + $calculatedResParamScore
                                    }
                $resObjectARMFunctions = $resObjectARMFunctions | Where-Object Count -GT 0
                $resObjectARMFunctions.foreach{
                    $calculatedResScore = $calculatedResScore + $_.Count 
                }
                $flatResObject | Add-Member -Name ResourceARMFunctions -Type NoteProperty -Value $resObjectARMFunctions
                $flatResObject | Add-Member -Name ResourceComplexity -Type NoteProperty -Value $calculatedResScore
                $totalresScore = $totalresScore + $calculatedResScore
            }
            $TemplateComplexityScore = $TemplateComplexityScore + $totalResScore
        }
        # Outputs 
        If ($Out) {
            $totalOutScore = 0
            $out | Get-Member | Where-Object MemberType -EQ 'NoteProperty' | ForEach-Object {
                $currentOut = $out.$($_.Name)
                $outName = $($_.Name)
                $calculatedoutScore = 0
                $calculatedoutScore = $calculatedoutScore + $outputScore
                $isInt = ((($content | Select-String -Pattern $outName -List | Select-Object -First 1) -split ':')[-1].Trim().GetType().Name) -match 'Int|Long|Double' 
                $isObject = (($content | Select-String -Pattern $outName -List | Select-Object -First 1) -split ':')[-1].Trim().StartsWith('{')
                $isString = (($content | Select-String -Pattern $outName -List | Select-Object -First 1) -split ':')[-1].Trim().StartsWith('"')

                switch ($true) {
                    $isInt { $outputType = 'int' ; $calculatedoutScore = $calculatedoutScore + 1 }
                    $isString { $outputType = 'string' ; $calculatedoutScore = $calculatedoutScore + 1 }
                    $isObject { $outputType = 'object' ; $calculatedoutScore = $calculatedoutScore + 3 }
                    Default { $outputType = 'unknown' ; $calculatedoutScore = $calculatedoutScore + 1 }
                }

                $newoutObject = [PSCustomObject]@{
                    outputName         = $($outName)
                    outputValue        = $currentOut
                    outputType         = $outputType
                    outputARMFunctions = [PSCustomObject]@{ }
                    outputComplexity   = 0
                }

                if ($outputType -eq 'string') {
                    $outArmFunctions = Foreach ($arm in $armfunctions) {
                        [PSCustomObject]@{
                            PSTypeName = 'ARMTemplate.ARMFunction'
                            Function   = $arm 
                            Count      = ( $currentOut | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count
                        }
                        
                    }
                    $outArmFunctions = $outArmFunctions | Where-Object Count -GT 0
                    $outArmFunctions.foreach{
                        $calculatedoutScore = $calculatedoutScore + $_.Count 
                    }
                    $newoutObject.outputARMFunctions = $outArmFunctions
                }
                if ($outputType -eq 'object') {
                    $outObjectARMFunctions = [System.Collections.Generic.List[PSCustomObject]]::New()
                    $flatOutObject = ConvertTo-FlatObject $currentout
                    $reportingObject = $flatOutObject
                    $flatOutObject |
                        Get-Member -MemberType NoteProperty | 
                            ForEach-Object { $propName = $_.Name ; 
                                If (! $flatResObject.$propName -eq $null) {
                                    If ($flatOutObject.$propName.gettype().Name -match 'string') {
                                        $propValue = $flatOutObject.$propName
                                        $outPropArmFunctions = Foreach ($arm in $armfunctions) {
                                            [PSCustomObject]@{
                                                PSTypeName = 'ARMTemplate.ARMFunction'
                                                Function   = $arm 
                                                Count      = ( $propValue | Where-Object { $_ -match $arm + '\(' } | Measure-Object).Count                
                                            }
                                        } 
                                        $outPropArmFunctions = $outPropArmFunctions | Where-Object Count -GT 0
                                        $outPropArmFunctions.foreach{
                                            $calculatedoutPropScore = $calculatedoutPropScore + $_.Count 
                                        }
                                        $reportingObject | Add-Member -Name ($propName + '.Complexity') -Type NoteProperty -Value $calculatedoutPropScore
                                    } 
                                    $outObjectARMFunctions.Add($outPropARMFunctions)
                                }
                            }
                            $outObjectARMFunctions = $outObjectARMFunctions | Where-Object Count -GT 0
                            $outObjectARMFunctions.foreach{
                                $calculatedoutScore = $calculatedoutScore + $_.Count 
                            }
                            $newoutObject.OutputARMFunctions = $outObjectARMFunctions
                            $newoutObject | Add-Member -Name outProp -Type NoteProperty -Value $reportingObject 
                        }
                        $newOutObject.OutputComplexity = $calculatedoutScore
                        $totaloutScore = $totaloutScore + $calculatedoutscore

                        $Outputs.Add($newOutObject)
                    }
                    $TemplateComplexityScore = $TemplateComplexityScore + $totalOutScore
                }
        #endregion Calculation 
                
                $ARMReport = [pscustomobject]@{
                    PSTypeName            = 'JsonFile.ARMTemplate'
                    Content               = $content
                    TemplateName          = if ($JsonTemplate) {$JsonTemplate.BaseName} else {''}
                    TemplatePath          = if ($JsonTemplate) {$JsonTemplate.FullName} else {''}
                    TemplateDirectory     = if ($JsonTemplate) {$JsonTemplate.Directory.FullName} else {''}
                    ContentVersion        = $json.contentVersion
                    Parameters            = @{ 
                        Parameters      = $param
                        ParametersArray = $updatedparams
                        Count           = if ($param) { ($param | Get-Member -MemberType NoteProperty).Count } else { 0 }
                        ComplexityScore = $totalParamScore 
                    }   
                    Variables       = @{ 
                        Variables       = $var
                        VariablesArray  = $updatedvar
                        Count           = if ($var) { ($var | Get-Member -MemberType NoteProperty).Count } else { 0 }
                        ComplexityScore = $totalVarScore
                    }
                    Resources       = @{ 
                        Resources       = $res
                        Count           = if ($res) { $res.Count } else { 0 }
                        ComplexityScore = $totalResScore
                    }
                    Outputs         = @{ 
                        Outputs         = $out
                        OutputsArray    = $updatedout
                        Count           = if ($out) { ($out | Get-Member -MemberType NoteProperty).Count } else { 0 }
                        ComplexityScore = $totalOutScore
                    }
                    Functions       = @{
                        CustomFucntions = $functions
                        Count           = if ($functions) { ($func | Get-Member -MemberType NoteProperty).Count } else { 0 }
                        ComplexityScore = $totalFuncScore 
                    }
                    ARMFunctions    = $azfunctions | Where-Object Count -GT 0
                    FuncsUsed       = ($azfunctions | Measure-Object -Property count -Sum).Sum
                    LinesOfTemplate = $measures.Lines
                    WordsInTemplate = $measures.Words
                    CharsInTemplate = $measures.Characters
                    ARMTemplateComplexityScore = $TemplateComplexityScore
                }
            }
            else {
                $ARMReport = [pscustomobject]@{
                    PSTypeName = 'JsonFile.OtherJsonFile'
                    File       = $File.Directory.Name
                    Content    = $content
                }
        
            }
            $ArmReport
        }
        
