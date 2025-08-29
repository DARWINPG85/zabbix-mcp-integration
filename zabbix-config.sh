#!/bin/bash
# zabbix-config.sh - Ejecutar en servidor Zabbix

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Configuración - EDITAR SEGÚN TU ENTORNO ---
MCP_SERVER_IP="20.50.0.100"        # Cambiar por la IP del servidor MCP
ZABBIX_SERVER_IP="20.50.0.10"      # Cambiar por la IP del servidor Zabbix
MCP_AUTH_TOKEN="a8093d0f104f03f657849cb2ebcf415384199db40d7c47a874646e8f7833c8" # Cambiar por tu token de autenticación del MCP
ZABBIX_DB_PASSWORD="zabbix123"     # Cambiar por tu contraseña de la BD de Zabbix
ZABBIX_DB_NAME="zabbix"             # Nombre de la base de datos de Zabbix
ZABBIX_DB_USER="zabbix"             # Usuario de la base de datos de Zabbix

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

check_config() {
    if [[ "$MCP_SERVER_IP" == "TU_IP_MCP_SERVER" ]] || [[ "$ZABBIX_SERVER_IP" == "TU_IP_ZABBIX_SERVER" ]]; then
        error "CONFIGURACIÓN REQUERIDA: Edita las variables al inicio del script con las IPs y credenciales correctas de tu entorno."
    fi
}

echo -e "${BLUE}"
cat << "EOF"
    ┌─┐┌─┐┌┐ ┌┐ ┬─┐ ┬   ┌─┐┌─┐┌┐┌┌─┐┬┌─┐
    ┌─┘├─┤├┴┐├┴┐│┌┴┬┘───│  │ ││││├┤ ││ ┬
    └─┘┴ ┴└─┘└─┘┴┘ └┘   └─┘└─┘┘└┘└  ┴└─┘
                    ZABBIX SERVER CONFIG
EOF
echo -e "${NC}"

echo "🔧 Configurando Servidor Zabbix para integración MCP"
echo "🚀 MCP Server: $MCP_SERVER_IP"
echo "📍 Zabbix Server: $ZABBIX_SERVER_IP"
echo "=================================================="

check_config

# Verificar que somos el servidor Zabbix
if ! curl -s http://localhost/zabbix/api_jsonrpc.php >/dev/null 2>&1; then
    echo "❌ Error: Este no parece ser el servidor Zabbix"
    echo "   Verifica que Zabbix esté instalado y funcionando en este servidor"
    exit 1
fi

log "✅ Servidor Zabbix detectado"

# 1. Verificar usuario MCP en base de datos
log "🔍 Verificando usuario MCP en base de datos..."

echo "🔍 Verificando usuario mcp_user en base de datos:"
# Cambiar a MySQL
MYSQL_PASSWORD="$ZABBIX_DB_PASSWORD" mysql -h localhost -u "$ZABBIX_DB_USER" "$ZABBIX_DB_NAME" << 'EOF'
-- Verificar usuario mcp_user
SELECT 
    u.userid,
    u.username, 
    u.roleid, 
    r.name AS role_name,
    'Usuario encontrado' AS status
FROM users u 
LEFT JOIN role r ON u.roleid = r.roleid 
WHERE u.username = 'mcp_user';

-- Verificar grupos del usuario
SELECT 
    u.username,
    ug.usrgrpid, 
    g.name AS group_name,
    'Grupo asignado' AS status
FROM users u
JOIN users_groups ug ON u.userid = ug.userid
JOIN usrgrp g ON ug.usrgrpid = g.usrgrpid
WHERE u.username = 'mcp_user';
EOF

log "✅ Usuario MCP verificado en base de datos"

# 2. Instalar dependencias para webhook
log "📦 Instalando dependencias para webhook..."

apt update
apt install -y python3 python3-pip curl

# Instalar requests para Python
pip3 install requests

log "✅ Dependencias instaladas"

# 3. Crear script de webhook para Zabbix
log "📝 Creando script de webhook..."

mkdir -p /usr/lib/zabbix/alertscripts

cat > /usr/lib/zabbix/alertscripts/mcp_webhook.py << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
import requests
import sys
from datetime import datetime

def send_to_mcp(args):
    """Envia alertas a servidor MCP"""
    mcp_endpoint = "http://$MCP_SERVER_IP:3001/alerts"
    mcp_token = "$MCP_AUTH_TOKEN"  # Token de autenticación para el servidor MCP
    
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {mcp_token}'
    }
    
    # Extraer argumentos del webhook de Zabbix
    eventid = args[0] if len(args) > 0 else "unknown"
    severity = args[1] if len(args) > 1 else "0"
    message = args[2] if len(args) > 2 else "No message"
    host = args[3] if len(args) > 3 else "unknown"
    value = args[4] if len(args) > 4 else ""
    
    payload = {
        "timestamp": datetime.now().isoformat(),
        "source": "zabbix",
        "eventid": eventid,
        "severity": severity,
        "message": message,
        "host": host,
        "value": value,
        "zabbix_server": "$ZABBIX_SERVER_IP"
    }
    
    try:
        print(f"Sending alert to MCP: {mcp_endpoint}")
        print(f"Payload: {json.dumps(payload, indent=2)}")
        
        response = requests.post(mcp_endpoint, json=payload, headers=headers, timeout=15)
        response.raise_for_status()
        
        print(f"Alert sent successfully: HTTP {response.status_code}")
        print(f"Response: {response.text}")
        return True
        
    except requests.exceptions.Timeout:
        print("? Error: Timeout connecting to MCP server", file=sys.stderr)
        return False
    except requests.exceptions.ConnectionError:
        print("? Error: Cannot connect to MCP server", file=sys.stderr)
        return False
    except requests.exceptions.HTTPError as e:
        print(f"? HTTP Error: {e}", file=sys.stderr)
        print(f"Response: {response.text}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"? Unexpected error: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    # Los argumentos vienen de Zabbix
    args = sys.argv[1:]
    print(f"Script called with args: {args}")
    
    success = send_to_mcp(args)
    sys.exit(0 if success else 1)
EOF

chmod +x /usr/lib/zabbix/alertscripts/mcp_webhook.py

log "✅ Script de webhook creado en /usr/lib/zabbix/alertscripts/mcp_webhook.py"

# 4. Test del script webhook
log "🧪 Probando script webhook..."

echo "Ejecutando test del webhook..."
/usr/lib/zabbix/alertscripts/mcp_webhook.py "test123" "4" "Test alert message" "test-host" "85.5"

# 5. Configurar firewall para permitir conexión hacia MCP
log "🔥 Configurando firewall..."

# Permitir conexión hacia servidor MCP
ufw allow out to $MCP_SERVER_IP port 3001

# Permitir conexión desde MCP hacia Zabbix (para API calls)
ufw allow from $MCP_SERVER_IP to any port 80
ufw allow from $MCP_SERVER_IP to any port 443

log "✅ Firewall configurado"

# 6. Test de conectividad API local
log "🔍 Probando API de Zabbix local..."

api_test=$(curl -s -X POST http://localhost/zabbix/api_jsonrpc.php \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "apiinfo.version",
    "id": 1
  }')

echo "API Response: $api_test"

if echo "$api_test" | grep -q "result"; then
    log "✅ API de Zabbix funcional"
else
    warning "⚠️ Posible problema con API de Zabbix"
fi

# 7. Test de conectividad hacia MCP server
log "🔍 Probando conectividad hacia MCP server..."

if curl -s --connect-timeout 5 http://$MCP_SERVER_IP:3001/health >/dev/null 2>&1; then
    log "✅ Conectividad hacia MCP server OK"
else
    warning "⚠️ No se puede conectar con MCP server (normal si aún no está instalado)"
fi

echo ""
echo "=================================================="
echo "🎉 CONFIGURACIÓN ZABBIX COMPLETADA"
echo "=================================================="
echo ""
echo "🚀 PASOS SIGUIENTES EN INTERFAZ WEB DE ZABBIX:"
echo "   http://zabbix.tudominio.com/zabbix"
echo ""
echo "1. 📝 Crear Media Type (Administration > Media Types > Create):"
echo "   - Name: MCP Integration"
echo "   - Type: Webhook"
echo "   - Script name: mcp_webhook.py"
echo "   - Parameters:"
echo "     {ALERT.SENDTO}"
echo "     {EVENT.ID}"
echo "     {EVENT.SEVERITY}"
echo "     {ALERT.MESSAGE}"
echo "     {HOST.NAME}"
echo "     {ITEM.VALUE}"
echo ""
echo "2. ⚙️ Crear Action (Configuration > Actions > Create):"
echo "   - Name: Send to MCP Server"
echo "   - Conditions: Configure según necesidades"
echo "   - Operations:"
echo "     - Send message"
echo "     - Send to users: mcp_user"
echo "     - Send via: MCP Integration"
echo ""
echo "3. 👤 Configurar User Media (Administration > Users > mcp_user):"
echo "   - Media tab > Add"
echo "   - Type: MCP Integration"
echo "   - Send to: mcp_server"
echo "   - When active: 1-7,00:00-24:00"
echo "   - Use if severity: seleccionar todas"
echo ""
echo "📝 IMPORTANTE:"
echo "   - El token de autenticación del MCP ya ha sido configurado en este script."
echo ""
echo "🧪 DESPUÉS de instalar MCP server, probar con:"
echo "   /usr/lib/zabbix/alertscripts/mcp_webhook.py test123 4 'Test message' test-host 85.5"
echo ""
echo "=================================================="

log "🎯 Configuración de servidor Zabbix completada"
