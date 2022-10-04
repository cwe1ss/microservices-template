[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [ValidateSet("internal-grpc", "internal-grpc-sql-bus", "internal-http-bus", "public-razor")]
    [string]$Template,

    [Parameter(Mandatory=$True)]
    [string]$ServiceName,

    [Parameter(Mandatory=$True)]
    [string]$NamespaceName
)

$ErrorActionPreference = "Stop"

#$Template = "internal-grpc"
#$ServiceName = "sample-svc"
#$NamespaceName = "SampleSvc"


############################
"Validating parameters"

if (![regex]::IsMatch($ServiceName, "^[a-z0-9-]+$")) { throw "ServiceName may only contain lowercase letters, numbers and dash (-), since it will be used for Azure resource names." }

$templatePath = Join-Path "services" "_$Template"
$newServicePath = Join-Path "services" $ServiceName


if (!(Test-Path $templatePath)) { throw "The template $templatePath does not exist" }
if (Test-Path $newServicePath) { throw "The service path $newServicePath already exists" }


############################
"Copying template folder"

Copy-Item -Path $templatePath -Destination $newServicePath -Exclude bin,obj -Recurse


############################
"Renaming project folder"

$oldProjectFolder = Get-ChildItem -Path $newServicePath -Directory

$newProjectFolderName = $NamespaceName + $oldProjectFolder.Name.Substring($oldProjectFolder.Name.IndexOf("."))
$newProjectFolderPath = Join-Path $newServicePath $newProjectFolderName

Move-Item $oldProjectFolder.FullName $newProjectFolderPath


############################
"Copying proto file (if it exists)"

$oldProtoFileName = "_$Template.proto"
$newProtoFileName = "$ServiceName.proto"
$oldProtoPath = Join-Path "proto" $oldProtoFileName
$newProtoPath = Join-Path "proto" $newProtoFileName
if (Test-Path $oldProtoPath) {
    $protoContent = Get-Content $oldProtoPath
    $protoContent = $protoContent.Replace("csharp_namespace = ""$($oldProjectFolder.Name)""", "csharp_namespace = ""$newProjectFolderName""")
    $protoContent | Set-Content $newProtoPath
}


############################
"Updating project file"

$oldProjectFile = Get-ChildItem $newProjectFolderPath -Filter "*.csproj"
$newProjectFilePath = Join-Path $newProjectFolderPath "$newProjectFolderName.csproj"

$projectContent = Get-Content $oldProjectFile
$projectContent = $projectContent.Replace($oldProtoFileName, $newProtoFileName) # proto
$projectContent = $projectContent -replace "(?<=<UserSecretsId>).*(?=<\/UserSecretsId>)", "aspnet-$newProjectFolderName-$((New-Guid).ToString().ToUpper())" # New random User Secrets ID

$projectContent | Set-Content $newProjectFilePath
Remove-Item $oldProjectFile


############################
"Updating solution file"

$oldSlnPath = (Get-ChildItem $newServicePath -Filter "*.sln")
$newSlnPath = Join-Path $newServicePath "$NamespaceName.sln"

$slnContent = Get-Content $oldSlnPath.FullName
$slnContent = $slnContent.Replace("""$($oldProjectFolder.Name)""", """$newProjectFolderName""") # project name
$slnContent = $slnContent.Replace("$($oldProjectFile.Name)", "$newProjectFolderName.csproj") # project file
$slnContent = $slnContent.Replace("$($oldProjectFolder.Name)", $newProjectFolderName) # Project folder

$slnContent | Set-Content $newSlnPath
Remove-Item $oldSlnPath


############################
"Replacing namespaces in C# files"

$oldNamespace = $oldProjectFolder.Name
$newNamespace = $newProjectFolderName

$csharpFiles = Get-ChildItem -Path $newProjectFolderPath -Filter "*.cs" -Exclude bin,obj -Recurse -Depth 10
foreach ($csharpFile in $csharpFiles) {
    #$csharpFile = $csharpFiles[0]
    $fileContent = Get-Content $csharpFile.FullName
    $fileContent = $fileContent.Replace("namespace $oldNamespace", "namespace $newNamespace")
    $fileContent = $fileContent.Replace("using $oldNamespace", "using $newNamespace")
    $fileContent | Set-Content $csharpFile.FullName
}


############################
"Replacing namespaces in Razor files"

$razorFiles = Get-ChildItem -Path $newProjectFolderPath -Filter "*.cshtml" -Exclude bin,obj -Recurse -Depth 10
foreach ($razorFile in $razorFiles) {
    #$razorFile = $razorFiles[0]
    $fileContent = Get-Content $razorFile.FullName
    $fileContent = $fileContent.Replace("@model $oldNamespace", "@model $newNamespace")
    $fileContent = $fileContent.Replace("@namespace $oldNamespace", "@namespace $newNamespace")
    $fileContent = $fileContent.Replace("@using $oldNamespace", "@using $newNamespace")
    $fileContent | Set-Content $razorFile.FullName
}


############################
"Adding project to global solution"

dotnet sln add $newProjectFilePath
if ($LASTEXITCODE -ne 0) { throw "Project could not be added to global solution" }


############################
"Creating GitHub workflow"

$oldWorkflowPath = Join-Path ".github" "workflows" "service-$Template.yml"
$newWorkflowPath = Join-Path ".github" "workflows" "service-$ServiceName.yml"

$workflowContent = Get-Content $oldWorkflowPath

$workflowContent[0] = "name: '$ServiceName'"
$workflowContent = $workflowContent.Replace($oldProtoFileName, $newProtoFileName) # Proto file
$workflowContent = $workflowContent.Replace($Template, $ServiceName) # service Name
$workflowContent = $workflowContent.Replace("services/_", "services/") # service path
$workflowContent = $workflowContent.Replace($oldProjectFolder.Name, $newProjectFolderName)

$workflowContent | Set-Content $newWorkflowPath


############################
"Compiling service solution (to see if everything works)"

dotnet build $newServicePath
if ($LASTEXITCODE -ne 0) { throw "Build for new service failed." }


############################
# "Updating .\infrastructure\config.json"

# TODO: We need a way to modify the JSON without removing the comments. ConvertFrom-Json & System.Text.Json drops them.
# Newtonsoft.Json seems to keep them but we would have to store the DLL somewhere.

# $configPath = Join-Path "infrastructure" "config.json"
# $config = Get-Content $configPath | ConvertFrom-Json

# $config | ConvertTo-Json | Set-Content $configPath

"Done!"
""
"You MUST add the new service to .\infrastructure\config.json - this does not yet happen automatically."

