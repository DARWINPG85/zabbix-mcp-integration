#!/bin/bash
# mcp-install-rhel.sh - Script modificado para sistemas RHEL (CentOS, Rocky, AlmaLinux)
# Ejecutar en servidor MCP

set -e

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Configuración - EDITAR SEGÚN TU ENTORNO ---
ZABBIX_URL="http://20.50.0.10/zabbix/api_jsonrpc.php"  # Cambiar por tu dominio/IP de Zabbix
ZABBIX_SERVER_IP="20.50.0.10"  # Cambiar por la IP del servidor Zabbix
MCP_SERVER_IP="20.50.0.100"        # Cambiar por la IP del servidor MCP
INSTALL_DIR="/opt/mcp-zabbix"

# --- Funciones de Logging ---
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# --- Verificaciones Iniciales ---
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Este script NO debe ejecutarse como root. Usa un usuario con permisos de sudo (en el grupo 'wheel')."
    fi
}

check_config() {
    if [[ "$ZABBIX_SERVER_IP" == "TU_IP_ZABBIX_SERVER" ]] || [[ "$MCP_SERVER_IP" == "TU_IP_MCP_SERVER" ]]; then
        error "CONFIGURACIÓN REQUERIDA: Edita las variables al inicio del script con las IPs correctas de tu entorno."
    fi
}

# --- Banner de Inicio ---
echo -e "${BLUE}"
cat << "EOF"
    ┌┬┐┌─┐┌─┐   ┌─┐┌─┐┬─┐┬  ┬┌─┐┬─┐
    │││├─┤├─┘───└─┐├┤ ├┬┘└┐┌┘├┤ ├┬┘
    ┴ ┴┴ ┴┴     └─┘└─┘┴└─ └┘ └─┘┴└─
         MCP SERVER INSTALLER (RHEL/CentOS Version)
EOF
echo -e "${NC}"

echo "🚀 Instalando/Actualizando MCP Server"
echo "🔧 Zabbix Server: $ZABBIX_SERVER_IP"
echo "📍 MCP Server: $MCP_SERVER_IP"
echo "=================================================="

check_root
check_config

log "✅ Confirmado: Este es el servidor MCP"

# 1. Instalar dependencias del sistema con DNF
log "📦 Habilitando el repositorio EPEL (Extra Packages for Enterprise Linux)..."
sudo dnf install -y epel-release
sudo dnf makecache  # Actualizar información de los repositorios 

# Limpiar caché de dnf para evitar datos obsoletos
log "🧹 Limpiando el caché de DNF..."
sudo dnf clean all

log "📦 Instalando dependencias del sistema con DNF..."
sudo dnf install -y epel-release
sudo dnf install -y \
    curl \
    git \
    nginx \
    redis \
    postgresql \
    python3 \
    python3-pip \
    jq \
    htop \
    net-tools

log "🔨 Instalando 'Development Tools' (equivalente a build-essential)..."
sudo dnf groupinstall -y "Development Tools"

# 2. Instalar Node.js 18 usando DNF modules
log "🟢 Instalando Node.js 18..."
sudo dnf module install -y nodejs:18

# Verificar instalación
node --version || error "Error instalando Node.js"
npm --version || error "Error instalando npm"

# Instalar PM2 globalmente
log "🔄 Instalando PM2 globalmente..."
sudo npm install -g pm2

log "✅ Node.js y PM2 instalados"

# 3. Crear estructura de directorios
log "📁 Creando estructura de directorios..."
sudo mkdir -p $INSTALL_DIR
sudo chown $USER:$USER $INSTALL_DIR

mkdir -p $INSTALL_DIR/{src/{config,lib,routes,middleware,utils},scripts,docker,logs,tests}

log "✅ Estructura de directorios creada"

# 4. Crear package.json
log "📝 Creando package.json..."
cat > $INSTALL_DIR/package.json << 'EOF'
{
  "name": "mcp-zabbix-integration",
  "version": "1.0.0",
  "description": "MCP Server integration with Zabbix monitoring",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest",
    "pm2:start": "pm2 start ecosystem.config.js",
    "pm2:stop": "pm2 stop mcp-zabbix",
    "pm2:restart": "pm2 restart mcp-zabbix",
    "pm2:logs": "pm2 logs mcp-zabbix"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "@google/generative-ai": "^0.2.1",
    "redis": "^4.6.0",
    "winston": "^3.10.0",
    "joi": "^17.11.0",
    "express-rate-limit": "^7.1.0",
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "prom-client": "^15.0.0",
    "compression": "^1.7.4",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# 5. Crear archivo .env (si no existe)
if [ ! -f "$INSTALL_DIR/.env" ]; then
    log "🔐 Creando archivo .env..."
    cat > $INSTALL_DIR/.env << EOF
# Configuración de Zabbix
ZABBIX_URL=$ZABBIX_URL
ZABBIX_SERVER_IP=$ZABBIX_SERVER_IP
# --- NUEVO: Usa un token de API en lugar de usuario/contraseña ---
ZABBIX_API_TOKEN=b6d89dcc0f08f33d14dd3f63235a3fa7866cb601cea19911ecb76de04d35abf

# Configuración de Gemini AI
GEMINI_API_KEY=AIzaSyCAi8ntLzka9HHAgQ2dke_1j4wqUeD80WI

# Configuración del servidor MCP
NODE_ENV=production
PORT=3001
MCP_AUTH_TOKEN=a8093d0f104f03f657849cb2ebcf415384199db40d7c47a874646e8f7833c8
LOG_LEVEL=info

# Configuración de Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Configuración de seguridad
JWT_SECRET=YOUR_JWT_SECRET_HERE
ENCRYPTION_KEY=12345678901234567890123456789012

# Configuración de red
MCP_SERVER_IP=$MCP_SERVER_IP
ALLOWED_IPS=$MCP_SERVER_IP,$ZABBIX_SERVER_IP,127.0.0.1

# Rate limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
EOF
    log "✅ Archivo .env creado. ¡No olvides editarlo!"
else
    log "ℹ️ Archivo .env existente no fue modificado."
fi

# 6. Crear servidor MCP principal
log "⚙️ Creando servidor MCP principal..."
cat > $INSTALL_DIR/mcp-server.js << 'EOF'
#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const axios = require('axios');

// Configurar Zabbix API
const ZABBIX_URL = process.env.ZABBIX_URL || 'http://localhost/zabbix/api_jsonrpc.php';
const ZABBIX_TOKEN = process.env.ZABBIX_API_TOKEN || '';

class ZabbixMCPServer {
    constructor() {
        this.server = new Server(
            {
                name: 'zabbix-mcp-server',
                version: '1.0.0',
            },
            {
                capabilities: {
                    tools: {},
                },
            }
        );
        
        this.setupToolHandlers();
        this.setupErrorHandling();
    }

    async callZabbixAPI(method, params = {}) {
        try {
            const publicMethods = ['apiinfo.version'];
            const isPublicMethod = publicMethods.includes(method);
            
            const requestData = {
                jsonrpc: '2.0',
                method,
                params: params,
                id: Date.now(),
            };
            
            const requestConfig = {
                headers: {
                    'Content-Type': 'application/json-rpc'
                }
            };
            
            if (!isPublicMethod) {
                requestConfig.headers['Authorization'] = `Bearer ${ZABBIX_TOKEN}`;
            }
            
            const response = await axios.post(ZABBIX_URL, requestData, requestConfig);
            
            if (response.data.error) {
                throw new Error(`Zabbix API Error: ${response.data.error.data || response.data.error.message}`);
            }
            
            return response.data.result;
        } catch (error) {
            throw new Error(`Failed to call Zabbix API: ${error.message}`);
        }
    }

    setupToolHandlers() {
        // Listar herramientas disponibles
        this.server.setRequestHandler(ListToolsRequestSchema, async () => {
            return {
                tools: [
                    {
                        name: 'get_host_count',
                        description: 'Get the total number of monitored hosts in Zabbix',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'list_hosts',
                        description: 'List all monitored hosts in Zabbix with their status',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                limit: {
                                    type: 'number',
                                    description: 'Maximum number of hosts to return (default: 20)',
                                    default: 20
                                }
                            },
                        },
                    },
                    {
                        name: 'get_zabbix_version',
                        description: 'Get the Zabbix server version',
                        inputSchema: {
                            type: 'object',
                            properties: {},
                        },
                    },
                    {
                        name: 'get_active_problems',
                        description: 'Get active problems/alerts in Zabbix',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                limit: {
                                    type: 'number',
                                    description: 'Maximum number of problems to return (default: 10)',
                                    default: 10
                                }
                            },
                        },
                    },
                    {
                        name: 'search_hosts',
                        description: 'Search hosts by name or pattern',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                search: {
                                    type: 'string',
                                    description: 'Search pattern for host names'
                                }
                            },
                            required: ['search']
                        },
                    }
                ],
            };
        });

        // Manejar llamadas a herramientas
        this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
            const { name, arguments: args } = request.params;

            try {
                switch (name) {
                    case 'get_host_count':
                        const hostCount = await this.callZabbixAPI('host.get', { countOutput: true });
                        return {
                            content: [
                                {
                                    type: 'text',
                                    text: `Total de hosts monitoreados en Zabbix: ${hostCount}`
                                }
                            ]
                        };

                    case 'list_hosts':
                        const limit = args?.limit || 20;
                        const hosts = await this.callZabbixAPI('host.get', {
                            output: ['host', 'name', 'status'],
                            limit: limit
                        });
                        
                        const hostList = hosts.map((h, index) => {
                            const status = h.status === "0" ? "🟢 Activo" : "🔴 Inactivo";
                            return `${index + 1}. ${h.name || h.host} - ${status}`;
                        }).join('\n');
                        
                        return {
                            content: [
                                {
                                    type: 'text',
                                    text: `Lista de hosts monitoreados (${hosts.length} de ${limit} máximo):\n\n${hostList}`
                                }
                            ]
                        };

                    case 'get_zabbix_version':
                        const version = await this.callZabbixAPI('apiinfo.version', {});
                        return {
                            content: [
                                {
                                    type: 'text',
                                    text: `Versión de Zabbix: ${version}`
                                }
                            ]
                        };

                    case 'get_active_problems':
                        const limit_problems = args?.limit || 10;
                        try {
                            const problems = await this.callZabbixAPI('problem.get', {
                                output: 'extend',
                                recent: true,
                                limit: limit_problems
                            });
                            
                            if (problems.length === 0) {
                                return {
                                    content: [
                                        {
                                            type: 'text',
                                            text: '✅ No hay problemas activos en Zabbix en este momento.'
                                        }
                                    ]
                                };
                            } else {
                                const problemList = problems.map((p, index) => {
                                    const severity = ['', 'ℹ️ Info', '⚠️ Warning', '🟡 Average', '🟠 High', '🔴 Disaster'][p.severity] || '❓ Unknown';
                                    return `${index + 1}. ${severity} ${p.name}`;
                                }).join('\n');
                                
                                return {
                                    content: [
                                        {
                                            type: 'text',
                                            text: `Problemas activos en Zabbix (${problems.length}):\n\n${problemList}`
                                        }
                                    ]
                                };
                            }
                        } catch (error) {
                            return {
                                content: [
                                    {
                                        type: 'text',
                                        text: `⚠️ No se pudieron consultar los problemas: ${error.message}`
                                    }
                                ]
                            };
                        }

                    case 'search_hosts':
                        const searchPattern = args?.search;
                        if (!searchPattern) {
                            throw new Error('Search pattern is required');
                        }
                        
                        const searchResults = await this.callZabbixAPI('host.get', {
                            output: ['host', 'name', 'status'],
                            search: { name: searchPattern },
                            searchWildcardsEnabled: true
                        });
                        
                        if (searchResults.length === 0) {
                            return {
                                content: [
                                    {
                                        type: 'text',
                                        text: `No se encontraron hosts que coincidan con "${searchPattern}"`
                                    }
                                ]
                            };
                        }
                        
                        const searchList = searchResults.map((h, index) => {
                            const status = h.status === "0" ? "🟢 Activo" : "🔴 Inactivo";
                            return `${index + 1}. ${h.name || h.host} - ${status}`;
                        }).join('\n');
                        
                        return {
                            content: [
                                {
                                    type: 'text',
                                    text: `Hosts encontrados con "${searchPattern}" (${searchResults.length}):\n\n${searchList}`
                                }
                            ]
                        };

                    default:
                        throw new Error(`Unknown tool: ${name}`);
                }
            } catch (error) {
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Error: ${error.message}`
                        }
                    ],
                    isError: true
                };
            }
        });
    }

    setupErrorHandling() {
        this.server.onerror = (error) => {
            console.error('[MCP Error]', error);
        };

        process.on('SIGINT', async () => {
            await this.server.close();
            process.exit(0);
        });
    }

    async run() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
        console.error('🚀 Zabbix MCP Server running via stdio');
    }
}

// Ejecutar el servidor
if (require.main === module) {
    const server = new ZabbixMCPServer();
    server.run().catch(console.error);
}

module.exports = ZabbixMCPServer;
EOF

# 7. Crear servidor web con inteligencia Zabbix
log "🤖 Creando servidor web con inteligencia Zabbix..."
cat > $INSTALL_DIR/server.js << 'EOF'
require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const axios = require('axios');
const winston = require('winston');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// --- Basic Setup ---
const app = express();
const PORT = process.env.PORT || 3001;

// --- Logger Setup ---
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
    transports: [
        new winston.transports.File({ filename: './logs/error.log', level: 'error' }),
        new winston.transports.File({ filename: './logs/combined.log' }),
        new winston.transports.Console({ format: winston.format.simple() })
    ]
});

// --- Zabbix API Client (Token Auth) ---
class ZabbixClient {
    constructor() {
        this.apiUrl = process.env.ZABBIX_URL;
        this.token = process.env.ZABBIX_API_TOKEN;
    }

    async call(method, params = {}) {
        if (!this.token || this.token === 'b6d89dcc0f08f33d14dd3f63235a3fa7866cb601cea19911ecb76de04d35abf') {
            const errorMessage = 'Zabbix API token is not configured in .env file (ZABBIX_API_TOKEN).';
            logger.error(errorMessage);
            throw new Error(errorMessage);
        }
        try {
            const response = await axios.post(this.apiUrl, {
                jsonrpc: '2.0',
                method,
                params,
                auth: this.token,
                id: Date.now(),
            });
            if (response.data.error) {
                 logger.error(`Zabbix API Error: ${JSON.stringify(response.data.error)}`);
                 throw new Error(`Zabbix API Error: ${response.data.error.data}`);
            }
            return response.data.result;
        } catch (error) {
            logger.error(`Zabbix API call to '${method}' failed: ${error.message}`);
            throw error;
        }
    }
}
const zabbix = new ZabbixClient();

// --- Gemini AI Client ---
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

// --- Express Middleware ---
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '10mb' }));

function authMiddleware(req, res, next) {
    const token = req.headers.authorization?.replace('Bearer ', '');
    const expectedToken = process.env.MCP_AUTH_TOKEN;
    if (!expectedToken || token !== expectedToken) {
        logger.warn('Unauthorized access attempt:', { ip: req.ip, path: req.path });
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
}

// --- API Routes ---
app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

app.post('/alerts', authMiddleware, (req, res) => {
    logger.info('Alert received from Zabbix:', req.body);
    res.json({ status: 'success', message: 'Alert received' });
});

app.post('/ask-zabbix', authMiddleware, async (req, res) => {
    const { prompt } = req.body;
    if (!prompt) return res.status(400).json({ error: 'Prompt is required' });

    const normalizedPrompt = prompt.toLowerCase().replace(/[¿?¡!.,]/g, '');
    logger.info(`Received Zabbix query: "${prompt}" (Normalized: "${normalizedPrompt}")`);

    try {
        let zabbixData;
        let geminiSystemPrompt;

        if (normalizedPrompt.includes('cuantos host')) {
            zabbixData = await zabbix.call('host.get', { countOutput: true });
            geminiSystemPrompt = `El usuario preguntó cuántos hosts hay. Zabbix informa que hay ${zabbixData} hosts. Responde amigablemente al usuario en español, indicando este número. La pregunta original fue: "${prompt}"`;
        } else if (normalizedPrompt.includes('lista de host')) {
            zabbixData = await zabbix.call('host.get', { output: ['host'] });
            const hostNames = zabbixData.map(h => h.host).join(', ');
            geminiSystemPrompt = `El usuario pidió una lista de hosts. Zabbix informa que los hosts son: ${hostNames}. Responde amigablemente al usuario en español, presentando esta lista. La pregunta original fue: "${prompt}"`;
        } else {
             geminiSystemPrompt = `El usuario preguntó "${prompt}", pero no sé cómo consultar esa información en Zabbix todavía. Responde amigablemente en español que por ahora solo puedo contar hosts y listar sus nombres, pero que estoy aprendiendo.`;
        }
        
        const result = await model.generateContent(geminiSystemPrompt);
        const responseText = await result.response.text();
        res.json({ answer: responseText });

    } catch (error) {
        logger.error('Error in /ask-zabbix:', { message: error.message, stack: error.stack });
        res.status(500).json({ error: 'Failed to process your request.', details: error.message });
    }
});

// --- Server Start ---
app.listen(PORT, '0.0.0.0', () => {
    logger.info(`🚀 MCP-Zabbix Server running on port ${PORT}`);
});
EOF

# ecosystem.config.js para PM2
cat > $INSTALL_DIR/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'mcp-zabbix',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: { NODE_ENV: 'production', PORT: 3001 },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '512M'
  }]
};
EOF
log "✅ Archivos principales creados"

# 8. Instalar dependencias Node.js
log "📦 Instalando dependencias Node.js..."
cd $INSTALL_DIR
npm install --production

log "✅ Dependencias de Node.js instaladas"

# 9. Configurar servicios del sistema
log "⚙️ Configurando servicios (Redis y Nginx)..."
sudo systemctl enable --now redis
sudo systemctl enable --now nginx

# Configurar Nginx para RHEL/CentOS
log "🌐 Creando configuración de Nginx..."
sudo tee /etc/nginx/conf.d/mcp-zabbix.conf << EOF
server {
    listen 80;
    server_name $MCP_SERVER_IP;
    
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

log "✅ Configuración de Nginx creada. Recargando Nginx..."
sudo nginx -t && sudo systemctl reload nginx

# 10. Configurar firewall con firewalld
log "🔥 Configurando firewall con firewalld..."
sudo systemctl enable --now firewalld

# Permitir SSH, HTTP, HTTPS
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# Permitir puerto MCP (3001) desde Zabbix y localhost
log "🔥 Creando reglas de firewall para el puerto 3001..."
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ZABBIX_SERVER_IP' port protocol='tcp' port='3001' accept"
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='127.0.0.1' port protocol='tcp' port='3001' accept"

# Permitir Redis (6379) solo desde localhost
log "🔥 Creando regla de firewall para Redis..."
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='127.0.0.1' port protocol='tcp' port='6379' accept"

# Recargar firewall para aplicar cambios
log "🔥 Recargando firewall..."
sudo firewall-cmd --reload

log "✅ Firewall configurado"

# 11. Verificar servicios
log "🔍 Verificando estado de los servicios..."
if systemctl is-active --quiet redis; then log "✅ Redis está activo"; else warning "⚠️ Redis no está activo"; fi
if systemctl is-active --quiet nginx; then log "✅ Nginx está activo"; else warning "⚠️ Nginx no está activo"; fi
if systemctl is-active --quiet firewalld; then log "✅ Firewalld está activo"; else warning "⚠️ Firewalld no está activo"; fi

# --- NUEVA SECCIÓN DE DIAGNÓSTICO ---
echo ""
echo "=================================================="
echo "🔍 EJECUTANDO PRUEBA DE CONEXIÓN A LA API DE ZABBIX..."
echo "=================================================="
log "Verificando el token de API de Zabbix desde el archivo .env..."

# Extraer credenciales del .env
ZABBIX_API_URL=$(grep ZABBIX_URL $INSTALL_DIR/.env | cut -d '=' -f2)
ZABBIX_API_TOKEN=$(grep ZABBIX_API_TOKEN $INSTALL_DIR/.env | cut -d '=' -f2)

if [ "$ZABBIX_API_TOKEN" == "b6d89dcc0f08f33d14dd3f63235a3fa7866cb601cea19911ecb76de04d35abfX" ]; then
    error "El token de API de Zabbix no ha sido configurado en el archivo .env"
    error "   SOLUCIÓN: Edita el archivo 'nano $INSTALL_DIR/.env' y pega tu token en la variable ZABBIX_API_TOKEN."
    exit 1
fi

# Ejecutar prueba con curl
API_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json-rpc" \
-d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"apiinfo.version\",
    \"params\": {},
    \"id\": 1
}" $ZABBIX_API_URL)

# Analizar respuesta
if echo "$API_RESPONSE" | jq -e '.result' > /dev/null; then
    ZABBIX_VERSION=$(echo "$API_RESPONSE" | jq -r '.result')
    log "✅ ¡ÉXITO! El token de API de Zabbix es válido y la conexión con Zabbix v$ZABBIX_VERSION funcionó."
    warning "   Si las preguntas aún fallan, reinicia el servicio con 'npm run pm2:restart'"
else
    ERROR_MESSAGE=$(echo "$API_RESPONSE" | jq -r '.error.data')
    error "¡FALLO LA CONEXIÓN A LA API DE ZABBIX CON EL TOKEN!"
    error "   Razón: $ERROR_MESSAGE"
    error "   SOLUCIÓN: Ve a la interfaz web de Zabbix (Administration -> General -> API tokens), y asegúrate de que tu token esté activo y tenga los permisos correctos."
fi

# --- Instrucciones Finales ---
echo ""
echo "=================================================="
echo "🎉 INSTALACIÓN/ACTUALIZACIÓN MCP SERVER COMPLETADA"
echo "=================================================="
echo ""
echo "🚀 PASOS SIGUIENTES:"
echo ""
echo "1. 📝 Edita tu archivo de configuración si es necesario:"
echo "   nano $INSTALL_DIR/.env"
echo "   (¡Asegúrate de que ZABBIX_API_TOKEN sea el correcto!)"
echo ""
echo "2. 🔄 Iniciar/Reiniciar el servidor MCP con PM2:"
echo "   cd $INSTALL_DIR"
echo "   npm run pm2:restart"
echo ""
echo "3. ✅ Verificar que el servidor funciona:"
echo "   pm2 status"
echo "   curl http://127.0.0.1:3001/health"
echo ""
echo "4. 💬 Para hablar con tu nuevo servidor MCP, usa un comando curl:"
echo "   curl -X POST http://$MCP_SERVER_IP/ask-zabbix \\"
echo "        -H \"Authorization: Bearer TU_MCP_TOKEN\" \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{\"prompt\": \"cuantos host tengo en zabbix?\"}'"
echo ""
echo "=================================================="

log "🎯 Script de instalación para RHEL/CentOS finalizado."
