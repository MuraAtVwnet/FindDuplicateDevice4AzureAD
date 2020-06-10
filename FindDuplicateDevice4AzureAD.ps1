<#
.SYNOPSIS
Azure AD にある重複デバイスの検出、削除をします。
比較は、デバイス名で比較し、最終ログインが一番新しいデバイス以外を削除します。

重複したデバイスは CSV 出力し、削除した場合はリストにその操作も記録されます。
カレントディレクトリに実行ログも出力されます。
データ出力先は default カレントディレクトリですが、指定することも可能です(デバイス名指定はできません)

.DESCRIPTION
重複リストのみ出力(Removeオプションを指定していない時の動作)
    重複リスト出力だけをします

削除(-Remove)
    重複したデバイスを削除します
    重複リストには削除処理が記録されます

テスト(-WhatIf)
    実際の削除はせず、動作確認だけします

CSV 出力ディレクトリ指定(-CSVPath)
    CSV の出力先ディレクトリ
    省略時はカレントに出力されます

実行ログ出力ディレクトリ(-LogPath)
    実行ログの出力先
    省略時はカレントディレクトリに出力します

全デバイス リスト出力(-AllList)
    重複確認する全デバイス リストを CSV 出力します

.EXAMPLE
PS C:\Test> .\FindDuplicateDevice4AzureAD.ps1
デバイス重複リストを出力します

PS C:\Test> .\FindDuplicateDevice4AzureAD.ps1 -AllList
全デバイスとデバイス重複リストを出力します

PS C:\Test> .\FindDuplicateDevice4AzureAD.ps1 -Remove
重複したデバイスを削除し、全デバイスと重複リストを出力します

PS C:\Test> .\FindDuplicateDevice4AzureAD.ps1 -Remove -WhatIf
重複したデバイスを削除テストをし(削除はしません)、デバイス重複リストを出力します

PS C:\Test> .\FindDuplicateDevice4AzureAD.ps1 -CSVPath C:\CSV
デバイス重複リストを C:\CSV に出力します

PS C:\Test> .\FindDuplicateDevice4AzureAD.ps1 -LogPath C:\Log
実行ログを C:\Log に出力します

.PARAMETER Remove
重複デバイスを削除します
Remove が指定されていない場合は重複リストのみを出力します

.PARAMETER CSVPath
CSV の出力先
省略時はカレントディレクトリに出力します

.PARAMETER LogPath
実行ログの出力先
省略時はカレントディレクトリに出力します

.PARAMETER AllList
重複確認する全デバイス リストを CSV 出力します

.PARAMETER WhatIf
実際の削除はせず、動作確認だけします

.LINK
重複したデバイス排除するスクリプト(PowerShell)
http://www.vwnet.jp/Windows/PowerShell/2018111601/FindDuplicateDevice.htm
#>

###################################################
# 重複デバイス検出
###################################################
Param(
	[switch]$Remove,			# 削除実行
	[string]$CSVPath,			# CSV 出力 Path
	[string]$LogPath,			# ログ出力ディレクトリ
	[switch]$AllList,			# 全リスト出力
	[switch]$WhatIf				# テスト
	)

# 全デバイスデータ名
$GC_AllDeviceName = "AllDevice(AzureAD)"

# 重複デバイスデータ名
$GC_DuplicateDeviceName = "DuplicateDevice(AzureAD)"

# ログの出力先
if( $LogPath -eq [string]$null ){
	$GC_LogPath = Convert-Path .
}
else{
	$GC_LogPath = $LogPath
}

# Windows PowerShell 以外はサポートされていない
if( $PSVersionTable.PSVersion.Major -ge 6 ){
	Log "[FAIL] PowerShell Core is not supported."
	exit
}

# ログファイル名
$GC_LogName = "FindDuplicateDevice(AzureAD)"

# CSV レコード
class CsvRecode {
	[string] $DeviceName
	[string] $LastLogon
	[string] $ObjectID
	[string] $DeviceID
	[string] $Status
	[string] $Operation
}

# 定数
$GC_StatusOriginal = "Original"
$GC_StatusDuplicate = "Duplicate"
$GC_OperationRemove = "Remove"


# DeviceName = DisplayName
# LastLogon = ApproximateLastLogonTimeStamp
# ObjectID = ObjectId
# DeviceID = DeviceId

# Connect-AzureAD
# $Devices = Get-AzureADDevice




##########################################################################
# ログ出力
##########################################################################
function Log(
			$LogString
			){

	$Now = Get-Date

	# Log 出力文字列に時刻を付加(YYYY/MM/DD HH:MM:SS.MMM $LogString)
	$Log = $Now.ToString("yyyy/MM/dd HH:mm:ss.fff") + " "
	$Log += $LogString

	# ログデバイス名が設定されていなかったらデフォルトのログデバイス名をつける
	if( $GC_LogName -eq $null ){
		$GC_LogName = "LOG"
	}

	# ログデバイス名(XXXX_YYYY-MM-DD.log)
	$LogDevice = $GC_LogName + "_" +$Now.ToString("yyyy-MM-dd") + ".log"

	# ログフォルダーがなかったら作成
	if( -not (Test-Path $GC_LogPath) ) {
		New-Item $GC_LogPath -Type Directory
	}

	# ログデバイス名
	$LogDeviceName = Join-Path $GC_LogPath $LogDevice

	# ログ出力
	Write-Output $Log | Out-Device -DevicePath $LogDeviceName -Encoding Default -append

	# echo
	[System.Console]::WriteLine($Log)
}


###################################################
# 必要データ取得
###################################################
filter GetDeviceData{

	$DeviceData = New-Object CsvRecode

	# デバイス名
	$DeviceData.DeviceName = $_.DisplayName

	# 最終ログイン日時
	$DeviceData.LastLogon = $_.ApproximateLastLogonTimeStamp

	# オブジェクト ID
	$DeviceData.ObjectID = $_.ObjectId

	# デバイス ID
	$DeviceData.DeviceID = $_.DeviceId

	return $DeviceData
}

###################################################
# 重複デバイス検出
###################################################
filter KeyBreak{

	BEGIN{
		# 初期値設定
		$InitFlag = $true
		$FirstNameFlag = $true

		$NewKeyDeviceName = [string]$null
		$NewRec = $null
	}

	PROCESS{
		### 通常処理
		# 比較キーとデータセット
		$OldKeyDeviceName = $NewKeyDeviceName
		$OldRec = $NewRec

		$NewKeyDeviceName = $_.DeviceName
		$NewRec = $_

		# デバイス名重複
		if( $OldKeyDeviceName -eq $NewKeyDeviceName ){
			$TmpRec = $OldRec
			if( $FirstNameFlag -eq $true ){
				$FirstNameFlag = $false
				$TmpRec.Status = $GC_StatusOriginal
			}
			else{
				$TmpRec.Status = $GC_StatusDuplicate
			}

			# 重複データ
			return $TmpRec
		}
		# キーブレーク
		else{
			# キーブレークした後は重複データを出力する
			if( $FirstNameFlag -eq $false ){
				$TmpRec = $OldRec

				# デバイス名重複
				$TmpRec.Status = $GC_StatusDuplicate

				# 重複データ
				return $TmpRec
			}
		}
	}

	END{
		# 残ったデーターを出力
		# キーブレークした後は重複データを出力する
		if( $FirstNameFlag -eq $false ){

			$TmpRec = $NewRec

			# デバイス名重複
			$TmpRec.Status = $GC_StatusDuplicate

			# 重複データ
			return $TmpRec
		}
	}
}

###################################################
# Sort
###################################################
function DataSort($TergetDevicesData){
	[array]$SortDevicesData = $TergetDevicesData | Sort-Object -Property `
													DisplayName,
													ApproximateLastLogonTimeStamp

	return $SortDevicesData
}

###################################################
# 全データ出力
###################################################
function OutputAllData([array]$DuplicateDevices, $Now){
	$OutputDevice = Join-Path $CSVPath ($GC_AllDeviceName + "_" +$Now.ToString("yyyy-MM-dd_HH-mm") + ".csv")

	Log "[INFO] Output all Device list : $OutputDevice"

	if( -not(Test-Path $CSVPath)){
		mdkdir $CSVPath
	}

	$DuplicateDevices | Export-Csv -Path $OutputDevice -Encoding Default
}


###################################################
# 重複データ出力
###################################################
function OutputDuplicateData([array]$SortDevicesData, $Now){

	$OutputDevice = Join-Path $CSVPath ($GC_DuplicateDeviceName + "_" +$Now.ToString("yyyy-MM-dd_HH-mm") + ".csv")

	Log "[INFO] Output duplicate Device list : $OutputDevice"

	if( -not(Test-Path $CSVPath)){
		mdkdir $CSVPath
	}
	$DuplicateDevices | Export-Csv -Path $OutputDevice -Encoding Default
}


###################################################
# デバイス操作
###################################################
function DeviceOperation( [array]$DuplicateDevices ){

	$DuplicateDeviceCount = $DuplicateDevices.Count
	$OperationCount = 0

	for( $i = 0; $i -lt $DuplicateDeviceCount; $i++ ){
		# デバイス名重複
		if( $DuplicateDevices[$i].Status -eq $GC_StatusDuplicate ){

			# 重複したオブジェクト IDデバイス名
			$DuplicateDeviceObjectId = $DuplicateDevices[$i].ObjectId
			$DuplicateDeviceName = $DuplicateDevices[$i].DeviceName

			# デバイス重複
			# オペレーション : Remove
			if( $Remove ){
				$DuplicateDevices[$i].Operation = $GC_OperationRemove

				if( -not $WhatIf ){
					# 削除
					Remove-AzureADDevice -ObjectId $DuplicateDevice
				}

				Log "[INFO] Device duplicate (Remove) : $DuplicateDeviceName / $DuplicateDeviceObjectId"

					$OperationCount++
				}
			}
		}
	}

	return $OperationCount
}

###################################################
# main
###################################################
Log "[INFO] ============== START =============="

# Azure AD Login
try{
	Connect-AzureAD -ErrorAction Stop
}
catch{
	Log "Azure login fail !"
	exit
}

# CSV 出力先
if( $CSVPath -eq [string]$null){
	$CSVPath = Convert-Path .
}

# 全デバイスを取得
[array]$TergetDevicesData = Get-AzureADDevice | GetDeviceData

# 対象デバイス数
$TergetDevicesDataCount = $TergetDevicesData.Count

# 対象0件なら処理しない
if( $TergetDevicesDataCount -eq 0 ){
	Log "[INFO] Terget Devices is zero."
}
else{
	# 対象デバイス数表示
	Log "[INFO] Terget Devices count : $TergetDevicesDataCount"

	# Data Sort
	Log "[INFO] Data sort."
	[array]$SortDevicesData = DataSort $TergetDevicesData

	# 出力デバイス用処理時間
	$Now = Get-Date

	# 全デバイスリスト出力
	if( $AllList -eq $true ){
		Log "[INFO] Output all data"
		OutputAllData $SortDevicesData $Now
	}

	# 重複デバイス検出
	Log "[INFO] Get duplicate Devices."
	[array]$DuplicateDevices = $SortDevicesData | KeyBreak

	# 重複デバイス数
	$DuplicateDeviceCount = $DuplicateDevices.Count

	# 重複 0 件なら処理しない
	if($DuplicateDeviceCount -eq 0){
		Log "[INFO] Duplicate Device is zero."
	}
	else{
		# 重複デバイス数表示
		Log "[INFO] Duplicate Device count : $DuplicateDeviceCount"

		# 重複デバイス操作
		Log "[INFO] Device operation"
		$Counter = DeviceOperation $DuplicateDevices

		if( $Counter -ne 0 ){
			Log "[INFO] Device deduplication count : $Counter"
		}

		# 重複データ出力
		OutputDuplicateData $DuplicateDevices $Now
	}
}

Log "[INFO] ============== END =============="
