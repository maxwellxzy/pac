#!/bin/bash
# 把域名增加到pac文件中
# 进入脚本所在的目录
cd "$(dirname "$0")"
pac_file="gfw2.pac"
log_file="update.log"
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$log_file"
}

# 获取第一个参数和第二个参数。如果不是2个参数，则提示需要2个参数
if [ $# -ne 2 ]; then
    echo "错误：需要提供两个参数"
    echo "用法：$0 <参数1> <参数2>"
    exit 1
fi
domain=$1
pass=$2
# 检查域名格式
if ! [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    echo "错误：无效的域名格式。请使用类似 example.com 的格式"
    exit 1
fi
# 检查 pass是否为proxy或direct，忽略大小写
pass_lower=$(echo "$pass" | tr '[:upper:]' '[:lower:]')
if [ "$pass_lower" != "proxy" ] && [ "$pass_lower" != "direct" ]; then
    echo "错误：第二个参数必须是 proxy 或 direct（不区分大小写）"
    exit 1
fi
# 检查 PAC 文件是否存在 (Git pull 后，PAC 文件应该存在于指定位置)
if [ ! -f "$pac_file" ]; then
  echo "错误：PAC 文件未找到：$pac_file，请确认 Git 仓库中存在此文件。"
  exit 1
fi
#######正式开始############
export https_proxy=http://127.0.0.1:1099
# Git pull 拉取最新的 PAC 文件
echo "正在从 Git 仓库拉取最新的 PAC 文件..."
git pull 2>&1 | tee -a "$log_file" # 将 git pull 的输出也记录到日志
git_pull_status=$?
if [ $git_pull_status -ne 0 ]; then
  echo "错误：Git pull 命令执行失败，请检查 Git 仓库状态或网络连接。"
  exit 1
fi
# 记录日志开始标记
log "# --- BEGIN ADD DOMAIN LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #"
# 检查domain是否存在于pac文件，如果存在，则先删除文件中的这一行
log "检查域名$domain是否存在$pac_file中"
if grep -q "\"$domain\"" $pac_file; then
    log "确认!域名$domain存在! 先备份"
    cp $pac_file $pac_file.bak
    log "删除域名所在的行"
    sed -i "/\"$domain\"/d" $pac_file
fi
# 如果pass_lower为direct，则直接添加到pac文件的directDomains位置的下一行：
if [ "$pass_lower" == "direct" ]; then
    log "添加域名到直连"
    sed -i "/^var directDomains.*/a\  \"$domain\": 1," "$pac_file"
else
    log "添加域名到代理"
    sed -i "/^var domainsUsingProxy.*/a\  \"$domain\": 1," "$pac_file"
fi
log "更新home.pac"
rm -rf home.pac
cp $pac_file home.pac
sed -i '1s/127\.0\.0\.1/192\.168\.1\.101/' home.pac


log "# --- END ADD DOMAIN LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #"

git add .
git commit -m "add $domain to $pac_file $pass_lower domains"
git push
