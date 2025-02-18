#!/bin/bash
# 把域名增加到pac文件中
# 进入脚本所在的目录
cd "$(dirname "$0")"
pac_file="gfw2.pac"
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
# 检查domain是否存在于pac文件，如果存在，则先删除文件中的这一行
echo "检查域名$domain是否存在$pac_file中"
if grep -q "\"$domain\"" $pac_file; then
    echo "确认!域名$domain存在! 先备份"
    cp $pac_file $pac_file.bak
    echo "删除域名所在的行"
    sed -i "/\"$domain\"/d" $pac_file
fi
# 如果pass_lower为direct，则直接添加到pac文件的directDomains位置的下一行：
if [ "$pass_lower" == "direct" ]; then
    echo "添加域名到直连"
    sed -i "/^var directDomains.*/a\  \"$domain\": 1," "$pac_file"
else
    echo "添加域名到代理"
    sed -i "/^var domainsUsingProxy.*/a\  \"$domain\": 1," "$pac_file"
fi
