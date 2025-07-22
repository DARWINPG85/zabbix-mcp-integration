# 🚀 MCP-Zabbix Integration

**Integración completa entre servidor MCP (Model Context Protocol) y Zabbix para monitoreo inteligente con IA**

## 📋 Descripción

Esta solución proporciona una integración bidireccional entre un servidor MCP y Zabbix, permitiendo:

- 🤖 **Consultas inteligentes** a Zabbix usando IA (Gemini)
- 📊 **Webhook de alertas** desde Zabbix hacia el servidor MCP
- 🔧 **API REST** para interacciones programáticas
- 📈 **Monitoreo en tiempo real** con respuestas en lenguaje natural

## 🏗️ Arquitectura

```
┌─────────────────┐    API Calls    ┌─────────────────┐
│   MCP SERVER    │◄──────────────► │ ZABBIX SERVER   │
│  (Puerto 3001)  │                 │  (Puerto 80)    │
│                 │    Webhooks     │                 │
│ - Node.js       │◄──────────────── │ - Zabbix API    │
│ - Express       │                 │ - PostgreSQL    │
│ - Gemini AI     │                 │ - Nginx         │
│ - Redis         │                 │                 │
└─────────────────┘                 └─────────────────┘
```

## 📋 Prerrequisitos

### Servidor MCP
- ✅ Sistema operativo: RHEL 8+, CentOS 8+, Rocky Linux 8+, AlmaLinux 8+
- ✅ Memoria RAM: Mínimo 2GB, recomendado 4GB
- ✅ Espacio en disco: Mínimo 10GB libres
- ✅ Usuario con privilegios sudo (miembro del grupo `wheel`)

### Servidor Zabbix
- ✅ Zabbix 7.4 instalado y funcionando
- ✅ PostgreSQL configurado
- ✅ Acceso a la base de datos de Zabbix
- ✅ Usuario con privilegios de administración en Zabbix

### Tokens y APIs necesarios
- 🔑 **Token de API de Zabbix** (Administration → General → API tokens)
- 🔑 **Clave API de Google Gemini** (https://makersuite.google.com/app/apikey)

## 🚀 Instalación

### Paso 1: Preparar configuración

Antes de ejecutar los scripts, debes editar las variables de configuración en cada archivo:

#### Variables a configurar:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `TU_IP_MCP_SERVER` | IP del servidor MCP | `192.168.1.100` |
| `TU_IP_ZABBIX_SERVER` | IP del servidor Zabbix | `192.168.1.200` |
| `TU_DOMINIO_ZABBIX` | Dominio/IP de Zabbix | `zabbix.miempresa.com` |
| `TU_MCP_AUTH_TOKEN` | Token de autenticación MCP | `abc123xyz789...` |
| `TU_ZABBIX_DB_PASSWORD` | Contraseña de la BD Zabbix | `mi_password_seguro` |

### Paso 2: Instalar servidor MCP

```bash
# 1. Descargar y editar el script
wget https://raw.githubusercontent.com/TU_USUARIO/mcp-zabbix/main/mcp-install-rhel.sh
nano mcp-install-rhel.sh  # Editar las variables de configuración

# 2. Dar permisos de ejecución
chmod +x mcp-install-rhel.sh

# 3. Ejecutar instalación (NO como root)
./mcp-install-rhel.sh
```

### Paso 3: Configurar servidor Zabbix

```bash
# 1. Descargar y editar el script
wget https://raw.githubusercontent.com/TU_USUARIO/mcp-zabbix/main/zabbix-config.sh
nano zabbix-config.sh  # Editar las variables de configuración

# 2. Dar permisos de ejecución
chmod +x zabbix-config.sh

# 3. Ejecutar configuración (como root)
sudo ./zabbix-config.sh
```

### Paso 4: Configurar tokens y APIs

#### En el servidor MCP:
```bash
# Editar archivo de configuración
nano /opt/mcp-zabbix/.env

# Configurar las siguientes variables:
ZABBIX_API_TOKEN=tu_token_de_zabbix_aqui
GEMINI_API_KEY=tu_clave_gemini_aqui
MCP_AUTH_TOKEN=tu_token_mcp_seguro_aqui
```

#### En Zabbix Web Interface:

1. **Crear Token de API:**
   - Ve a: Administration → General → API tokens
   - Click "Create API token"
   - Name: `MCP Integration`
   - User: `mcp_user` (o admin)
   - Expiry: Sin expiración o fecha lejana
   - Copia el token generado

2. **Configurar Media Type:**
   - Ve a: Administration → Media types → Create media type
   - Name: `MCP Integration`
   - Type: `Webhook`
   - Script name: `mcp_webhook.py`
   - Parameters:
     ```
     {ALERT.SENDTO}
     {EVENT.ID}
     {EVENT.SEVERITY}
     {ALERT.MESSAGE}
     {HOST.NAME}
     {ITEM.VALUE}
     ```

3. **Configurar Action:**
   - Ve a: Configuration → Actions → Create action
   - Name: `Send to MCP Server`
   - Conditions: Configurar según necesidades
   - Operations:
     - Operation type: `Send message`
     - Send to users: `mcp_user`
     - Send only to: `MCP Integration`

### Paso 5: Iniciar servicios

```bash
# En el servidor MCP
cd /opt/mcp-zabbix
npm run pm2:start

# Verificar estado
pm2 status
curl http://localhost:3001/health
```

## 🧪 Pruebas

### Diagnosticar conectividad

```bash
# Descargar script de diagnóstico
wget https://raw.githubusercontent.com/TU_USUARIO/mcp-zabbix/main/diagnostic.sh
nano diagnostic.sh  # Editar IPs
chmod +x diagnostic.sh

# Ejecutar en ambos servidores
./diagnostic.sh
```

### Probar integración

```bash
# Probar consulta a MCP
curl -X POST http://TU_IP_MCP_SERVER:3001/ask-zabbix \
  -H "Authorization: Bearer TU_MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "¿cuántos hosts tengo en Zabbix?"}'

# Probar webhook desde Zabbix
/usr/lib/zabbix/alertscripts/mcp_webhook.py test123 4 "Test message" test-host 85.5
```

## 📖 Uso

### Consultas disponibles

| Consulta | Descripción |
|----------|-------------|
| "¿cuántos hosts tengo?" | Cuenta total de hosts monitoreados |
| "lista de hosts" | Lista todos los hosts con su estado |
| "problemas activos" | Muestra alertas actuales |
| "versión de Zabbix" | Información del servidor |

### Ejemplo de uso con curl

```bash
curl -X POST http://TU_IP_MCP_SERVER:3001/ask-zabbix \
  -H "Authorization: Bearer TU_MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "¿Cuáles son los problemas más críticos en mi infraestructura?"
  }'
```

### Respuesta esperada

```json
{
  "answer": "Actualmente tienes 3 hosts monitoreados en Zabbix. Los hosts activos son: servidor-web-01, base-datos-02 y servidor-app-03. Todo parece estar funcionando correctamente sin problemas críticos."
}
```

## 🔧 Configuración Avanzada

### Variables de entorno (.env)

```bash
# Zabbix
ZABBIX_URL=http://tu-zabbix.com/zabbix/api_jsonrpc.php
ZABBIX_API_TOKEN=tu_token_aqui
ZABBIX_SERVER_IP=192.168.1.200

# Gemini AI
GEMINI_API_KEY=tu_clave_gemini

# MCP Server
NODE_ENV=production
PORT=3001
MCP_AUTH_TOKEN=token_seguro_aqui
LOG_LEVEL=info

# Seguridad
JWT_SECRET=clave_jwt_secreta
ALLOWED_IPS=192.168.1.100,192.168.1.200,127.0.0.1

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### Comandos PM2 útiles

```bash
# Gestión del servicio
npm run pm2:start     # Iniciar
npm run pm2:stop      # Detener
npm run pm2:restart   # Reiniciar
npm run pm2:logs      # Ver logs

# Comandos PM2 directos
pm2 status            # Estado de procesos
pm2 monit            # Monitor en tiempo real
pm2 logs mcp-zabbix  # Logs específicos
```

## 🔍 Solución de Problemas

### Problemas comunes

#### Error: "Cannot connect to MCP server"
```bash
# Verificar que el servicio esté corriendo
pm2 status

# Verificar logs
pm2 logs mcp-zabbix

# Verificar puertos
netstat -tulpn | grep 3001
```

#### Error: "Zabbix API token invalid"
```bash
# Verificar token en .env
grep ZABBIX_API_TOKEN /opt/mcp-zabbix/.env

# Probar token manualmente
curl -X POST http://TU_ZABBIX_SERVER/zabbix/api_jsonrpc.php \
  -H "Content-Type: application/json-rpc" \
  -d '{
    "jsonrpc": "2.0",
    "method": "apiinfo.version",
    "auth": "TU_TOKEN_AQUI",
    "id": 1
  }'
```

#### Error: "Permission denied" en webhook
```bash
# Verificar permisos del script
ls -la /usr/lib/zabbix/alertscripts/mcp_webhook.py

# Corregir permisos si es necesario
chmod +x /usr/lib/zabbix/alertscripts/mcp_webhook.py
chown zabbix:zabbix /usr/lib/zabbix/alertscripts/mcp_webhook.py
```

#### Firewall bloqueando conexiones
```bash
# En servidor MCP - verificar reglas
sudo firewall-cmd --list-all

# En servidor Zabbix - verificar UFW
sudo ufw status

# Abrir puertos manualmente si es necesario
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='TU_IP_ZABBIX' port protocol='tcp' port='3001' accept"
sudo firewall-cmd --reload
```

### Logs útiles

```bash
# Logs del servidor MCP
tail -f /opt/mcp-zabbix/logs/combined.log
tail -f /opt/mcp-zabbix/logs/error.log

# Logs de PM2
pm2 logs mcp-zabbix --lines 100

# Logs de Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Logs de Zabbix
tail -f /var/log/zabbix/zabbix_server.log
```

## 📁 Estructura de Archivos

```
/opt/mcp-zabbix/
├── server.js              # Servidor web principal
├── mcp-server.js          # Servidor MCP para Claude
├── package.json           # Dependencias Node.js
├── ecosystem.config.js    # Configuración PM2
├── .env                   # Variables de entorno
├── logs/                  # Directorio de logs
│   ├── combined.log
│   ├── error.log
│   ├── out.log
│   └── err.log
└── src/                   # Código fuente organizado
    ├── config/
    ├── lib/
    ├── routes/
    ├── middleware/
    └── utils/

/usr/lib/zabbix/alertscripts/
└── mcp_webhook.py         # Script webhook para Zabbix
```

## 🔒 Seguridad

### Recomendaciones de seguridad

1. **Tokens seguros:**
   - Usa tokens largos y complejos
   - Rota los tokens periódicamente
   - No hardcodees tokens en el código

2. **Firewall:**
   - Restringe acceso solo a IPs necesarias
   - Usa VPN para acceso remoto
   - Monitor logs de acceso

3. **SSL/TLS:**
   ```bash
   # Configurar HTTPS en Nginx (recomendado)
   sudo certbot --nginx -d tu-mcp-server.com
   ```

4. **Actualizaciones:**
   ```bash
   # Mantener dependencias actualizadas
   cd /opt/mcp-zabbix
   npm audit
   npm update
   ```

## 🚀 Características Avanzadas

### Integración con Claude MCP

El servidor incluye un servidor MCP compatible con Claude para consultas avanzadas:

```bash
# Configurar en Claude Desktop
# Agregar a ~/.config/claude-desktop/claude_desktop_config.json:
{
  "mcpServers": {
    "zabbix": {
      "command": "node",
      "args": ["/opt/mcp-zabbix/mcp-server.js"],
      "env": {
        "ZABBIX_URL": "http://tu-zabbix.com/zabbix/api_jsonrpc.php",
        "ZABBIX_API_TOKEN": "tu_token_aqui"
      }
    }
  }
}
```

### Métricas y Monitoreo

El servidor expone métricas en formato Prometheus:

```bash
# Endpoint de métricas
curl http://TU_IP_MCP_SERVER:3001/metrics
```

### Rate Limiting

Protección automática contra spam y ataques:

- 100 requests por 15 minutos por IP
- Configurable en archivo .env
- Logging automático de intentos bloqueados

## 📞 Soporte

- 📧 **Email:** soporte@ccaceresoln.com

## 🔄 Changelog

### v1.0.0 (2025-01-21)
- ✅ Integración inicial MCP-Zabbix
- ✅ Servidor web con Express
- ✅ Cliente de API Zabbix con autenticación por token
- ✅ Integración con Gemini AI
- ✅ Scripts de instalación para RHEL/CentOS
- ✅ Webhook de alertas desde Zabbix
- ✅ Configuración de firewall y seguridad
- ✅ Documentación completa

---

**¡Gracias por usar MCP-Zabbix Integration! 🚀**
