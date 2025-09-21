#!/bin/bash

# GoormIDE V2Ray Auto Deploy Script - Updated 2025
# Обновленная версия для современных версий V2Ray

set -e

USER=$(whoami)
SCRIPT_DIR="$HOME/.goormide"
V2RAY_DIR="$SCRIPT_DIR/bin/v2ray"
CONFIG_FILE="$V2RAY_DIR/config.json"
SERVICE_FILE="$SCRIPT_DIR/service.sh"

# Цветной вывод
red() {
    echo -e "\033[31m$1\033[0m"
}

green() {
    echo -e "\033[32m$1\033[0m"
}

blue() {
    echo -e "\033[34m$1\033[0m"
}

yellow() {
    echo -e "\033[33m$1\033[0m"
}

# Функция для проверки архитектуры
get_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "64" ;;
        aarch64) echo "arm64-v8a" ;;
        *) echo "64" ;;
    esac
}

# Функция для генерации UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# Функция для создания конфига V2Ray
create_v2ray_config() {
    local uuid=$(generate_uuid)
    local port=$((RANDOM % 10000 + 20000))
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $port,
      "protocol": "socks",
      "settings": {
        "auth": "noauth"
      }
    },
    {
      "port": $((port + 1)),
      "protocol": "http",
      "settings": {}
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
    
    echo "$port"
}

# Функция для создания сервисного скрипта
create_service_script() {
    local port=$1
    
    cat > "$SERVICE_FILE" << EOF
#!/bin/bash

SCRIPT_DIR="\$HOME/.goormide"
V2RAY_BIN="\$SCRIPT_DIR/bin/v2ray/v2ray"
CONFIG_FILE="\$SCRIPT_DIR/bin/v2ray/config.json"
PID_FILE="\$SCRIPT_DIR/v2ray.pid"

start_v2ray() {
    if [[ -f "\$PID_FILE" ]]; then
        local pid=\$(cat "\$PID_FILE")
        if kill -0 "\$pid" 2>/dev/null; then
            echo "V2Ray уже запущен (PID: \$pid)"
            return 0
        fi
    fi
    
    echo "Запуск V2Ray..."
    nohup "\$V2RAY_BIN" run -c "\$CONFIG_FILE" >/dev/null 2>&1 &
    local pid=\$!
    echo "\$pid" > "\$PID_FILE"
    
    sleep 2
    if kill -0 "\$pid" 2>/dev/null; then
        echo "V2Ray успешно запущен (PID: \$pid)"
        echo "SOCKS5 прокси: localhost:$port"
        echo "HTTP прокси: localhost:$((port + 1))"
        return 0
    else
        echo "Ошибка запуска V2Ray"
        return 1
    fi
}

stop_v2ray() {
    if [[ -f "\$PID_FILE" ]]; then
        local pid=\$(cat "\$PID_FILE")
        if kill -0 "\$pid" 2>/dev/null; then
            kill "\$pid"
            rm -f "\$PID_FILE"
            echo "V2Ray остановлен"
        else
            rm -f "\$PID_FILE"
            echo "V2Ray не запущен"
        fi
    else
        echo "V2Ray не запущен"
    fi
}

case "\$1" in
    start)
        start_v2ray
        ;;
    stop)
        stop_v2ray
        ;;
    restart)
        stop_v2ray
        sleep 1
        start_v2ray
        ;;
    status)
        if [[ -f "\$PID_FILE" ]]; then
            local pid=\$(cat "\$PID_FILE")
            if kill -0 "\$pid" 2>/dev/null; then
                echo "V2Ray запущен (PID: \$pid)"
                echo "SOCKS5 прокси: localhost:$port"
                echo "HTTP прокси: localhost:$((port + 1))"
            else
                echo "V2Ray не запущен"
                rm -f "\$PID_FILE"
            fi
        else
            echo "V2Ray не запущен"
        fi
        ;;
    *)
        start_v2ray
        ;;
esac
EOF
    
    chmod +x "$SERVICE_FILE"
}

# Функция для загрузки V2Ray
download_v2ray() {
    local arch=$(get_arch)
    local version="v5.16.1"  # Последняя стабильная версия
    local url="https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-${arch}.zip"
    
    blue "Загрузка V2Ray ${version} для архитектуры ${arch}..."
    
    cd "$V2RAY_DIR"
    
    if command -v wget >/dev/null 2>&1; then
        wget -q -O v2ray.zip "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -s -o v2ray.zip "$url"
    else
        red "Ошибка: не найден wget или curl"
        exit 1
    fi
    
    if command -v unzip >/dev/null 2>&1; then
        unzip -q v2ray.zip
        rm v2ray.zip
    else
        red "Ошибка: не найден unzip"
        exit 1
    fi
    
    chmod +x v2ray
}

# Основная функция установки
install() {
    blue "### GoormIDE V2Ray Auto Deploy Script 2025 ###"
    green "Обновленная версия скрипта для современных версий V2Ray"
    echo
    
    yellow "Особенности:"
    echo "1. Автоматический запуск после логина в GoormIDE"
    echo "2. Поддержка современных версий V2Ray"
    echo "3. SOCKS5 и HTTP прокси"
    echo "4. Автоматическая генерация портов"
    echo
    
    green "Продолжить установку? [Y/n]: "
    read -r confirm
    
    if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
        blue "Начинаем установку..."
    else
        red "Установка отменена"
        exit 0
    fi
    
    # Проверка на повторную установку
    if [[ -d "$SCRIPT_DIR" ]]; then
        yellow "Обнаружена предыдущая установка. Переустановить? [Y/n]: "
        read -r confirm
        
        if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
            blue "Удаление предыдущей установки..."
            pkill -f "v2ray" 2>/dev/null || true
            rm -rf "$SCRIPT_DIR"
            # Восстановление bashrc если есть бэкап
            if [[ -f "$HOME/.bashrc_bak" ]]; then
                mv "$HOME/.bashrc_bak" "$HOME/.bashrc"
            fi
        else
            green "Выход без изменений"
            exit 0
        fi
    fi
    
    # Создание директорий
    blue "Создание директорий..."
    mkdir -p "$V2RAY_DIR"
    
    # Загрузка V2Ray
    download_v2ray
    
    # Создание конфигурации
    blue "Создание конфигурации..."
    local port=$(create_v2ray_config)
    
    # Создание сервисного скрипта
    blue "Создание сервисного скрипта..."
    create_service_script "$port"
    
    # Настройка автозапуска
    blue "Настройка автозапуска..."
    if [[ -f "$HOME/.bashrc" ]]; then
        cp "$HOME/.bashrc" "$HOME/.bashrc_bak"
    fi
    
    # Добавление автозапуска в bashrc
    echo "" >> "$HOME/.bashrc"
    echo "# GoormIDE V2Ray Auto Start" >> "$HOME/.bashrc"
    echo "if [[ -f \"$SERVICE_FILE\" ]]; then" >> "$HOME/.bashrc"
    echo "    \"$SERVICE_FILE\" start >/dev/null 2>&1" >> "$HOME/.bashrc"
    echo "fi" >> "$HOME/.bashrc"
    
    # Запуск V2Ray
    blue "Запуск V2Ray..."
    "$SERVICE_FILE" start
    
    sleep 2
    
    # Проверка статуса
    if pgrep -f "v2ray" >/dev/null; then
        green "✅ Установка завершена успешно!"
        echo
        green "Информация о прокси:"
        echo "🔹 SOCKS5: localhost:$port"
        echo "🔹 HTTP: localhost:$((port + 1))"
        echo
        yellow "Управление V2Ray:"
        echo "Запуск: $SERVICE_FILE start"
        echo "Остановка: $SERVICE_FILE stop"
        echo "Статус: $SERVICE_FILE status"
        echo "Перезапуск: $SERVICE_FILE restart"
        echo
        blue "Настройка прокси в браузере:"
        echo "1. Установите SwitchyOmega в Chrome/Firefox"
        echo "2. Добавьте SOCKS5 прокси: localhost:$port"
        echo "3. Или HTTP прокси: localhost:$((port + 1))"
    else
        red "❌ Ошибка установки. V2Ray не запустился."
        red "Проверьте логи и попробуйте запустить вручную:"
        red "$SERVICE_FILE start"
        exit 1
    fi
}

# Проверка окружения
if [[ -z "$GOORM_PROJECT_NAME" && -z "$GOORM_TASK_ID" ]]; then
    yellow "⚠️  Предупреждение: Скрипт оптимизирован для GoormIDE"
    yellow "Вы можете продолжить, но некоторые функции могут работать некорректно"
    echo
fi

# Запуск установки
install
