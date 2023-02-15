微軟遠端連線自訂解析度與自動複製密碼到剪貼簿
===
# 簡介
主要解決的問題
1. 解析度可以自訂或自動調整到適當的大小，避免每次打開都會出現卷軸實在很煩。
2. 對於企業電腦無法儲存密碼的也提供一個變相的解決方案，在打開的時候自動複製指定密碼到剪貼簿。

快速使用
```ps1
irm bit.ly/rdpConnect|iex; rdpConnect '192.168.3.12' -Copy:'PassWD'
```


<br><br><br>

# 詳細使用方法
## 捷徑的用法
```bat
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "&{irm bit.ly/rdpConnect|iex; rdpConnect '192.168.3.12' -Copy:'PassWD' -Ratio:(16/11)}"
```
<br>

## 詳細使用範例
```ps1
# 載入函式庫
irm 'raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpConnect.ps1'|iex
irm bit.ly/rdpConnect|iex

# 自動複製密碼到剪貼簿
rdpConnect 192.168.3.12 -Copy:'PassWD'
# 設定解析度長寬比例(預設是16:11)
rdpConnect 192.168.3.12 -Ratio:(16/11)
# 全螢連接
rdpConnect 192.168.3.12 -FullScreen
# 最大化視窗
rdpConnect 192.168.3.12 -MaxWindows
# 自訂解析度與位置(長, 高 ,x ,y)
rdpConnect 192.168.3.12 -Define 1600 900 100 100
```


<br><br><br>

# 使用csv管理多個伺服器登入資訊
使用方法
```ps1
irm bit.ly/rdpConnect|iex; rdpMgr 'rdpList.csv'
```

rdpList.csv
```csv
Description,IP,AC,PW
範例1,192.168.3.12,user,abc123
```

單一bat執行檔案
```bat
Set CsvFile=C:\サーバ接続情報.csv

rem Set IMP=Import-Module W:\RdpServer\rdpConnect\rdpConnect.ps1
Set IMP=iex (irm bit.ly/rdpConnect)
Set CMD=rdpMgr '%CsvFile%'
start pwsh.exe -WindowStyle Minimized -NoExit -Command "& {%IMP%;%CMD%;Exit}"
```


<br><br><br>

# 離線使用
```ps1
# 輸出 bat 與 ps1 檔案 (執行時可隨著不同螢幕大小調整rdp內容)
irm bit.ly/rdpConnect|iex; Download '192.168.3.12' '123456' -Ratio:(16/11) -OutName:'rdpServer1'

# 輸出 rdp 檔案 (寫死的rdp)
irm bit.ly/rdpConnect|iex; rdpConnect 192.168.3.12 -OutputRDP:"Default.rdp"
```

## rdpMgr
使用
```ps1
# 打開清單
irm bit.ly/rdpConnect|iex; RdpMgr

# 編輯清單
irm bit.ly/rdpConnect|iex; RdpMgr -EditCsv
```

捷徑
```ps1
powershell -win hid -nop -c "irm bit.ly/rdpConnect|iex; RdpMgr '.\rdpList.csv'"
```

打包成 bat 下載到桌面

```ps1
irm bit.ly/rdpConnect|iex; WrapUp2Bat
```