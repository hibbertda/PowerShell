function closesmatch ($closesmatch_input) {
    $diff = [math]::abs($closesmatch_input - $mdSkuCost[0])
    $min_index = 0
    
    for ($i = 1; $i -lt $mdSkuCost.count; $i++){
       $new_diff = [math]::abs($closesmatch_input - $mdSkuCost[$i])
       if ($new_diff -lt $diff) {
          $diff = $new_diff
          $min_index = $i
       }
    }
    return $($mdSkuCost[$min_index])
}

# import managed disk SKU info (general)
$mdsku_info = import-csv -Path .\MD_skuinfo.csv
$mdSkuCost = $mdsku_info."diskSize(Gb)" | Sort-Object -Unique

# import VHD size report
$VHDSize = import-csv -Path .\AzureVMBlobSize-4-6-2018.csv

# add col for MDSku/MDPrice
$VHDSize | Add-Member -Type NoteProperty -Name 'MDSku' -Value $null
$VHDSize | Add-Member -Type NoteProperty -Name 'MDPrice' -Value $null

$VHDSize | ForEach-Object {
    $mdSize = closesmatch($_.size)
    $selection = ($mdsku_info | Where-Object {$_."DiskSize(gb)" -eq $mdSize -and $_.sku -like "P*"})

    $_.MDSku = $selection.sku
    $_.MDPrice = $selection.PriceperMonth

}
$VHDSize | Export-Csv -NoTypeInformation -Path ~\desktop\vhdtomd.csv