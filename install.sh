#!/bin/bash

#禁止恶意搬运，修改，贩卖此脚本
#希望大家支持原创

clear

# 获取设备信息
function get_device_info() {
    echo "==================================================="
    echo "                  设备信息检测"
    echo "==================================================="
    
    # 获取主机名
    hostname=$(hostname 2>/dev/null || echo "未知")
    echo "主机名称: $hostname"
    
    # 获取内核版本
    kernel=$(uname -r 2>/dev/null || echo "未知")
    echo "内核版本: $kernel"
    
    # 获取系统信息
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "系统名称: $NAME"
        echo "系统版本: $VERSION"
        echo "系统ID: $ID"
    else
        echo "系统信息: 未知"
    fi
    
    a=$(arch 2>/dev/null || echo "未知") 
    echo "系统架构: $a"
       
    # 获取CPU信息
    cpu_info=$(grep -m 1 "model name" /proc/cpuinfo 2>/dev/null | cut -d ':' -f2 | sed 's/^[ \t]*//')
    if [ -z "$cpu_info" ]; then
        cpu_info="未知"
    fi
    echo "CPU型号: $cpu_info"
    
    # 获取内存信息
    mem_total=$(grep "MemTotal" /proc/meminfo 2>/dev/null | awk '{printf "%.2f GB", $2/1024/1024}')
    if [ -z "$mem_total" ]; then
        mem_total="未知"
    fi
    echo "总内存: $mem_total"
    
    # 获取磁盘信息
    disk_total=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}')
    if [ -z "$disk_total" ]; then
        disk_total="未知"
    fi
    echo "根分区大小: $disk_total"
    
    # 检测是否是Termux容器
    if [ -d "/boot" ] && [ -n "$(ls -A /boot 2>/dev/null)" ]; then
        echo "运行环境: 真实系统"
        IS_REAL_SYSTEM=true
    else
        echo "运行环境: Termux容器"
        IS_REAL_SYSTEM=false
    fi
    
    # 获取当前用户
    echo "当前用户: $(whoami)"
    
    # 获取运行时间
    uptime_info=$(uptime -p 2>/dev/null || echo "未知")
    echo "运行时间: $uptime_info"
    
    echo "==================================================="
    echo ""
}

# 显示设备信息
get_device_info

# 法律声明
echo "==================================================="
echo "                  XHCOC 安装脚本"
echo "==================================================="
echo "法律声明："
echo "1. 本脚本仅供学习和研究使用，禁止用于任何商业用途"
echo "2. 禁止以任何理由贩卖、倒卖本脚本或修改后的版本"
echo "3. 禁止恶意修改脚本用于非法用途"
echo "4. 使用本脚本产生的一切后果由使用者自行承担"
echo "5. 作者不对使用本脚本造成的任何损失负责"
echo "==================================================="
echo "作者B站:摸鱼好无聊wow"
echo ""

# 等待10秒并提示用户同意
echo "脚本将在10秒后开始运行，请阅读并同意上述条款"
for i in {10..1}; do
    echo -ne "倒计时: $i 秒\r"
    sleep 1
done
echo ""

# 获取用户同意
read -p "是否同意上述条款并继续安装? (y/n): " agree
if [ "$agree" != "y" ] && [ "$agree" != "Y" ]; then
    echo "安装已取消"
    exit 1
fi

TARGET_FOLDER="/opt/QQ/resources/app/app_launcher"

# 颜色定义
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log() {
    time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}[${time}]: $1${NC}"
}

function log_error() {
    time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[${time}]: $1${NC}"
}

function log_success() {
    time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}[${time}]: $1${NC}"
}

function log_warning() {
    time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}[${time}]: $1${NC}"
}

function execute_command() {
    log "${2}..."
    ${1}
    if [ $? -eq 0 ]; then
        log_success "${2}成功"
    else
        log_error "${2}失败"
        exit 1
    fi
}

function check_sudo() {
    if ! command -v sudo &>/dev/null; then
        log_error "sudo不存在, 请手动安装: \n Centos: dnf install -y sudo\n Debian/Ubuntu: apt-get install -y sudo\n"
        exit 1
    fi
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "错误: 此脚本需要以 root 权限运行。"
        log_error "请尝试使用 'sudo bash ${0}' 或切换到 root 用户后运行。"
        exit 1
    fi
    log "脚本正在以 root 权限运行。"
}

function check_os_version() {
    sudo apt-get install bc
    log "检查系统版本..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            debian)
                if [ $VERSION_ID -lt 12 ]; then
                    log_error "错误: Debian 版本不能低于 12，当前版本: $VERSION_ID"
                    exit 1
                fi
                ;;
            ubuntu)
                if [ $(echo "$VERSION_ID < 20" | bc -l) -eq 1 ]; then
                    log_error "错误: Ubuntu 版本不能低于 20，当前版本: $VERSION_ID"
                    exit 1
                fi
                ;;
            *)
                log "检测到系统: $NAME $VERSION"
                ;;
        esac
        log_success "系统版本检查通过: $NAME $VERSION"
    else
        log_warning "警告: 无法检测系统版本，继续安装..."
    fi
}

function check_python_version() {
    log "检查Python版本..."
    if command -v python3 &>/dev/null; then
        python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        python_major=$(echo $python_version | cut -d. -f1)
        python_minor=$(echo $python_version | cut -d. -f2)
        
        if [ $python_major -lt 3 ] || ([ $python_major -eq 3 ] && [ $python_minor -lt 7 ]); then
            log_warning "Python版本低于3.7，当前版本: $python_version，将安装最新版本..."
            install_latest_python
        else
            log_success "Python版本符合要求: $python_version"
        fi
    else
        log_warning "未找到Python3，将安装最新版本..."
        install_latest_python
    fi
}

function install_latest_python() {
    log "安装最新版本Python..."
    detect_package_manager
    
    if [ "${package_manager}" = "apt-get" ]; then
        execute_command "sudo apt-get update -y -qq"
        execute_command "sudo apt-get install -y -qq software-properties-common" 
        execute_command "sudo add-apt-repository -y ppa:deadsnakes/ppa" 
        execute_command "sudo apt-get update -y -qq"
        execute_command "sudo apt-get install -y -qq python3.11 python3.11-venv python3.11-dev" 
        execute_command "sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1" 
    elif [ "${package_manager}" = "dnf" ]; then
        execute_command "sudo dnf install -y python3.11 python3.11-venv python3.11-devel" 
        execute_command "sudo alternatives --set python3 /usr/bin/python3.11" 
    fi
    
    # 验证安装
    python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    log_success "Python安装完成，当前版本: $python_version"
}

function check_existing_installation() {
    log "检查现有安装..."
    if [ -d "/opt/QQ" ] || [ -d "/opt/qq" ]; then
        log_warning "检测到现有安装，将进行强制卸载..."
        
        # 停止可能运行的服务
        if pgrep -f "qq" > /dev/null; then
            pkill -f "qq"
            sleep 2
        fi
        
        # 卸载QQ
        if [ "${package_manager}" = "apt-get" ]; then
            execute_command "sudo apt-get remove --purge -y -qq linuxqq" 
        elif [ "${package_manager}" = "dnf" ]; then
            execute_command "sudo dnf remove -y linuxqq" 
        fi
        
        # 删除相关文件和目录
        execute_command "sudo rm -rf /opt/QQ" 
        execute_command "sudo rm -rf /opt/qq" 
        execute_command "sudo rm -rf /root/qq" 
        execute_command "sudo rm -rf /usr/local/bin/start-qq"
        execute_command "sudo rm -rf /root/venv"
        execute_command "sudo rm -rf ${TARGET_FOLDER}/napcat" 
        
        log_success "现有安装已清理完成"
    fi
}

function get_system_arch() {
    system_arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
    if [ "${system_arch}" = "none" ]; then
        log_error "无法识别的系统架构, 请检查错误。"
        exit 1
    fi
    log "当前系统架构: ${system_arch}"
}

function detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        package_manager="apt-get"
        package_installer="dpkg"
    elif command -v dnf &>/dev/null; then
        package_manager="dnf"
        package_installer="rpm"
        dnf_is_el_or_fedora
    else
        log_error "高级包管理器检查失败, 目前仅支持apt-get/dnf。"
        exit 1
    fi
    log "当前高级包管理器: ${package_manager}"
    log "当前基础包管理器: ${package_installer}"
}

function dnf_is_el_or_fedora() {
    if [ -f "/etc/fedora-release" ]; then
        dnf_host="fedora"
    else
        dnf_host="el"
    fi
}

function network_test() {
    local parm1=${1}
    local found=0
    local timeout=10
    local status=0
    target_proxy=""

    local current_proxy_setting="${proxy_num_arg:-9}"

    log "开始网络测试: ${parm1}..."
    log "命令行传入代理参数 (proxy_num_arg): '${proxy_num_arg}', 本次测试生效设置: '${current_proxy_setting}'"

    if [ "${parm1}" == "Github" ]; then
        proxy_arr=("https://ghfast.top" "https://git.yylx.win/" "https://gh-proxy.com" "https://ghfile.geekertao.top" "https://gh-proxy.net" "https://j.1win.ggff.net" "https://ghm.078465.xyz" "https://gitproxy.127731.xyz" "https://jiashu.1win.eu.org" "https://github.tbedu.top")
        check_url="https://raw.githubusercontent.com/NapNeko/NapCatQQ/main/package.json"
    else
        log_error "错误: 未知的网络测试目标 '${parm1}', 默认测试 Github"
        parm1="Github"
        proxy_arr=("https://ghfast.top" "https://git.yylx.win/" "https://gh-proxy.com" "https://ghfile.geekertao.top" "https://gh-proxy.net" "https://j.1win.ggff.net" "https://ghm.078465.xyz" "https://gitproxy.127731.xyz" "https://jiashu.1win.eu.org" "https://github.tbedu.top")
        check_url=""
    fi

    if [[ "${current_proxy_setting}" -ge 1 && "${current_proxy_setting}" -le ${#proxy_arr[@]} ]]; then
        log "手动指定代理: ${proxy_arr[$((current_proxy_setting - 1))]}"
        target_proxy="${proxy_arr[$((current_proxy_setting - 1))]}"
    else
        if [ "${current_proxy_setting}" -ne 0 ]; then
            log "代理设置为自动测试或指定无效 ('${current_proxy_setting}'), 正在检查 ${parm1} 代理可用性..."

            if [ -n "${check_url}" ]; then
                for proxy_candidate in "${proxy_arr[@]}"; do
                    local test_target_url
                    if [ -n "${check_url}" ]; then
                        test_target_url="${proxy_candidate}/${check_url}"
                    fi

                    log "测试代理: ${proxy_candidate} (目标URL: ${test_target_url})"
                    status_and_exit_code=$(curl -k -L --connect-timeout ${timeout} --max-time $((timeout * 2)) -o /dev/null -s -w "%{http_code}:%{exitcode}" "${test_target_url}")
                    status=$(echo "${status_and_exit_code}" | cut -d: -f1)
                    curl_exit_code=$(echo "${status_and_exit_code}" | cut -d: -f2)

                    if [ "${curl_exit_code}" -ne 0 ]; then
                        log_warning "代理 ${proxy_candidate} 测试失败或超时 (curl 退出码: ${curl_exit_code})"
                        continue
                    fi

                    if ([ "${parm1}" == "Github" ] && [ "${status}" -eq 200 ]); then
                        found=1
                        target_proxy="${proxy_candidate}"
                        log "将使用 ${parm1} 代理: ${target_proxy}"
                        break
                    else
                        log_warning "代理 ${proxy_candidate} 返回 HTTP 状态 ${status}, 不适用。"
                    fi
                done
            else
                log_warning "警告: ${parm1} 代理测试缺少有效的检查URL, 无法自动选择代理。"
            fi

            if [ ${found} -eq 0 ]; then
                log_warning "警告: 无法找到可用的 ${parm1} 代理。"
                if [ -n "${check_url}" ]; then
                    log "将尝试直连 ${check_url}..."
                    status_and_exit_code=$(curl -k --connect-timeout ${timeout} --max-time $((timeout * 2)) -o /dev/null -s -w "%{http_code}:%{exitcode}" "${check_url}")
                    status=$(echo "${status_and_exit_code}" | cut -d: -f1)
                    curl_exit_code=$(echo "${status_and_exit_code}" | cut -d: -f2)

                    if [ "${curl_exit_code}" -eq 0 ] && [ "${status}" -eq 200 ]; then
                        log_success "直连 ${parm1} 成功，将不使用代理。"
                        target_proxy=""
                    else
                        log_error "警告: 无法直连到 ${parm1} (${check_url}) (HTTP状态: ${status}, curl退出码: ${curl_exit_code})，请检查网络。"
                        
                        # 询问用户是否继续
                        echo -e "${YELLOW}代理测试失败，是否跳过代理直接继续? (y/n)${NC}"
                        echo -e "${YELLOW}10秒后未选择将自动跳过代理...${NC}"
                        read -t 10 -p "请选择 (y/n): " skip_proxy_choice
                        
                        if [ $? -ne 0 ]; then
                            # 超时情况
                            log "超时未选择，默认跳过代理继续执行"
                            skip_proxy_choice="y"
                        fi
                        
                        if [[ "${skip_proxy_choice}" =~ ^[Yy]$ ]]; then
                            log "用户选择跳过代理，将继续执行后续操作"
                            target_proxy=""
                        else
                            log "用户选择重新尝试代理测试"
                            # 递归调用自身重新尝试
                            network_test "${parm1}"
                            return
                        fi
                    fi
                else
                    log_error "无检查URL, 无法尝试直连。不使用代理。"
                    target_proxy=""
                fi
            fi
        else
            log "代理已通过参数关闭 (序号 0), 将直接连接 ${parm1}..."
            target_proxy=""
            if [ -n "${check_url}" ]; then
                status_and_exit_code=$(curl -k --connect-timeout ${timeout} --max-time $((timeout * 2)) -o /dev/null -s -w "%{http_code}:%{exitcode}" "${check_url}")
                status=$(echo "${status_and_exit_code}" | cut -d: -f1)
                curl_exit_code=$(echo "${status_and_exit_code}" | cut -d: -f2)
                if [ "${curl_exit_code}" -eq 0 ] && [ "${status}" -eq 200 ]; then
                    log_success "直连 ${parm1} (${check_url}) 测试成功。"
                else
                    log_error "警告: 直连 ${parm1} (${check_url}) 测试失败 (HTTP状态: ${status}, curl退出码: ${curl_exit_code}) 或网络不通。"
                    
                    # 询问用户是否继续
                    echo -e "${YELLOW}网络连接测试失败，是否继续执行? (y/n)${NC}"
                    echo -e "${YELLOW}10秒后未选择将自动继续...${NC}"
                    read -t 10 -p "请选择 (y/n): " continue_choice
                    
                    if [ $? -ne 0 ]; then
                        # 超时情况
                        log "超时未选择，默认继续执行"
                        continue_choice="y"
                    fi
                    
                    if [[ ! "${continue_choice}" =~ ^[Yy]$ ]]; then
                        log "用户选择中止执行"
                        exit 1
                    fi
                fi
            else
                log_warning "无检查URL (${parm1}), 代理关闭状态下不执行网络测试。"
            fi
        fi
    fi
}

function install_el_repo() {
    if [ -f "/etc/opencloudos-release" ]; then
        os_version=$(grep -oE '[0;9]+' /etc/opencloudos-release | head -n 1)
        if [[ -n "$os_version" && "$os_version" -ge 9 ]]; then
            log "检测到 OpenCloudOS 9+, 安装 epol-release..."
            execute_command "sudo dnf install -y epol-release" 
        else
            log "OpenCloudOS 版本低于 9 或无法确定版本, 安装 epel-release..."
            execute_command "sudo dnf install -y epel-release" 
        fi
    else
        log "非 OpenCloudOS 的 EL 系统, 安装 epel-release..."
        execute_command "sudo dnf install -y epel-release"
    fi
}

function install_dependency() {
    log "开始更新依赖..."
    detect_package_manager

    if [ "${package_manager}" = "apt-get" ]; then
        log "更新软件包列表中..."
        if ! sudo apt-get update -y -qq; then
            log_error "更新软件包列表失败, 是否继续安装(如果您是全新的系统请选择N)"
            read -p "是否继续? (Y/n): " continue_install
            case "${continue_install}" in
            [nN] | [nN][oO])
                log "用户选择停止安装。"
                exit 1
                ;;
            *)
                log_warning "警告: 跳过软件源更新, 继续安装..."
                ;;
            esac
        else
            log_success "更新软件包列表成功"
        fi
        execute_command "sudo apt-get install -y -qq zip unzip jq curl xvfb screen xauth procps" 
    elif [ "${package_manager}" = "dnf" ]; then
        if [ "${dnf_host}" = "el" ]; then
            install_el_repo
        fi
        execute_command "sudo dnf install --allowerasing -y zip unzip jq curl xorg-x11-server-Xvfb screen procps-ng" 
    fi
    log_success "更新依赖成功..."
}

function create_tmp_folder() {
    if [ -d "./NapCat" ] && [ "$(ls -A ./NapCat)" ]; then
        log_error "文件夹已存在且不为空(./NapCat)，请重命名后重新执行脚本以防误删"
        exit 1
    fi
    sudo mkdir -p ./NapCat
}

function clean() {
    sudo rm -rf ./NapCat
    if [ $? -ne 0 ]; then
        log_warning "临时目录删除失败, 请手动删除 ./NapCat。"
    fi
    sudo rm -rf ./NapCat.Shell.zip
    if [ $? -ne 0 ]; then
        log_warning "NapCatQQ压缩包删除失败, 请手动删除 NapCat.Shell.zip。"
    fi
    if [ -f "/etc/init.d/napcat" ]; then
        sudo rm -f /etc/init.d/napcat
    fi
    if [ -d "${TARGET_FOLDER}/napcat.packet" ]; then
        sudo rm -rf "${TARGET_FOLDER}/napcat.packet"
    fi
}

function download_napcat() {
    create_tmp_folder
    default_file="NapCat.Shell.zip"
    if [ -f "${default_file}" ]; then
        log "检测到已下载NapCat安装包,跳过下载..."
    else
        log "开始下载NapCat安装包,请稍等..."
        network_test "Github"
        napcat_download_url="${target_proxy:+${target_proxy}/}https://github.com/NapNeko/NapCatQQ/releases/download/v4.8.124/NapCat.Shell.zip"

        curl -k -L -# "${napcat_download_url}" -o "${default_file}"
        if [ $? -ne 0 ]; then
            log_error "文件下载失败, 请检查错误。或者手动下载压缩包并放在脚本同目录下"
            clean
            exit 1
        fi

        if [ -f "${default_file}" ]; then
            log_success "${default_file} 成功下载。"
        else
            ext_file=$(basename "${napcat_download_url}")
            if [ -f "${ext_file}" ]; then
                sudo mv "${ext_file}" "${default_file}"
                if [ $? -ne 0 ]; then
                    log_error "文件更名失败, 请检查错误。"
                    clean
                    exit 1
                else
                    log_success "${default_file} 成功重命名。"
                fi
            else
                log_error "文件下载失败, 请检查错误。或者手动下载压缩包并放在脚本同目录下"
                clean
                exit 1
            fi
        fi
    fi

    log "正在验证 ${default_file}..."
    sudo unzip -t "${default_file}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_error "文件验证失败, 请检查错误。"
        clean
        exit 1
    fi

    log "正在解压 ${default_file}..."
    sudo unzip -q -o -d ./NapCat NapCat.Shell.zip
    if [ $? -ne 0 ]; then
        log_error "文件解压失败, 请检查错误。"
        clean
        exit 1
    fi
}

function get_qq_target_version() {
    linuxqq_target_version="3.2.18-36580"
}

function compare_linuxqq_versions() {
    local ver1="${1}"
    local ver2="${2}"

    IFS='.-' read -r -a ver1_parts <<<"${ver1}"
    IFS='.-' read -r -a ver2_parts <<<"${ver2}"

    local length=${#ver1_parts[@]}
    if [ ${#ver2_parts[@]} -lt $length ]; then
        length=${#ver2_parts[@]}
    fi

    for ((i = 0; i < length; i++)); do
        if ((ver1_parts[i] > ver2_parts[i])); then
            force="n"
            return
        elif ((ver1_parts[i] < ver2_parts[i])); then
            force="y"
            return
        fi
    done

    if [ ${#ver1_parts[@]} -gt ${#ver2_parts[@]} ]; then
        force="n"
    elif [ ${#ver1_parts[@]} -lt ${#ver2_parts[@]} ]; then
        force="y"
    else
        force="n"
    fi
}

function check_linuxqq() {
    get_qq_target_version
    linuxqq_package_name="linuxqq"
    local qq_package_json_path="/opt/QQ/resources/app/package.json"
    local napcat_config_path="/opt/QQ/resources/app/app_launcher/napcat/config"
    local backup_path="/tmp/napcat_config_backup_$(date +%s)"

    if [[ -z "${linuxqq_target_version}" || "${linuxqq_target_version}" == "null" ]]; then
        log_error "无法获取目标QQ版本, 请检查错误。"
        exit 1
    fi

    local package_json_exists=true
    if ! [ -f "${qq_package_json_path}" ]; then
        log_warning "警告: LinuxQQ 的核心配置文件 (${qq_package_json_path}) 未找到。可能安装不完整或已损坏。"
        log "将触发 LinuxQQ 的安装/重装流程。"
        force="y"
        package_json_exists=false
    fi

    linuxqq_target_build=${linuxqq_target_version##*-}
    log "最低linuxQQ版本: ${linuxqq_target_version}, 构建: ${linuxqq_target_build}"
    
    if [ "${force}" = "y" ]; then
        log "强制重装模式..."
        local qq_is_installed=false
        local backup_created=false

        if [ -d "${napcat_config_path}" ]; then
            log "检测到现有 Napcat 配置 (${napcat_config_path}), 准备备份..."
            if sudo mkdir -p "${backup_path}"; then
                log "创建备份目录: ${backup_path}"
                if sudo cp -a "${napcat_config_path}/." "${backup_path}/"; then
                    log_success "Napcat 配置备份成功到 ${backup_path}"
                    backup_created=true
                else
                    log_error "警告: Napcat 配置备份失败 (从 ${napcat_config_path} 到 ${backup_path})。将继续重装，但配置可能丢失。"
                    sudo rm -rf "${backup_path}"
                fi
            else
                log_error "严重警告: 无法创建备份目录 ${backup_path}。将继续重装，但配置可能丢失。"
            fi
        else
            log_warning "警告: 未找到现有 Napcat 配置目录 (${napcat_config_path}), 您之前的配置无法找到。"
        fi

        if [ "${package_installer}" = "rpm" ]; then
            if rpm -q ${linuxqq_package_name} &>/dev/null; then
                qq_is_installed=true
            fi
        elif [ "${package_installer}" = "dpkg" ]; then
            if dpkg -l | grep -q "^ii.*${linuxqq_package_name}"; then
                qq_is_installed=true
            fi
        fi

        if [ "${qq_is_installed}" = true ]; then
            log "检测到已安装的 LinuxQQ，将卸载旧版本以进行重装..."
            if [ "${package_manager}" = "dnf" ]; then
                execute_command "sudo dnf remove -y ${linuxqq_package_name}" 
            elif [ "${package_manager}" = "apt-get" ]; then
                execute_command "sudo apt-get remove --purge -y -qq ${linuxqq_package_name}" 
                execute_command "sudo apt-get autoremove -y -qq" 
            fi
        else
            if [ "${package_json_exists}" = true ]; then
                log "包管理器未记录 LinuxQQ 安装, 但将继续执行安装/重装流程。"
            else
                log "未检测到已安装的 LinuxQQ 或其核心文件, 将进行全新安装。"
            fi
        fi

        install_linuxqq

        if [ "${backup_created}" = true ]; then
            log "准备恢复 Napcat 配置从 ${backup_path}..."
            if ! sudo mkdir -p "${napcat_config_path}"; then
                log_error "严重警告: 无法创建目标配置目录 (${napcat_config_path}) 进行恢复。"
            else
                if sudo cp -a "${backup_path}/." "${napcat_config_path}/"; then
                    log_success "Napcat 配置恢复成功到 ${napcat_config_path}"
                    sudo chmod -R 777 "${napcat_config_path}"
                else
                    log_error "警告: Napcat 配置恢复失败 (从 ${backup_path} 到 ${napcat_config_path})。请检查 ${backup_path} 中的备份文件。"
                fi
            fi

            log "清理备份目录 ${backup_path}..."
            sudo rm -rf "${backup_path}"
        else
            log "之前未创建备份, 无需恢复配置。"
        fi
    else
        if [ "${package_installer}" = "rpm" ]; then
            if rpm -q ${linuxqq_package_name} &>/dev/null; then
                linuxqq_installed_version=$(rpm -q --queryformat '%{VERSION}' ${linuxqq_package_name})
                linuxqq_installed_build=${linuxqq_installed_version##*-}
                log "${linuxqq_package_name} 已安装, 版本: ${linuxqq_installed_version}, 构建: ${linuxqq_installed_build}"

                compare_linuxqq_versions "${linuxqq_installed_version}" "${linuxqq_target_version}"
                if [ "${force}" = "y" ]; then
                    log "版本未满足要求, 需要更新。"
                    install_linuxqq
                else
                    log "版本已满足要求, 无需更新。"
                    log "是否强制重装, 10s超时跳过重装(y/n)"
                    read -t 10 -r force
                    if [[ $? -ne 0 ]]; then
                        log "超时未输入, 跳过重装"
                        force="n"
                        update_linuxqq_config "${linuxqq_installed_version}" "${linuxqq_installed_build}"
                    elif [[ "${force}" =~ ^[Yy]?$ ]]; then
                        force="y"
                        log "强制重装..."
                        install_linuxqq
                    elif [[ "${force}" == "n" ]]; then
                        force="n"
                        log "跳过重装"
                        update_linuxqq_config "${linuxqq_installed_version}" "${linuxqq_installed_build}"
                    else
                        force="n"
                        log "输入错误, 跳过重装"
                        update_linuxqq_config "${linuxqq_installed_version}" "${linuxqq_installed_build}"
                    fi
                fi
            else
                install_linuxqq
            fi
        elif [ "${package_installer}" = "dpkg" ]; then
            if dpkg -l | grep ${linuxqq_package_name} &>/dev/null; then
                linuxqq_installed_version=$(dpkg -l | grep "^ii" | grep "linuxqq" | awk '{print $3}')
                linuxqq_installed_build=${linuxqq_installed_version##*-}
                log "${linuxqq_package_name} 已安装, 版本: ${linuxqq_installed_version}, 构建: ${linuxqq_installed_build}"

                compare_linuxqq_versions "${linuxqq_installed_version}" "${linuxqq_target_version}"
                if [ "${force}" = "y" ]; then
                    log "版本未满足要求, 需要更新。"
                    install_linuxqq
                else
                    log "版本已满足要求, 无需更新。"
                    log "是否强制重装, 10s超时跳过重装(y/n)"
                    read -t 10 -r force
                    if [[ $? -ne 0 ]]; then
                        log "超时未输入, 跳过重装"
                        force="n"
                        update_linuxqq_config "${linuxqq_installed_version}" "${linuxqq_installed_build}"
                    elif [[ "${force}" =~ ^[Yy]?$ ]]; then
                        force="y"
                        log "强制重装..."
                        install_linuxqq
                    elif [[ "${force}" == "n" ]]; then
                        force="n"
                        log "跳过重装"
                        update_linuxqq_config "${linuxqq_installed_version}" "${linuxqq_installed_build}"
                    else
                        force="n"
                        log "输入错误, 跳过重装"
                        update_linuxqq_config "${linuxqq_installed_version}" "${linuxqq_installed_build}"
                    fi
                fi
            else
                install_linuxqq
            fi
        fi
    fi
}

function install_linuxqq() {
    get_system_arch
    log "安装LinuxQQ..."
    
    if [ "${system_arch}" = "amd64" ]; then
        if [ "${package_installer}" = "rpm" ]; then
            qq_download_url="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.19_250904_x86_64_01.rpm"
        elif [ "${package_installer}" = "dpkg" ]; then
            qq_download_url="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.19_250904_amd64_01.deb"
        fi
    elif [ "${system_arch}" = "arm64" ]; then
        if [ "${package_installer}" = "rpm" ]; then
            qq_download_url="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.19_250904_aarch64_01.rpm"
        elif [ "${package_installer}" = "dpkg" ]; then
            qq_download_url="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.19_250904_arm64_01.deb"
        fi
    fi

    if ! [[ -f "QQ.deb" || -f "QQ.rpm" ]]; then
        if [ "${qq_download_url}" = "" ]; then
            log_error "获取QQ下载链接失败, 请检查错误, 或者手动下载QQ安装包并重命名为QQ.deb或QQ.rpm(注意自己的系统架构)放到脚本同目录下。"
            exit 1
        fi
        log "QQ下载链接: ${qq_download_url}"
        log "如果无法下载请手动下载QQ安装包并重命名为QQ.deb或QQ.rpm(注意自己的系统架构)放到脚本同目录下"
    fi

    if [ "${package_manager}" = "dnf" ]; then
        if ! [ -f "QQ.rpm" ]; then
            sudo curl -k -L -# "${qq_download_url}" -o QQ.rpm
            if [ $? -ne 0 ]; then
                log_error "文件下载失败, 请检查错误。"
                exit 1
            else
                log_success "文件下载成功"
            fi
        else
            log "检测到当前目录下存在QQ安装包, 将使用本地安装包进行安装。"
        fi

        execute_command "sudo dnf install -y ./QQ.rpm" 
        rm -f QQ.rpm
    elif [ "${package_manager}" = "apt-get" ]; then
        if ! [ -f "QQ.deb" ]; then
            sudo curl -k -L -# "${qq_download_url}" -o QQ.deb
            if [ $? -ne 0 ]; then
                log_error "文件下载失败, 请检查错误。" 
                exit 1
            else
                log_success "文件下载成功"
            fi
        else
            log "检测到当前目录下存在QQ安装包, 将使用本地安装包进行安装。"
        fi

        execute_command "sudo apt-get install -f -y -qq ./QQ.deb" 
        execute_command "sudo apt-get install -y -qq libnss3" 
        execute_command "sudo apt-get install -y -qq libgbm1"
        log "检测系统可用的 libasound2 ..."
        if apt-cache show libasound2t64 >/dev/null 2>&1; then
            TARGET_PKG="libasound2t64"
        else
            TARGET_PKG="libasound2"
        fi

        log "安装 $TARGET_PKG"
        if sudo apt-get install -y -qq "$TARGET_PKG"; then
            log_success "安装 $TARGET_PKG 成功"
        else
            log_error "安装 $TARGET_PKG 失败"
            exit 1
        fi
        sudo rm -f QQ.deb
    fi
    update_linuxqq_config "${linuxqq_target_version}" "${linuxqq_target_build}"
}

function update_linuxqq_config() {
    log "正在更新用户QQ配置..."

    confs=$(sudo find /home -name "config.json" -path "*/.config/QQ/versions/*" 2>/dev/null)
    if [ -f "/root/.config/QQ/versions/config.json" ]; then
        confs="/root/.config/QQ/versions/config.json ${confs}"
    fi

    for conf in ${confs}; do
        log "正在修改 ${conf}..."
        sudo jq --arg targetVer "${1}" --arg buildId "${2}" \
            '.baseVersion = $targetVer | .curVersion = $targetVer | .buildId = $buildId' "${conf}" >"${conf}.tmp" &&
            sudo mv "${conf}.tmp" "${conf}" || {
            log_error "QQ配置更新失败! "
            exit 1
        }
    done
    log_success "更新用户QQ配置成功..."
}

function check_napcat() {
    napcat_target_version=$(jq -r '.version' "./NapCat/package.json")
    if [[ -z "${napcat_target_version}" || "${napcat_target_version}" == "null" ]]; then
        log_error "无法获取NapCatQQ版本, 请检查错误。"
        exit 1
    else
        log "最新NapCatQQ版本: v${napcat_target_version}"
    fi

    if [ "$force" = "y" ]; then
        log "强制重装模式..."
        install_napcat
    else
        if [ -d "${TARGET_FOLDER}/napcat" ]; then
            napcat_installed_version=$(jq -r '.version' "${TARGET_FOLDER}/napcat/package.json")
            IFS='.' read -r i1 i2 i3 <<<"${napcat_installed_version}"
            IFS='.' read -r t1 t2 t3 <<<"${napcat_target_version}"
            if ((i1 < t1 || (i1 == t1 && i2 < t2) || (i1 == t1 && i2 == t2 && i3 < t3))); then
                install_napcat
            else
                log "已安装最新版本, 无需更新。"
            fi
        else
            install_napcat
        fi
    fi
}

function install_napcat() {
    if [ ! -d "${TARGET_FOLDER}/napcat" ]; then
        sudo mkdir -p "${TARGET_FOLDER}/napcat/"
    fi

    log "正在移动文件..."
    sudo cp -r -f ./NapCat/* "${TARGET_FOLDER}/napcat/"
    if [ $? -ne 0 ] && [ $? -ne 1 ]; then
        log_error "文件移动失败, 请检查错误。"
        clean
        exit 1
    else
        log_success "移动文件成功"
    fi

    sudo chmod -R 777 "${TARGET_FOLDER}/napcat/"
    log "正在修补文件..."
    sudo echo "(async () => {await import('file:///${TARGET_FOLDER}/napcat/napcat.mjs');})();" >/opt/QQ/resources/app/loadNapCat.js
    if [ $? -ne 0 ]; then
        log_error "loadNapCat.js文件写入失败, 请检查错误。"
        clean
        exit 1
    else
        log_success "修补文件成功"
    fi
    modify_qq_config
    clean
}

function modify_qq_config() {
    log "正在修改QQ启动配置..."

    if sudo jq '.main = "./loadNapCat.js"' /opt/QQ/resources/app/package.json >./package.json.tmp; then
        sudo mv ./package.json.tmp /opt/QQ/resources/app/package.json
        log_success "修改QQ启动配置成功..."
    else
        log_error "修改QQ启动配置失败..."
        exit 1
    fi
}

function install_framework() {
    log "开始安装适配框架..."
    
    # 切换到root目录
    cd /root || exit 1
    
    # 检查Python版本
    check_python_version
    
    # 安装虚拟环境包
    log "安装虚拟环境包..."
    if [ "${package_manager}" = "apt-get" ]; then
        execute_command "sudo apt-get install -y -qq python3-venv"
    elif [ "${package_manager}" = "dnf" ]; then
        execute_command "sudo dnf install -y python3-virtualenv" 
    fi
    
    # 配置pip清华镜像源
    log "配置pip清华镜像源..."
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    log_success "pip清华镜像源配置完成"
    
    # 创建虚拟环境
    log "创建虚拟环境..."
    python3 -m venv /root/venv
    if [ $? -ne 0 ]; then
        log_error "虚拟环境创建失败"
        exit 1
    fi
    log_success "虚拟环境创建成功"
    
    # 切换到/opt目录并创建qq文件夹
    cd /opt || exit 1
    mkdir -p qq
    cd qq || exit 1
    
    # 检查本地是否有框架压缩包
    if [ -f "/root/framework.zip" ]; then
        log "检测到本地框架压缩包，使用本地文件..."
        cp /root/framework.zip .
    elif [ -f "./framework.zip" ]; then
        log "检测到当前目录下有框架压缩包，使用本地文件..."
    else
        # 下载框架压缩包
        log "下载框架压缩包..."
        framework_url="https://xinghe.x7go.top/xinghe/napcat.zip"
        curl -k -L -# "${framework_url}" -o framework.zip
        if [ $? -ne 0 ]; then
            log_error "框架压缩包下载失败"
            exit 1
        fi
        log_success "框架压缩包下载成功"
    fi
    
    # 检查是否安装unzip，如果没有则安装
    if ! command -v unzip &>/dev/null; then
        log "安装unzip..."
        if [ "${package_manager}" = "apt-get" ]; then
            execute_command "sudo apt-get install -y -qq unzip" 
        elif [ "${package_manager}" = "dnf" ]; then
            execute_command "sudo dnf install -y unzip"
        fi
    fi
    
    # 验证压缩包
    log "正在验证 framework.zip..."
    unzip -t framework.zip >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_error "框架压缩包验证失败，文件可能已损坏"
        exit 1
    fi
    
    # 解压压缩包
    log "解压框架压缩包..."
    unzip -q -o framework.zip
    if [ $? -ne 0 ]; then
        log_error "解压框架压缩包失败"
        exit 1
    fi
    log_success "解压框架压缩包成功"
    
    # 删除压缩包
    rm -f framework.zip
    log "删除压缩包完成"
    
    # 激活虚拟环境并安装依赖
    log "开始安装必要依赖…"
    apt install python3-dev gcc -y
    
    log "安装框架依赖..."
    source /root/venv/bin/activate
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        if [ $? -ne 0 ]; then
            log_error "依赖安装失败"
            exit 1
        fi
        log_success "依赖安装成功"
    else
        log_warning "未找到requirements.txt文件，跳过依赖安装"
    fi
    deactivate
    
    # 创建启动脚本
    log "创建启动脚本..."
    mkdir -p /usr/local/bin
    cat > /usr/local/bin/start-qq << EOF
#!/bin/bash

if pgrep -f "python3 main.py" >/dev/null; then
    echo "框架已经在运行中，请勿重复启动"
    exit 1
fi

screen -dmS napcat bash -c "xvfb-run -a qq --no-sandbox"
cd /opt/qq
source /root/venv/bin/activate
python3 main.py
EOF
    
    # 设置启动脚本权限
    chmod +x /usr/local/bin/start-qq
    log_success "启动脚本创建完成"
        
    # 创建软链接
    log "创建软链接..."
    if [ -d "/opt/qq" ]; then
        ln -sf /opt/qq /root/qq
        log_success "框架软链接创建成功"
    fi
        
    log_success "适配框架安装完成"
    log "您可以使用 'start-qq' 命令启动框架/QQ"
}

function install_nodejs_npm() {
    log "开始安装Node.js和npm..."
    
    # 检测包管理器并安装Node.js和npm
    if [ "${package_manager}" = "apt-get" ]; then
        # 对于Debian/Ubuntu系统
        execute_command "sudo apt install -y nodejs npm" 
    elif [ "${package_manager}" = "dnf" ]; then
        # 对于Fedora/CentOS/RHEL系统
        execute_command "sudo dnf install -y nodejs npm"
    fi
    
    # 验证安装并显示版本
    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        node_version=$(node -v)
        npm_version=$(npm -v)
        log_success "Node.js安装完成，版本: $node_version"
        log_success "npm安装完成，版本: $npm_version"
    else
        log_error "Node.js或npm安装失败"
        exit 1
    fi
}
function chmod_root() {
    log "正在设置权限…"
    
    sudo chmod 777 -R /opt/qq
    
    sudo chmod 700 /root
    
    sudo chmod 700 /usr/local/bin/start-qq
    
    log_success "相关权限设置完成"
}

function self_destruct() {
    log "开始自毁程序，清理残留文件..."
    
    # 删除脚本自身
    if [ -f "$0" ]; then
        rm -rf "$0"
        log_success "脚本自身已删除"
    fi
    
    # 清理下载的安装包
    if [ -f "QQ.deb" ]; then
        rm -rf QQ.deb
        log_success "QQ.deb 已删除"
    fi
    
    if [ -f "QQ.rpm" ]; then
        rm -rf QQ.rpm
        log_success "QQ.rpm 已删除"
    fi
    
    if [ -f "NapCat.Shell.zip" ]; then
        rm -rf NapCat.Shell.zip
        log_success "NapCat.Shell.zip 已删除"
    fi
    
    if [ -f "framework.zip" ]; then
        rm -rf framework.zip
        log_success "framework.zip 已删除"
    fi
    
    # 清理临时目录
    if [ -d "./NapCat" ]; then
        rm -rf ./NapCat
        log_success "临时目录 ./NapCat 已删除"
    fi
    
    # 清理其他可能残留的文件
    find /tmp -name "napcat_config_backup_*" -type d -exec rm -rf {} \; 2>/dev/null && log_success "备份目录已清理"
    
    log_success "自毁程序完成，所有残留文件已清理"
}

function setup_autostart() {
    echo "==================================================="
    echo "                 开机自启动设置"
    echo "==================================================="
    echo "警告：设置开机自启动可能存在以下风险："
    echo "1. 系统启动时间可能会增加"
    echo "2. 如果程序出现问题，可能会影响系统稳定性"
    echo "3. 目前该功能仍处于内测阶段，可能存在未知问题"
    echo "4. 如果不需要自启动，可以随时手动启动程序"
    echo "5. 一旦出现任何故障脚本的开发者不负任何责任"
    echo "==================================================="
    
    # 等待10秒
    echo "将在10秒后询问是否添加开机自启动..."
    for i in {10..1}; do
        echo -ne "倒计时: $i 秒\r"
        sleep 1
    done
    echo ""
    
    # 询问用户
    read -p "是否添加开机自启动? (y/n): " autostart_choice
    if [[ "$autostart_choice" =~ ^[Yy]$ ]]; then
        log "正在设置开机自启动..."
        
        # 检测运行环境
        if [ "$IS_REAL_SYSTEM" = true ]; then
            # 真实系统 - 使用systemd
            setup_systemd_autostart
        else
            # 容器环境 - 检查是否是tmoe-linux容器
            if [ -f "/usr/local/etc/tmoe-linux/environment/entrypoint" ]; then
                setup_tmoe_autostart
            else
                log_warning "无法识别的容器环境，无法设置开机自启动"
                echo "请手动设置启动命令: start-qq"
            fi
        fi
    else
        log "跳过开机自启动设置"
    fi
}

function setup_systemd_autostart() {
    log "检测到真实系统，使用systemd设置开机自启动..."
    
    # 创建systemd服务文件
    cat > /etc/systemd/system/napcat.service << EOF
[Unit]
Description=NapCatQQ
After=network-online.target       
Wants=network-online.target       

[Service]
Type=oneshot                  
RemainAfterExit=yes             
User=root                      
ExecStart=/opt/qq/start.sh        

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable napcat.service
    
        cat > /opt/qq/start.sh << EOF
#!/bin/bash

start-qq
EOF

    chmod 777 /opt/qq/start.sh
    
    if [ $? -eq 0 ]; then
        log_success "开机自启动设置成功"
        log "可以使用以下命令管理服务:"
        log "启动服务: systemctl start napcat"
        log "停止服务: systemctl stop napcat"
        log "查看状态: systemctl status napcat"
        log "禁用自启动: systemctl disable napcat"
    else
        log_error "开机自启动设置失败"
    fi
}

function setup_tmoe_autostart() {
    log "检测到tmoe-linux容器，修改entrypoint文件设置开机自启动..."
    
    # 备份原文件
    cp /usr/local/etc/tmoe-linux/environment/entrypoint /usr/local/etc/tmoe-linux/environment/entrypoint.backup
    
    # 检查是否已经添加了启动命令
    if grep -q "/usr/local/bin/start-qq" /usr/local/etc/tmoe-linux/environment/entrypoint; then
        log "启动命令已存在，无需重复添加"
        return
    fi
    
    # 在文件末尾添加启动命令
    rm -rf /usr/local/etc/tmoe-linux/environment/entrypoint
    echo "" >> /usr/local/etc/tmoe-linux/environment/entrypoint
    echo "sudo bash start-qq " >> /usr/local/etc/tmoe-linux/environment/entrypoint
    
    if [ $? -eq 0 ]; then
        log_success "开机自启动设置成功"
        log "启动命令已添加到: /usr/local/etc/tmoe-linux/environment/entrypoint"
    else
        log_error "开机自启动设置失败"
        # 恢复备份
        cp /usr/local/etc/tmoe-linux/environment/entrypoint.backup /usr/local/etc/tmoe-linux/environment/entrypoint
    fi
    
    # 删除备份文件
    rm -f /usr/local/etc/tmoe-linux/environment/entrypoint.backup
}

function show_main_info() {
    echo -e "\n${BLUE}---------------- Shell 安装完成 ----------------${NC}"
    echo ""
    log "启动 Napcat (需要图形环境或 Xvfb):"
    log "  sudo xvfb-run -a qq --no-sandbox"
    echo ""
    log "后台运行 Napcat (使用 screen)(请使用 root 账户):"
    log "  启动: screen -dmS napcat bash -c \"xvfb-run -a qq --no-sandbox\""
    log "  带账号启动: screen -dmS napcat bash -c \"xvfb-run -a qq --no-sandbox -q QQ号码\""
    log "  附加到会话: screen -r napcat (按 Ctrl+A 然后按 D 分离)"
    log "  停止会话: screen -S napcat -X quit"
    echo ""
    log "Napcat 相关信息:"
    log "  安装位置: ${TARGET_FOLDER}/napcat"
    log "  WebUI Token: 查看 ${TARGET_FOLDER}/napcat/config/webui.json 文件获取"
    echo ""
    log "框架/QQ启动命令:"
    log "  start-qq"
    log "  框架主文件目录:/opt/qq/"
    log "  已连接链接至/root/qq"    
    log "  请仔细阅读开发文档.md"
    echo ""
    # 显示Node.js和npm版本
    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        node_version=$(node -v)
        npm_version=$(npm -v)
        log "Node.js版本: $node_version"
        log "npm版本: $npm_version"
    fi
    echo ""
    echo -e "${BLUE}--------------------------------------------------${NC}"
}

function shell_help() {
    echo "命令选项 (高级用法):"
    echo "您可以在 原安装命令 后面添加以下参数:"
    echo ""
    echo "  --force                   强制重装 LinuxQQ 和 NapCat"
    echo "  --proxy [0-n]             指定下载代理序号 (0: 不使用, 1-n: 内置列表)"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --force)
        force="y"
        shift
        ;;
    --proxy)
        proxy_num_arg="$2"
        shift
        shift
        ;;
    --help | -h)
        shell_help
        exit 0
        ;;
    *)
        echo "未知参数: $1"
        shell_help
        exit 1
        ;;
    esac
done

check_sudo
check_root
check_os_version
check_existing_installation

log "开始 Shell 安装流程..."
install_dependency
download_napcat
check_linuxqq
check_napcat

log "NapCat安装完成，开始安装框架..."
install_framework

log "框架安装完成，开始安装Node.js和npm..."
install_nodejs_npm

log "开始设置系统权限"
chmod_root

show_main_info
clean
log_success "Shell 安装流程完成。"

# 询问是否设置开机自启动
setup_autostart

# 执行自毁程序
self_destruct

exit 0