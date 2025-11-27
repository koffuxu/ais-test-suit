# ais-test-suit

这是一个测试环境使用的脚本仓库说明 (README)，里面包含多个脚本。

## ftp-upload.sh
这个仓库包含一个用于将本地文件或目录上传到 FTP 服务器的脚本 `ftp-upload.sh`。

快速使用说明：

- 交互式方式（会提示输入密码）：
  ./ftp-upload.sh <local_path> <remote_folder>

- 非交互式方式（通过环境变量提供密码）：
  export FTP_PASSWORD='你的密码'
  ./ftp-upload.sh ./test1126/ test-1126

- 当服务器使用自签名证书时临时跳过证书校验（不安全，仅用于内部或测试环境）：
  FTP_SKIP_CERT_VERIFY=1 ./ftp-upload.sh ./test1126/ test-1126

注意：
- 推荐先将服务器证书加入系统信任链，或让服务端使用由公认 CA 签发的证书，而不是长期跳过证书验证。
- 脚本不会删除或移动本地文件；`put` 与 `mirror` 操作默认不会移除本地源。

验证情况：macos验证成功
