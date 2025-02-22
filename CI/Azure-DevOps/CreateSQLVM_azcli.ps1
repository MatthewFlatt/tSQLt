<# USAGE: ./CreateSQLVM.ps1 -Location "East US 2" -Size "Standard_D2as_v4" -ResourceGroupName "myTestResourceGroup" -VMAdminName "azureAdminName" -VMAdminPwd "aoeihag;ladjfalkj23" -SQLVersionEdition "2017" -SQLPort "41433" -SQLUserName "tSQLt_sa" -SQLPwd "aoeihag;ladjfalkj46" -BuildId "001" #>
Param( 
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $Location,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $Size,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ResourceGroupName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $BuildId,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $VMAdminName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String] $VMAdminPwd,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $SQLVersionEdition,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $SQLPort,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $SQLUserName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $SQLPwd
);

$scriptpath = $MyInvocation.MyCommand.Path;
$dir = Split-Path $scriptpath;
$projectDir = Split-Path (Split-Path $dir);

.($projectDir+"\Build\CommonFunctionsAndMethods.ps1")

Log-Output "<-><-><-><-><-><-><-><-><-><-><-><-><-><->";
Log-Output "FileLocation: ", $dir;
Log-Output "Project Location: ", $projectDir;
Log-Output "Parameters: ---------------------------";
Log-Output "Location:", $Location;
Log-Output "Size:", $Size;
Log-Output "ResourceGroupName:", $ResourceGroupName;
Log-Output "BuildId:", $BuildId;
Log-Output "SQLVersionEdition:", $SQLVersionEdition;
Log-Output "SQLPort:", $SQLPort;
Log-Output "Parameters: ---------------------------";
Log-Output "<-><-><-><-><-><-><-><-><-><-><-><-><-><->";

$VNetName = $ResourceGroupName+'_VNet';
$SubnetName = $ResourceGroupName + '_Subnet'
$VMName = ("V{0}-{1}###############" -f $BuildId,$SQLVersionEdition).substring(0,15).replace('#','')
$PipName = $ResourceGroupName + '_' + $(Get-Random);
$NsgName = $ResourceGroupName + '_nsg';
$InterfaceName = $ResourceGroupName + '_nic';

Log-Output "<-><-><-><-><-><-><-><-><-><-><-><-><-><->";
Log-Output "Names:";
Log-Output "ResourceGroupName:    ", $ResourceGroupName;
Log-Output "VMName:  ", $VMName;
Log-Output "VNetName:  ", $VNetName;
Log-Output "SubnetName:  ", $SubnetName;
Log-Output "PipName:  ", $PipName;
Log-Output "NsgName:  ", $NsgName;
Log-Output "InterfaceName:  ", $InterfaceName;
Log-Output "<-><-><-><-><-><-><-><-><-><-><-><-><-><->";

<# FYI Usage: $SQLVersionEditionHash.$SQLVersionEdition.offer = "SQL2016SP2-WS2016"
URN for az cli --> $SQLVersionEditionInfo.publisher+":"+$SQLVersionEditionInfo.offer+":"+$SQLVersionEditionInfo.sku+":"+$SQLVersionEditionInfo.version
#>
$SQLVersionEditionHash = @{
    "2008R2Std"=@{"sqlversion"="2008R2";"offer"="SQL2008R2SP3-WS2008R2SP1";"publisher"="microsoftsqlserver";"sku"="Standard";"osType"="Windows";"version"="latest"}; #MicrosoftSQLServer:SQL2008R2SP3-WS2008R2SP1:Standard:latest
    "2012Ent"=@{"sqlversion"="2012";"offer"="SQL2012SP4-WS2012R2";"publisher"="microsoftsqlserver";"sku"="Enterprise";"osType"="Windows";"version"="latest"}; #MicrosoftSQLServer:SQL2012SP4-WS2012R2:Enterprise:latest
    "2014"=@{"sqlversion"="2014";"offer"="sql2014sp3-ws2012r2";"publisher"="microsoftsqlserver";"sku"="sqldev";"osType"="Windows";"version"="latest"}; #MicrosoftSQLServer:sql2014sp3-ws2012r2:sqldev:latest
    "2016"=@{"sqlversion"="2016";"offer"="SQL2016SP2-WS2016";"publisher"="microsoftsqlserver";"sku"="sqldev";"osType"="Windows";"version"="latest"}; #MicrosoftSQLServer:sql2016sp2-ws2019:sqldev:latest
    "2017"=@{"sqlversion"="2017";"offer"="sql2017-ws2019";"publisher"="microsoftsqlserver";"sku"="sqldev";"osType"="Windows";"version"="latest"}; #MicrosoftSQLServer:sql2017-ws2019:sqldev:latest
    "2019"=@{"sqlversion"="2019";"offer"="sql2019-ws2019";"publisher"="microsoftsqlserver";"sku"="sqldev";"osType"="Windows";"version"="latest"} #MicrosoftSQLServer:sql2019-ws2019:sqldev:latest
};

$SQLVersionEditionInfo = $SQLVersionEditionHash.$SQLVersionEdition;
$ImageUrn = $SQLVersionEditionInfo.publisher+":"+$SQLVersionEditionInfo.offer+":"+$SQLVersionEditionInfo.sku+":"+$SQLVersionEditionInfo.version;
Log-Output "ImageUrn:  ", $ImageUrn;
Log-Output "SQLVersionEditionInfo:  ", $SQLVersionEditionInfo;

Log-Output "START: Creating Resource Group $ResourceGroupName";
$output = az group create --location "$Location" --name "$ResourceGroupName" | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating Resource Group";
    return
}
Log-Output "DONE: Creating Resource Group $ResourceGroupName";

Log-Output "START: Creating VNet $VNetName";
$output = az network vnet create --name "$VNetName" --resource-group "$ResourceGroupName" --location $Location --address-prefixes 192.168.0.0/16 `
            --subnet-name "$SubnetName" --subnet-prefixes 192.168.1.0/24 | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating VNet $VNetName";
    return
}
Log-Output "DONE: Creating VNet $VNetName";

Log-Output "START: Creating PIP $PipName";
$output = az network public-ip create --name $PipName --resource-group $ResourceGroupName --allocation-method Static --idle-timeout 4 `
                --location $Location | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating PIP";
    return
}
$FQDN = (az network public-ip show --resource-group $ResourceGroupName --name $PipName --query "ipAddress" --output tsv)
Log-Output "FQDN: ", $FQDN;
Log-Output "DONE: Creating PIP $PipName";

Log-Output "START: Creating NSG and Rules $NsgName";
$output = az network nsg create --name $NsgName --resource-group $ResourceGroupName --location $Location | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating NIC";
    return
}
$output = az network nsg rule create --name "RDPRule" --nsg-name $NsgName --priority 1000 --resource-group $ResourceGroupName --access Allow `
            --destination-address-prefixes * --destination-port-ranges 3389 --direction Inbound --protocol Tcp --source-address-prefixes * `
            --source-port-ranges * | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating NIC RDPRule";
    return
}
$output = az network nsg rule create --name "MSSQLRule" --nsg-name $NsgName --priority 1001 --resource-group $ResourceGroupName --access Allow `
            --destination-address-prefixes * --destination-port-ranges $SQLPort --direction Inbound --protocol Tcp --source-address-prefixes * `
            --source-port-ranges * | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating NIC MSSQLRule";
    return
}
Log-Output "DONE: Creating NSG and Rules $NsgName";

Log-Output "START: Creating NIC $InterfaceName";
$output = az network nic create --name $InterfaceName --resource-group $ResourceGroupName --subnet $SubnetName --vnet-name $VNetName `
            --location $Location --network-security-group $NsgName --public-ip-address $PipName | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating NIC";
    return
}
Log-Output "DONE: Creating NIC $InterfaceName";

Log-Output "Creating VM $VMName";

$output = az vm create --name "$VMName" --resource-group "$ResourceGroupName" --location "$Location" --admin-password "$VMAdminPwd" `
            --admin-username "$VMAdminName" --computer-name "$VMName" --image "$ImageUrn" --nics "$InterfaceName" --priority Spot `
            --size $Size | ConvertFrom-Json;
if (!$output) {
    Log-Output "VMName: ", $VMName;
    Log-Output "ResourceGroupName: ", $ResourceGroupName;
    Log-Output "Location: ", $Location;
    Log-Output "VMAdminPwd: ", $VMAdminPwd; #Starred out anyways
    Log-Output "VMAdminName: ", $VMAdminName;
    Log-Output "VMName: ", $VMName;
    Log-Output "ImageUrn: ", $ImageUrn;
    Log-Output "InterfaceName: ", $InterfaceName;
    Log-Output "Size: ", $Size;
    Write-Error "Error creating vm";
    return;
}

$VMResourceId = (az vm show --resource-group $ResourceGroupName --name $VMName --query id --output tsv)
Log-Output "VmResourceId: ", $VmResourceId;
Log-Output "DONE: Creating VM $VMName";

Log-Output 'START: Applying SqlVM Config'
$output = az deployment group create --resource-group $ResourceGroupName --template-file "$dir/CreateSQLVirtualMachineTemplate.bicep" `
                    --parameters sqlPortNumber=$SQLPort sqlAuthenticationLogin="$SQLUserName" sqlAuthenticationPassword="$SQLPwd" newVMName="$VMName" newVMRID="$VmResourceId" | ConvertFrom-Json;
if (!$output) {
    Write-Error "Error creating SqlVM";
    return;
}
$SQLVM|Out-String|Log-Output;
Log-Output 'DONE: Applying SqlVM Config'

Log-Output 'START: Prep SQL Server for tSQLt Build'
$DS = Invoke-Sqlcmd -InputFile "$dir/GetSQLServerVersion.sql" -ServerInstance "$FQDN,$SQLPort" -Username "$SQLUserName" -Password "$SQLPwd" -As DataSet
$DS.Tables[0].Rows | %{ Log-Output "{ $($_['LoginName']), $($_['TimeStamp']), $($_['VersionDetail']), $($_['ProductVersion']), $($_['ProductLevel']), $($_['SqlVersion']) }" }

$ActualSQLVersion = $DS.Tables[0].Rows[0]['SqlVersion'];
Log-Output "Actual SQL Version:",$ActualSQLVersion;

Log-Output 'DONE: Prep SQL Server for tSQLt Build';

Return @{
    "VmName"="$VmName";
    "ResourceGroupName"="$ResourceGroupName";
    "SQLVmFQDN"="$FQDN";              ##[vmname].[region].cloudapp.azure.com
    "SQLVmPort"="$SQLPort";                   ##1433
    "SQLVersionEdition"="$SQLVersionEdition"; ##2012Ent
};