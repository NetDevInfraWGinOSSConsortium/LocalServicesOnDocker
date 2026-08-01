-- 準備完了判定用のスクリプト（Start-Services.ps1 / Start-Services_wsl2.ps1 から
-- docker compose exec 経由で実行される）。
--
--   sqlplus -s -L SCOTT/tiger@localhost/XE @/ready/ready.sql
--
-- ・XE サービスと SCOTT でログインできること（-L でログイン失敗時は非ゼロ終了）
-- ・Shippers が 3 行揃っていること
-- の両方を確認する。3 行揃っていなければ 1/0 で ORA-01476 を発生させ、
-- WHENEVER SQLERROR EXIT FAILURE により異常終了＝未準備として扱う。
-- （CASE は短絡評価されるため、3 行あるときに 1/0 は評価されない）
WHENEVER SQLERROR EXIT FAILURE
WHENEVER OSERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 TERMOUT OFF
SELECT CASE WHEN COUNT(*) = 3 THEN 0 ELSE 1/0 END FROM Shippers;
EXIT SUCCESS
