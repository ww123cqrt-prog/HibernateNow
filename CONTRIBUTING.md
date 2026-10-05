# 参与开发

欢迎通过 Issue 描述问题，或提交 Pull Request。界面使用中文；讨论可使用中文或英文。

## 本地验证

需要 macOS、Swift 5.10 或更新版本、Xcode Command Line Tools 和 Python 3。

```bash
./script/verify_logic.sh
./script/build_and_run.sh --build
./script/package_release.sh
python3 script/verify_release.py
```

逻辑检查使用依赖注入和临时目录，不会写入真实电源设置或 sudoers。
`--build` 与打包脚本不会启动或停止已经运行的应用。`--verify` 和 `--install` 会运行应用。
管理员授权与真实合盖验证需由本机操作者执行，保存原始配置并在结束后恢复。

## 修改边界

保持三档命令的固定参数、写入后的完整读回核对、失败后的状态失效，以及账号级权限说明。
新增特权命令必须说明用途、权限范围和恢复方式，并补充有意义的验证。
仅修改界面文案或美术资源时，不应改变系统电源行为。

提交前运行相关检查；PR 说明改了什么、为什么修改、验证范围与未验证项。
不要提交密码、令牌、用户绝对路径、构建产物或本机配置。

## 发布

版本号位于 `VERSION`。发布前更新 `CHANGELOG.md`，提交源码并确认工作区干净。
从该提交打包，检查 `release-manifest.json` 的 `source_commit` 与发布标签一致，
且 `source_tree_clean` 为 `true`。Release 附件包含 DMG、应用 ZIP、构建清单和 SHA-256 校验文件。
当前打包采用 ad-hoc 签名；正式公证分发需要维护者另行提供 Developer ID 证书和 Apple 公证凭据。
