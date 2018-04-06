<#
.NOTES

.SYNOPSIS
	Collect VHD sizes from Azure Storage Accounts

.DESCRIPTION
    This script will search all storage accounts for a VHD container and then report
    on the size of all blobs in the container.
#>

$results = @()

# Loop through storage accounts and collect blob data
$allStorageAccount = Get-AzureRmStorageAccount

$allStorageAccount | ForEach-Object {

    $storageAccountName = $_.StorageAccountName
    $resourceGroupName = $_.ResourceGroupName

    #Generate storage account access key
    $key = Get-AzureRmStorageAccountKey `
        -ResourceGroupName $_.ResourceGroupName `
        -Name $_.StorageAccountName

    #Generate storage account contect w/ key
    $storageContext = New-AzureStorageContext `
        -StorageAccountName $_.StorageAccountName `
        -StorageAccountKey $key[0].value

        $vhd_blobs = Get-AzureStorageContainer `
            -Context $storageContext `
            -Name "vhds" `
            -ErrorAction SilentlyContinue `
            | Get-AzureStorageBlob | Select-Object Name, Length
        #loop though blobs in each storage account
        $vhd_blobs | ForEach-Object {
            $obj = New-Object psobject -Property @{
                Name = $_.Name
                #Compute the blob size in GB
                Size = [math]::Round($_.Length /1Gb, 3)
                storageAccount = $storageAccountName
                ResourceGroupName = $resourceGroupName
            }
            
            #add discovered results to total tally
            $results += $obj
        }
}
# Diplay results
$results

# Export results to desktop
$results | Select-Object Name, Size, StorageAccount, ResourceGroupName | Export-Csv -NoTypeInformation -Path "~\Desktop\AzureVMBlobSize.csv"