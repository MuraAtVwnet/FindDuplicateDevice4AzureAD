■ 概要
Azure AD にある重複デバイスの検出、削除をします。
比較は、デバイス名で比較し、最終ログインが一番新しいデバイス以外を削除します。

重複したデバイスは CSV 出力し、削除した場合はリストにその操作も記録されます。
カレントディレクトリに実行ログも出力されます。
データ出力先は default カレントディレクトリですが、指定することも可能です(デバイス名指定はできません)


■ オプション
オプション無し
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


■ 例
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

