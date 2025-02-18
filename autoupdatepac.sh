#!/bin/bash

# ** 切换到脚本所在目录 **
cd "$(dirname "$0")"

# 定义 PAC 文件路径 (假设 PAC 文件在当前 Git 仓库的 pac_file.pac), 已存在配置文件URL, 已存在配置文件名, 输出的自定义配置文件名, 代理组名称, 日志文件名
pac_file="gfw2.pac" # 假设 PAC 文件名为 pac_file.pac 且在当前目录
sr_cnip_ad_conf_url="https://johnshall.github.io/Shadowrocket-ADBlock-Rules-Forever/sr_cnip_ad.conf" # 已存在的 Shadowrocket 配置文件 URL
sr_cnip_ad_conf="sr_cnip_ad.conf" # 下载的已存在的 Shadowrocket 配置文件名 (本地保存文件名)
sr_cnip_ad_custom_conf="sr_cnip_ad_custom.conf" # 输出的自定义 Shadowrocket 配置文件名
proxy_group_name="select_group" # 默认代理组名称，可根据需要修改
https_proxy_address="http://127.0.0.1:1099" # 代理服务器地址，可根据需要修改
log_file="update.log" # 日志文件名

# 定义日志输出函数，方便记录日志并同时输出到终端 (可选)
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$log_file"
}

# 记录日志开始标记
log "# --- BEGIN LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #"

# 设置 HTTPS 代理
export https_proxy="$https_proxy_address"
export http_proxy="$https_proxy_address" # 建议同时设置 http_proxy

log "已设置 HTTPS 代理: $https_proxy"

# Git pull 拉取最新的 PAC 文件
log "正在从 Git 仓库拉取最新的 PAC 文件..."
git pull 2>&1 | tee -a "$log_file" # 将 git pull 的输出也记录到日志
git_pull_status=$?
if [ $git_pull_status -ne 0 ]; then
  log "错误：Git pull 命令执行失败，请检查 Git 仓库状态或网络连接。"
  log "# --- END LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #" # 记录日志结束标记，即使出错也要记录
  exit 1
fi
log "PAC 文件 Git pull 完成。"

# 检查 PAC 文件是否存在 (Git pull 后，PAC 文件应该存在于指定位置)
if [ ! -f "$pac_file" ]; then
  log "错误：PAC 文件未找到：$pac_file，请确认 Git 仓库中存在此文件。"
  log "# --- END LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #" # 记录日志结束标记，即使出错也要记录
  exit 1
fi

# 下载 sr_cnip_ad.conf 文件
log "正在下载 sr_cnip_ad.conf 文件..."
curl -sSL -o "$sr_cnip_ad_conf" "$sr_cnip_ad_conf_url" 2>&1 | tee -a "$log_file" # 将 curl 的输出也记录到日志
curl_status=$?
if [ $curl_status -ne 0 ]; then
  log "错误：下载 sr_cnip_ad.conf 文件失败，请检查网络连接或 URL 是否正确：$sr_cnip_ad_conf_url"
  log "# --- END LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #" # 记录日志结束标记，即使出错也要记录
  exit 1
fi
log "sr_cnip_ad.conf 文件下载完成。"

# 初始化用于存储规则的变量
rule_content=""

# 提取 directDomains 列表
direct_domains_str=$(grep -oP 'var directDomains = \[\K[^\;]*' "$pac_file" | sed 's/\];//g')
if [ -n "$direct_domains_str" ]; then
  IFS=',' read -r -a direct_domains_array <<< "$direct_domains_str"
  for domain in "${direct_domains_array[@]}"; do
    domain=$(echo "$domain" | sed "s/^\s*[\"']//g;s/[\"']\s*$//g")
    if [ -n "$domain" ]; then
      rule_content+=",DOMAIN-SUFFIX,$domain,direct\n"
      rule_content+=",DOMAIN,$domain,direct\n"
    fi
  done
fi

# 提取 domainsUsingProxy 列表
proxy_domains_str=$(grep -oP 'var domainsUsingProxy = \[\K[^\;]*' "$pac_file" | sed 's/\];//g')
if [ -n "$proxy_domains_str" ]; then
  IFS=',' read -r -a proxy_domains_array <<< "$proxy_domains_str"
  for domain in "${proxy_domains_array[@]}"; do
    domain=$(echo "$domain" | sed "s/^\s*[\"']//g;s/[\"']\s*$//g")
    if [ -n "$domain" ]; then
      rule_content+=",DOMAIN-SUFFIX,$domain,$proxy_group_name\n"
      rule_content+=",DOMAIN,$domain,$proxy_group_name\n"
    fi
  done
fi

# 添加 FINAL 规则
rule_content+=",FINAL,$proxy_group_name\n"

# 去除 rule_content 变量开头多余的逗号 (如果存在)
rule_content=$(echo "$rule_content" | sed 's/^,//g')

# 读取已下载的配置文件内容并插入规则
existing_conf_content=""
rule_section_found=false
while IFS= read -r line; do
  existing_conf_content+="$line\n"
  if [[ "$line" == "[Rule]" ]]; then
    rule_section_found=true
    existing_conf_content+="#自定义规则\n"
    existing_conf_content+="$rule_content"
  fi
done < "$sr_cnip_ad_conf"

if ! $rule_section_found; then
  log "警告：在已下载的配置文件中未找到 [Rule] 区块，规则将添加到文件末尾。"
  existing_conf_content+="\n[Rule]\n#自定义规则\n$rule_content"
fi

# 将合并后的配置内容写入新的文件
echo -e "$existing_conf_content" > "$sr_cnip_ad_custom_conf"

log "Shadowrocket 规则已合并到 '$sr_cnip_ad_conf' 并保存为 '$sr_cnip_ad_custom_conf'"
log "已将自定义规则插入到 [Rule] 区块下方，并添加了 '#自定义规则' 备注。"
log "请检查新的配置文件 '$sr_cnip_ad_custom_conf' 是否符合您的预期。"
log "开始执行 Git push..."
git push 2>&1 | tee -a "$log_file" # 将 git push 的输出也记录到日志
git_push_final_status=$?
if [ $git_push_final_status -ne 0 ]; then
  log "错误：Git push 命令执行失败。"
  log "# --- END LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #" # 记录日志结束标记，即使出错也要记录
  exit 1
fi
log "Git push 命令执行完成。"
log "脚本执行完毕，日志记录在 '$log_file' 文件中。"

# 记录日志结束标记
log "# --- END LOG --- $(date '+%Y-%m-%d %H:%M:%S') --- #"

exit 0
