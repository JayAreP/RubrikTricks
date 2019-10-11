$node_ip = 'sand1-rbk01.rubrikdemo.com'
$api_token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI5NDdlNGZhNC02MjA1LTQzOTYtOTc3Mi01OWRhZDFmOTU0YzhfZDYzZDZjNDEtZjdlMS00OTIzLTlkZGItMDZiNWU3NWFjZGJiIiwiaXNzIjoiOTQ3ZTRmYTQtNjIwNS00Mzk2LTk3NzItNTlkYWQxZjk1NGM4IiwianRpIjoiM2Y4ZmYzNTAtMDcwNi00MmNhLWFhYzAtMGU3NWRmY2NlMjhmIn0.szHwjShdsu1YAcJcge3ICJxn0o75nAKAVG3DxNNodVQ'

Connect-Rubrik -Server $node_ip -Token $api_token

# collect the stats!
$get_cdm_version = Invoke-RubrikRESTCall -endpoint 'cluster/me/version' -method GET
$cdm_version = $get_cdm_version.version

$get_logical_bytes = Invoke-RubrikRESTCall -api 'internal' -endpoint 'stats/snapshot_storage/logical' -method GET
$logical_bytes = $get_logical_bytes.value

$get_snapshot_bytes = Invoke-RubrikRESTCall -api 'internal' -endpoint 'stats/snapshot_storage/physical' -method GET
$snapshot_bytes = $get_snapshot_bytes.value

$get_total_storage = Invoke-RubrikRESTCall -api 'internal' -endpoint 'stats/total_storage' -method GET
$total_storage = $get_total_storage.value

$get_available_storage = Invoke-RubrikRESTCall -api 'internal' -endpoint 'stats/available_storage' -method GET
$available_storage = $get_available_storage.value


# change the stats!

$logical_dedupe = 100 * (1 - ($snapshot_bytes / $logical_bytes))
$logical_ratio = 100 / (100 - $logical_dedupe)

$logical_TB = ($logical_bytes / 1000000000000)
$snapshot_TB = ($snapshot_bytes / 1000000000000)
$total_storage_TB = ($total_storage / 1000000000000)
$available_storage_TB = ($available_storage / 1000000000000)
$available_percentage = ($available_storage / $total_storage) * 100

[math]::Round($a,2)

$logical_dedupe = [math]::round($logical_dedupe, 1)
$logical_ratio = [math]::round($logical_ratio, 1)
$logical_TB = [math]::round($logical_TB, 1)
$snapshot_TB = [math]::round($snapshot_TB, 1)
$total_storage_TB = [math]::round($total_storage_TB, 1)
$available_storage_TB = [math]::round($available_storage_TB, 1)
$available_percentage = [math]::round($available_percentage, 1)

# Get Node tunnel status

$node_status = Invoke-RubrikRESTCall -api 'internal' -Endpoint 'node' -Method GET

foreach ($i in $node_status.data) {
    if ($i.supportTunnel.isTunnelEnabled) {
        $nodetunnelport = $i.supportTunnel.port
        exit
    } else {
        $nodetunnelport = '----'
    }
}

$get_streams_count = Invoke-RubrikRESTCall -api 'internal' -Endpoint 'stats/streams/count' -Method GET
$streams_count = $get_streams_count.count

# Build the message

$message = "CDM: $cdm_version | Total Storage: $total_storage_TB`TB | Available Storage: $available_storage_TB`TB ($available_percentage`%) | Logical data reduction: $logical_dedupe ($logical_dedupe`:1) | Local snapshots: $snapshot_TB`TB | Running backups: $streams_count | Tunnel: $nodetunnelport" 

$config = New-Object psobject
$config | Add-Member -MemberType NoteProperty -Name 'classificationColor' -Value '#9DD5FB'
$config | Add-Member -MemberType NoteProperty -Name 'classificationMessage' -Value $message

# Set the banner

Invoke-RubrikRESTCall -api 'internal' -endpoint 'cluster/me/security_classification' -Method PUT -Body $config


