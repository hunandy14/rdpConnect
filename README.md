微軟遠端連線自訂解析度與自動複製密碼到剪貼簿
===

### 簡易使用說明
自動連上並複製密碼到剪貼簿
```ps1
irm bit.ly/36tr1aS|iex; rdpConnect '192.168.3.12' '123456' -Ratio:(16/11) -Zoom:1.0
```

bat文件用法
```bat
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "&{irm bit.ly/36tr1aS|iex; rdpConnect '192.168.3.12' '123456' -Ratio:(16/11) -Zoom:1.0}"
```

### 詳細使用範例
```ps1
# 載入函式庫
irm bit.ly/36tr1aS|iex

# 自動複製密碼到剪貼簿 (可為空或忽略-P)
rdpConnect 192.168.3.12 -PasswordCopy:'123456'
# 指定螢幕縮放為1.5倍 (預設1.0)
rdpConnect 192.168.3.12 -Zoom:1.5
# 設定解析度長寬比例(預設是16:11)
rdpConnect 192.168.3.12 -Ratio:(16/11)
# 全螢連接
rdpConnect 192.168.3.12 -FullScreen
# 最大化視窗
rdpConnect 192.168.3.12 -MaxWindows
# 自訂解析度與位置(長, 高 ,x ,y)
rdpConnect 192.168.3.12 -Define 1024 768 100 100
```

範例
```ps1
# 在放大倍率100%的電腦上, 調整縮放比為16:11, 自動複製密碼123456
irm bit.ly/36tr1aS|iex; rdpConnect 192.168.3.12 '123456'
# 在放大倍率150%的電腦上, 調整縮放比為16:11, 自動複製密碼123456
irm bit.ly/36tr1aS|iex; rdpConnect 192.168.3.12 '123456' -Ratio:(16/11) -Zoom:1.5
```

### 離線使用
下載到當前目錄
```ps1
irm bit.ly/36tr1aS|iex; Download '192.168.3.12' '123456' -Ratio:(16/11) -Zoom:1.0 -OutName:'rdpServer1'
```

### 簡介
主要解決的問題
1. 解析度可以自訂或自動調整到適當的大小，避免每次打開都會出現卷軸實在很煩。
2. 對於企業電腦無法儲存密碼的也提供一個變相的解決方案，在打開的時候自動複製指定密碼到剪貼簿。
