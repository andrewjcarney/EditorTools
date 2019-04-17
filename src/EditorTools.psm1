# Invoke-Editor.psm1
# (c) 2019 Andrew Carney

Set-StrictMode -Version Latest

if ($env:OS -inotmatch "Windows"){
    Write-Error "Sorry, windows only for now."
}

$Script:__CONFIG_PATH = "${PSScriptRoot}\.config"
$Script:__CONFIG = $null

class Editor {
    [bool]$IsDefault
    [string]$Name
    [string]$Path
    [string]$Description
    [string[]]$DefaultOptions
}

class Config {
    [string]$Default
    [System.Collections.Generic.IDictionary[string,object]]$Editors

    Config() {
        $this.Editors = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    }
}

<#
.SYNOPSIS

Launch a text editor on one or more files.

.DESCRIPTION

Launch a text editor on one or more files.
Takes any strings for the file name or extension.

.PARAMETER Editor
The editor to use.  Not required.

.PARAMETER Path
Path to one or more files

.INPUTS

Paths to files that you'd like to edit.  You can specify strings or pipe FileSystemInfo items.


.EXAMPLE

PS> gci C:\*.txt | Invoke-Editor

.EXAMPLE

PS> Invoke-Editor @("C:\foo.txt","c:\bar.txt") -Editor notepad
File.doc

.EXAMPLE

PS> Invoke-Editor -Path "C:\foo.txt"


Invoke-Editor
#>
function Invoke-Editor {
    Param(
        [Parameter(Mandatory=$true,ParameterSetName="names",Position=1)]
        [string[]]$Path = $null,
        [Parameter(Mandatory=$true,ParameterSetName="pipeline",ValueFromPipeline)]
        [System.IO.FileSystemInfo[]]$Paths = $null
    )
    DynamicParam {
        $ParameterName = "Editor"
        # Create the dictionary
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        
        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.Position = 0
        $ParameterAttribute.ParameterSetName = "noname"
        
        #Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        $arrSet = [string[]]($Script:__CONFIG.Editors.Keys | Sort)
        if ($arrSet -ieq $null) {
            $arrSet = @()
        }
        $ValidateSetAttribute = [System.Management.Automation.ValidateSetAttribute]::new($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin {
        $Editor = $PsBoundParameters[$ParameterName]
        if (![String]::IsNullOrEmpty($Editor)) {
            $editorPath = $editorPath = $Script:__CONFIG.Editors[$Editor].Path
        }
        else {
            $editorPath = $Script:__CONFIG.Editors[$Script:__CONFIG.Default].Path
        }
    }

    Process {
        if ($PSCmdlet.ParameterSetName -ieq "pipeline") {
            $Paths | ForEach-Object { Start-Process $editorPath -ArgumentList $_.FullName } 
        }
        else {
             $Path | Start-Process $editorPath -ArgumentList $file
        }
    }
}

<#
.SYNOPSIS

Add a text editor to the module.

.DESCRIPTION

Makes Invoke-Editor aware of a text editor.

.PARAMETER Name
Name of the editor.  This should be short and unique.

.PARAMETER Description
A friendly description of the editor.

.PARAMETER Path
Absolute path to the editor executable.

.PARAMETER Default
Set this editor as the default.

.PARAMETER DefaultOptions
Default command line switches to pass to the editor.


.EXAMPLE

PS> Add-Editor -Name "Notepad++" -Description "Notepad++ is an open source text editor." -Path "C:\Program Files\Notepad++\notepad++.exe" -Default

Add-Editor
#>
function Add-Editor {
    [OutputType([Editor])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,HelpMessage="Name of the editor.")]
        [string]$Name,
        [Parameter(Mandatory,HelpMessage="Description of the editor.")]
        [string]$Description,
        [Parameter(Mandatory,HelpMessage="Path to editor executable.")]
        [string]$Path,
        [Parameter(HelpMessage="Default options to pass to the editor.")]
        [string[]]$DefaultOptions,
        [switch]$Force,
        [Parameter(HelpMessage="Set this editor as the default.")]
        [switch]$Default
    )

    Begin {
        if ($Script:__CONFIG.Editors.ContainsKey($Name)) {
            Write-Error -Message "An editor with this name is already registered." `
                        -RecommendedAction "Choose a different name or remove the existing registration."
        }
    }

    Process {
        $e = New-Object Editor
        $e.Name = $Name
        $e.Description = $Description
        $e.Path = $Path
        $e.DefaultOptions = $DefaultOptions
        $e.IsDefault = $Default.IsPresent

        if ($e.IsDefault) {
            setDefault -name $e.Name
        }
    
        $Script:__CONFIG.Editors[$Name] = $e
        persist
        Write-Output $e
    }
}


<#
.SYNOPSIS

Get a list of editors.

.DESCRIPTION

Get a list of editors

.PARAMETER Editor
The editor to get.

.PARAMETER Default
Get the default editor.

.EXAMPLE

PS> Get-Editor

.EXAMPLE

PS> Get-Editor -Default

.EXAMPLE

PS> Get-Editor notepad


Invoke-Get
#>
function Get-Editor {
    [OutputType([Editor])]
    [OutputType([Editor[]])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$Default
    )
    DynamicParam {
        $ParameterName = "Editor"
        # Create the dictionary
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        
        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.ValueFromPipelineByPropertyName = $true
        $ParameterAttribute.ParameterSetName = "noname"
        $ParameterAttribute.Position = 0
        
        #Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        $arrSet = [string[]]($Script:__CONFIG.Editors.Keys | Sort)
        if ($arrSet -ieq $null) {
            $arrSet = @()
        }
        $ValidateSetAttribute = [System.Management.Automation.ValidateSetAttribute]::new($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin {
        # Bind the parameter to a friendly variable
            $Editor = $PsBoundParameters[$ParameterName]
    }

    Process {
        if ($Default.IsPresent) {
            Write-Output $Script:__CONFIG.Editors[$Script:__CONFIG.Default]
            return
        }
        
        if (![String]::IsNullOrEmpty($Editor)) {
              Write-Output $Script:__CONFIG.Editors[$Editor]
          }
          else {
              $Script:__CONFIG.Editors.Values | % {
                  Write-Output $_
               }
          }
 
    }
}

<#
.SYNOPSIS

Remove an editor from this module.

.DESCRIPTION

Remove an editor from this module.

.PARAMETER ObjEditor
Pass an editor object via the pipeline.

.PARAMETER Editor
Editor to remove.


.EXAMPLE

PS> Get-Editor notepad | Remove-Editor

.EXAMPLE

PS> Remove-Editor VSCode

Remove-Editor
#>
function Remove-Editor {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="pipeline")]
        [Editor]$ObjEditor
    )
    DynamicParam {
        $ParameterName = "Editor"
        # Create the dictionary
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        
        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.ValueFromPipelineByPropertyName = $true
        $ParameterAttribute.ParameterSetName = "name"
        $ParameterAttribute.Position = 0
        
        #Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        $arrSet = [string[]]($Script:__CONFIG.Editors.Keys | Sort)
        if ($arrSet -ieq $null) {
            $arrSet = @()
        }
        $ValidateSetAttribute = [System.Management.Automation.ValidateSetAttribute]::new($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    Begin {
        # Bind the parameter to a friendly variable
            $Editor = $PsBoundParameters[$ParameterName]
    }

    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "pipeline" { $Script:__CONFIG.Editors.Remove($ObjEditor.Name) }
            "name" { $Script:__CONFIG.Editors.Remove($Editor) }
        }
    }
}


<#
.SYNOPSIS

Set an editor as default.

.DESCRIPTION

Set an editor as default.

.PARAMETER Default

Set this editor as default.

.PARAMETER Editor
The editor to set as default.



.EXAMPLE

PS> Get-Editor notepad | Set-Editor -Default

Set-Editor
#>
function Set-Editor {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="pipeline")]
        [Editor]$Editor,
        [Parameter(Mandatory)]
        [switch]$Default
    )
    
    setDefault -name $Editor.Name
    persist
}

function load {

    if (Test-Path $Script:__CONFIG_PATH) {
        $Script:__CONFIG = Import-Clixml -Path $Script:__CONFIG_PATH
        return
    }

    # first run
    $Script:__CONFIG = New-Object Config

    # windows only for now.
    Add-Editor -Name "notepad" -Description "Standard notepad.exe included with all versions of windows since forever" -Path "notepad.exe" -Default | Out-null

    # other common editors
    $nppPaths = @(
       "${env:ProgramFiles}\Notepad++\notepad++.exe",
       "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    )
    
    foreach ($path in $nppPaths) {
        if (Test-Path -Path $path) {
            Add-Editor -Name "Notepad++" -Description "Notepad++, https://notepad-plus-plus.org/" -Path $path | Out-null
            break
        }
    }
    
    $codePaths = @(
        "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin\code.cmd"
    )
    
    foreach ($path in $codePaths) {
        if (Test-Path -Path $path) {
            Add-Editor -Name "VSCode" -Description "Visual Studio Code, https://code.visualstudio.com/" -Path "code.cmd" | Out-Null
            break
        }
    }

    persist
}

function persist {
    $Script:__CONFIG | Export-Clixml -Depth 5 -Path $Script:__CONFIG_PATH
}

function setDefault([string]$name) {
    $Script:__CONFIG.Editors.Keys | ForEach-Object {
        if ($name -ieq $_) {
            $Script:__CONFIG.Editors[$_].IsDefault = $true
        }
        else {
            $Script:__CONFIG.Editors[$_].IsDefault = $false
        }
    }
    $Script:__CONFIG.Default = $name
}

# and away we go...

load