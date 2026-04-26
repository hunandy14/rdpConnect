# rdpConnect v1（維護模式）

此目錄為 v1 維護線。新功能請到根目錄 `src/` 的 v2。

## 此處可以做的事

- 修 bug
- 修安全問題
- 補文件

## 此處絕對不做的事

- 加新功能
- 改函式名、改參數（會破壞既有使用者腳本）
- 重構（重構在 `src/` 進行）

## 版本標記

每次修改打 tag：`v1.0.x`

## 穩定 URL
- 最新（含 bug fix）：`raw.githubusercontent.com/hunandy14/rdpConnect/master/legacy/rdpConnect.ps1`

根目錄 `rdpConnect.ps1` 是一行 redirect，永久指向此目錄的 `rdpConnect.ps1`，所以 `irm bit.ly/rdpConnect | iex` 仍會載入 v1。
