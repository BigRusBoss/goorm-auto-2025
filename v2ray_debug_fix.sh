#!/bin/bash

# V2Ray диагностика и исправление проблем
# Запустите этот скрипт для диагностики проблем с V2Ray

SCRIPT_DIR="$HOME/.goormide"
V2RAY_DIR="$SCRIPT_DIR/bin/v2ray"
CONFIG_FILE="$V2RAY_DIR/config.json"
V2RAY_BIN="$V2RAY_DIR/v2ray"

# Цветной вывод
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

blue "=== V2Ray Диагностика ==="
echo

# 1. Проверка существования файлов
blue "1. Проверка файлов:"
if [[ -f "$V2RAY_BIN" ]]; then
    green "✅ V2Ray бинарник найден: $V2RAY_BIN"
    ls -la "$V2RAY_BIN"
else
    red "❌ V2Ray бинарник не найден: $V2RAY_BIN"
    exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
    green "✅ Конфиг найден: $CONFIG_FILE"
else
    red "❌ Конфиг не найден: $CONFIG_FILE"
fi

echo

# 2. Проверка прав доступа
blue "2. Проверка прав доступа:"
if [[ -x "$V2RAY_BIN" ]]; then
    green "✅ V2Ray исполняемый"
else
    red "❌ V2Ray не исполняемый, исправляем..."
    chmod +x "$V2RAY_BIN"
    green "✅ Права исправлены"
fi

echo

# 3. Проверка архитектуры и совместимости
blue "3. Проверка совместимости:"
echo "Архитектура системы: $(uname -m)"
echo "Тип системы: $(uname -s)"

# Проверяем зависимости
blue "Проверка зависимостей V2Ray:"
if ldd "$V2RAY_BIN" 2>/dev/null; then
    green "✅ Зависимости в порядке"
else
    yellow "⚠️  Не удалось проверить зависимости (возможно статическая сборка)"
fi

echo

# 4. Тест запуска V2Ray
blue "4. Тест запуска V2Ray:"
blue "Проверяем версию V2Ray..."
if timeout 10 "$V2RAY_BIN" version; then
    green "✅ V2Ray отвечает на команду version"
else
    red "❌ V2Ray не отвечает на команду version"
    
    # Попробуем другие команды
    blue "Пробуем альтернативные команды..."
    if timeout 10 "$V2RAY_BIN" -version 2>/dev/null; then
        yellow "⚠️  V2Ray работает с флагом -version"
    elif timeout 10 "$V2RAY_BIN" --version 2>/dev/null; then
        yellow "⚠️  V2Ray работает с флагом --version"
    else
        red "❌ V2Ray не отвечает ни на одну команду"
    fi
fi

echo

# 5. Проверка конфигурации
blue "5. Проверка конфигурации:"
if [[ -f "$CONFIG_FILE" ]]; then
    blue "Содержимое конфига:"
    cat "$CONFIG_FILE"
    echo
    
    # Валидация JSON
    if command -v python3 >/dev/null 2>&1; then
        if python3 -m json.tool "$CONFIG_FILE" >/dev/null 2>&1; then
            green "✅ JSON конфиг валидный"
        else
            red "❌ JSON конфиг невалидный"
        fi
    fi
    
    # Тест конфигурации V2Ray
    blue "Тестируем конфиг V2Ray..."
    if timeout 5 "$V2RAY_BIN" test -c "$CONFIG_FILE" 2>/dev/null; then
        green "✅ Конфиг прошел тест"
    else
        red "❌ Конфиг не прошел тест V2Ray"
        
        # Покажем ошибку
        blue "Ошибка конфига:"
        "$V2RAY_BIN" test -c "$CONFIG_FILE" || true
    fi
else
    red "❌ Конфиг отсутствует"
fi

echo

# 6. Проверка портов
blue "6. Проверка портов:"
if [[ -f "$CONFIG_FILE" ]]; then
    local socks_port=$(grep -o '"port": [0-9]*' "$CONFIG_FILE" | head -1 | grep -o '[0-9]*')
    local http_port=$(grep -o '"port": [0-9]*' "$CONFIG_FILE" | tail -1 | grep -o '[0-9]*')
    
    echo "SOCKS5 порт: $socks_port"
    echo "HTTP порт: $http_port"
    
    # Проверяем занятость портов
    if netstat -ln 2>/dev/null | grep -q ":$socks_port "; then
        red "❌ Порт $socks_port уже занят!"
        netstat -ln | grep ":$socks_port "
    else
        green "✅ Порт $socks_port свободен"
    fi
    
    if netstat -ln 2>/dev/null | grep -q ":$http_port "; then
        red "❌ Порт $http_port уже занят!"
        netstat -ln | grep ":$http_port "
    else
        green "✅ Порт $http_port свободен"
    fi
fi

echo

# 7. Проверка запущенных процессов
blue "7. Проверка процессов V2Ray:"
if pgrep -f v2ray >/dev/null; then
    yellow "⚠️  Найдены запущенные процессы V2Ray:"
    ps aux | grep v2ray | grep -v grep
else
    blue "Процессы V2Ray не найдены"
fi

echo

# 8. Попытка ручного запуска с отладкой
blue "8. Попытка ручного запуска:"
if [[ -f "$CONFIG_FILE" ]]; then
    blue "Запускаем V2Ray в режиме отладки..."
    timeout 5 "$V2RAY_BIN" run -c "$CONFIG_FILE" || {
        red "❌ Ошибка запуска V2Ray"
        echo "Попробуем запустить с более подробным выводом..."
        
        # Попробуем старый синтаксис
        timeout 5 "$V2RAY_BIN" -config="$CONFIG_FILE" 2>&1 || true
    }
fi

echo

# 9. Создание исправленного конфига
blue "9. Создание исправленного конфига:"
create_fixed_config() {
    local port=$((RANDOM % 10000 + 20000))
    local config_file="$V2RAY_DIR/config_fixed.json"
    
    cat > "$config_file" << EOF
{
  "log": {
    "access": "",
    "error": "",
    "loglevel": "info"
  },
  "inbounds": [{
    "port": $port,
    "protocol": "socks",
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls"]
    },
    "settings": {
      "auth": "noauth"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
    
    echo "Создан исправленный конфиг: $config_file"
    echo "SOCKS5 порт: $port"
    
    # Тестируем новый конфиг
    if timeout 5 "$V2RAY_BIN" test -c "$config_file"; then
        green "✅ Новый конфиг валидный"
        
        # Попробуем запустить
        blue "Пробуем запустить с новым конфигом..."
        "$V2RAY_BIN" run -c "$config_file" &
        local pid=$!
        sleep 3
        
        if kill -0 "$pid" 2>/dev/null; then
            green "✅ V2Ray успешно запущен с новым конфигом!"
            green "SOCKS5 прокси: localhost:$port"
            
            # Останавливаем тестовый запуск
            kill "$pid" 2>/dev/null
            
            # Заменяем оригинальный конфиг
            mv "$config_file" "$CONFIG_FILE"
            green "✅ Конфиг обновлен"
            
            # Обновляем сервисный скрипт
            sed -i "s/SOCKS_PORT/$port/g" "$SCRIPT_DIR/service.sh"
            sed -i "s/HTTP_PORT/$port/g" "$SCRIPT_DIR/service.sh"
            
            return 0
        else
            red "❌ Даже новый конфиг не работает"
            kill "$pid" 2>/dev/null || true
            return 1
        fi
    else
        red "❌ Новый конфиг тоже невалидный"
        return 1
    fi
}

create_fixed_config

echo

# 10. Финальные рекомендации
blue "10. Рекомендации:"
echo
yellow "Если V2Ray все еще не работает:"
echo "1. Попробуйте перезагрузить среду GoormIDE"
echo "2. Проверьте, не блокирует ли файрвол порты"
echo "3. Убедитесь что используете правильную версию V2Ray"
echo
yellow "Команды для управления:"
echo "Запуск: $SCRIPT_DIR/service.sh start"
echo "Статус: $SCRIPT_DIR/service.sh status"
echo "Остановка: $SCRIPT_DIR/service.sh stop"
echo
yellow "Ручной запуск для отладки:"
echo "$V2RAY_BIN run -c $CONFIG_FILE"

echo
blue "=== Диагностика завершена ==="
