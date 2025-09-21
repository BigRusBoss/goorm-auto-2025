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
        x86_64) 
            echo "64"
            ;;
        aarch64) 
            echo "arm64-v8a"
            ;;
        *) 
            echo "64"
            ;;
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
    
    cat > "$CONFIG_FILE" << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": PORT_PLACEHOLDER,
      "protocol": "socks",
      "settings": {
        "auth": "noauth"
      }
    },
    {
      "port": HTTP_PORT_PLACEHOLDER,
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
    
    # Заменяем плейсхолдеры на реальные порты
    sed -i "s/PORT_PLACEHOLDER/$port/g" "$CONFIG_FILE"
    sed -i "s/HTTP_PORT_PLACEHOLDER/$((port + 1))/g" "$CONFIG_FILE"
    
    echo "$port"
}

# Функция для создания сервисного скрипта
create_service_script() {
    local port=$1
    
    cat > "$SERVICE_FILE" << 'EOF'
#!/bin/bash

SCRIPT_DIR="$HOME/.goormide"
V2RAY_BIN="$SCRIPT_DIR/bin/v2ray/v2ray"
CONFIG_FILE="$SCRIPT_DIR/bin/v2ray/config.json"
PID_FILE="$SCRIPT_DIR/v2ray.pid"

start_v2ray() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "V2Ray уже запущен (PID: $pid)"
            return 0
        fi
    fi
    
    echo "Запуск V2Ray..."
    nohup "$V2RAY_BIN" run -c "$CONFIG_FILE" >/dev/null 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo "V2Ray успешно запущен (PID: $pid)"
        echo "SOCKS5 прокси: localhost:SOCKS_PORT"
        echo "HTTP прокси: localhost:HTTP_PORT"
        return 0
    else
        echo "Ошибка запуска V2Ray"
        return 1
    fi
}

stop_v2ray() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo "V2Ray остановлен"
        else
            rm -f "$PID_FILE"
            echo "V2Ray не запущен"
        fi
    else
        echo "V2Ray не запущен"
    fi
}

case "$1" in
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
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo "V2Ray запущен (PID: $pid)"
                echo "SOCKS5 прокси: localhost:SOCKS_PORT"
                echo "HTTP прокси: localhost:HTTP_PORT"
            else
                echo "V2Ray не запущен"
                rm -f "$PID_FILE"
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
    
    # Заменяем порты в сервисном скрипте
    sed -i "s/SOCKS_PORT/$port/g" "$SERVICE_FILE"
    sed -i "s/HTTP_PORT/$((port + 1))/g" "$SERVICE_FILE"
    
    chmod +x "$SERVICE_FILE"
}

# Альтернативный метод загрузки только бинарного файла
download_v2ray_binary() {
    local arch=$(get_arch)
    blue "Попытка альтернативной загрузки..."
    
    # Попробуем использовать более простой метод
    local binary_urls=(
        "https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-linux-${arch}.zip"
        "https://github.com/v2fly/v2ray-core/releases/download/v5.13.0/v2ray-linux-${arch}.zip"
    )
    
    for url in "${binary_urls[@]}"; do
        blue "Пробуем: $url"
        if command -v python3 >/dev/null 2>&1; then
            python3 << PYEOF
import urllib.request
import zipfile
import io
import sys
import os

try:
    print("Загрузка...")
    req = urllib.request.Request('$url')
    req.add_header('User-Agent', 'Mozilla/5.0')
    response = urllib.request.urlopen(req, timeout=30)
    data = response.read()
    
    print("Распаковка...")
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        if 'v2ray' in z.namelist():
            with z.open('v2ray') as f:
                with open('v2ray', 'wb') as out:
                    out.write(f.read())
            os.chmod('v2ray', 0o755)
            print("Успешно загружен v2ray")
            sys.exit(0)
        else:
            print("v2ray не найден в архиве")
            sys.exit(1)
except Exception as e:
    print(f"Ошибка: {e}")
    sys.exit(1)
PYEOF
            if [[ $? -eq 0 ]] && [[ -f "v2ray" ]]; then
                return 0
            fi
        fi
    done
    
    return 1
}

# Функция для загрузки V2Ray
download_v2ray() {
    local arch=$(get_arch)
    local version="v5.16.1"
    
    # Попробуем разные источники и версии
    local urls=(
        "https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-${arch}.zip"
        "https://github.com/v2fly/v2ray-core/releases/download/v5.15.3/v2ray-linux-${arch}.zip"
        "https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-linux-${arch}.zip"
    )
    
    blue "Загрузка V2Ray для архитектуры ${arch}..."
    
    cd "$V2RAY_DIR"
    
    # Проверка свободного места
    local available_space=$(df . | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 100000 ]]; then
        yellow "⚠️  Мало свободного места. Попробуем оптимизированную загрузку..."
    fi
    
    local success=false
    for url in "${urls[@]}"; do
        blue "Пробуем загрузить: $(basename "$url")"
        
        # Загрузка с ограничением размера и таймаутом
        if command -v wget >/dev/null 2>&1; then
            if timeout 60 wget --max-redirect=3 --timeout=10 -q -O v2ray.zip "$url"; then
                success=true
                break
            fi
        elif command -v curl >/dev/null 2>&1; then
            if timeout 60 curl --max-time 60 --max-redirs 3 -L -s -o v2ray.zip "$url"; then
                success=true
                break
            fi
        fi
        
        # Удаляем неудачную загрузку
        rm -f v2ray.zip
        yellow "Не удалось загрузить, пробуем следующий URL..."
    done
    
    if [[ "$success" != "true" ]]; then
        red "❌ Не удалось загрузить V2Ray с основных источников"
        yellow "Попробуем альтернативный метод..."
        
        # Альтернативный метод: попробуем загрузить только исполняемый файл
        if download_v2ray_binary; then
            return 0
        else
            red "Все методы загрузки не удались"
            exit 1
        fi
    fi
    
    # Проверяем размер файла
    local file_size=$(stat -c%s v2ray.zip 2>/dev/null || echo 0)
    if [[ $file_size -lt 1000000 ]]; then  # Меньше 1MB - подозрительно мало
        red "❌ Загруженный файл слишком мал ($file_size байт)"
        rm -f v2ray.zip
        
        # Пробуем альтернативный метод
        if download_v2ray_binary; then
            return 0
        else
            exit 1
        fi
    fi
    
    blue "Распаковка архива (размер: $((file_size/1024))KB)..."
    
    # Попробуем разные методы распаковки
    if command -v unzip >/dev/null 2>&1; then
        # Создаем временную директорию для безопасной распаковки
        local temp_dir="/tmp/v2ray_$$"
        mkdir -p "$temp_dir"
        
        # Копируем архив во временную директорию
        cp v2ray.zip "$temp_dir/"
        cd "$temp_dir"
        
        # Пробуем с ограничением памяти и принудительной перезаписью
        if timeout 60 unzip -o -q v2ray.zip v2ray 2>/dev/null; then
            # Копируем обратно
            cp v2ray "$V2RAY_DIR/"
            cd "$V2RAY_DIR"
            rm -rf "$temp_dir"
            success=true
        else
            cd "$V2RAY_DIR"
            rm -rf "$temp_dir"
            yellow "Обычная распаковка не удалась, пробуем альтернативный метод..."
            if download_v2ray_binary; then
                success=true
            else
                red "❌ Ошибка распаковки архива"
                rm -f v2ray.zip
                exit 1
            fi
        fi
    else
        red "❌ unzip не найден, используем альтернативный метод"
        if ! download_v2ray_binary; then
            exit 1
        fi
    fi
    
    rm -f v2ray.zip
    
    # Проверяем что файл v2ray существует и исполняется
    if [[ ! -f "v2ray" ]]; then
        red "❌ Файл v2ray не найден после распаковки"
        exit 1
    fi
    
    chmod +x v2ray
    
    # Проверяем что v2ray работает
    if ! timeout 10 ./v2ray version >/dev/null 2>&1; then
        yellow "⚠️  v2ray не запускается, возможно поврежден"
        if ! download_v2ray_binary; then
            red "❌ Не удалось получить рабочий v2ray"
            exit 1
        fi
    fi
    
    green "✅ V2Ray успешно загружен и готов к работе"
}

# Функция очистки при ошибке
cleanup_on_error() {
    red "❌ Произошла ошибка во время установки"
    blue "Очистка временных файлов..."
    
    # Остановка процессов
    pkill -f "v2ray" 2>/dev/null || true
    
    # Удаление файлов
    rm -rf "$SCRIPT_DIR" 2>/dev/null || true
    rm -rf /tmp/v2ray_* 2>/dev/null || true
    
    # Восстановление bashrc
    if [[ -f "$HOME/.bashrc_bak" ]]; then
        mv "$HOME/.bashrc_bak" "$HOME/.bashrc"
        blue "Восстановлен оригинальный .bashrc"
    fi
    
    yellow "Система возвращена в исходное состояние"
}

# Установка trap для обработки ошибок
trap cleanup_on_error ERR

# Функция для проверки доступности GitHub
check_github_access() {
    blue "Проверка доступности GitHub..."
    
    if command -v curl >/dev/null 2>&1; then
        if timeout 10 curl -s -I https://github.com >/dev/null 2>&1; then
            green "✅ GitHub доступен"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if timeout 10 wget -q --spider https://github.com 2>/dev/null; then
            green "✅ GitHub доступен"
            return 0
        fi
    fi
    
    yellow "⚠️  GitHub может быть недоступен, но попробуем продолжить..."
    return 0
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
    echo "5. Устойчивость к сбоям и ограничениям ресурсов"
    echo
    
    # Проверяем доступность GitHub
    check_github_access
    
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
    
    # Проверка ресурсов системы
    blue "Проверка системных ресурсов..."
    local free_mem=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}' 2>/dev/null || echo "N/A")
    local free_disk=$(df . | awk 'NR==2{print $4}' 2>/dev/null || echo "N/A")
    
    yellow "Свободно памяти: ${free_mem}GB"
    yellow "Свободно места: $((free_disk/1024))MB"
    
    # Очистка временных файлов для освобождения места
    blue "Очистка временных файлов..."
    rm -rf /tmp/v2ray* 2>/dev/null || true
    
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
    
    sleep 3
    
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
        
        # Отключаем trap после успешной установки
        trap - ERR
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
