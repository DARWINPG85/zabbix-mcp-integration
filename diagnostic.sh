# diagnostic.sh - Ejecutar en ambos servidores
#!/bin/bash

echo "=== DIAGNÓSTICO MCP-ZABBIX ==="
echo "Fecha: $(date)"
echo "Servidor: $(hostname -I)"
echo ""

# Variables de configuración - EDITAR SEGÚN TU ENTORNO
MCP_SERVER_IP="20.50.0.100"    # Cambiar por la IP del servidor MCP
ZABBIX_SERVER_IP="20.50.0.10"  # Cambiar por la IP del servidor Zabbix

# Test básico de red
echo "1. Test de conectividad básica:"
ping -c 3 $MCP_SERVER_IP && echo "✅ Ping MCP Server OK" || echo "❌ Ping MCP Server FAIL"
ping -c 3 $ZABBIX_SERVER_IP && echo "✅ Ping Zabbix Server OK" || echo "❌ Ping Zabbix Server FAIL"

# Test de puertos
echo ""
echo "2. Test de puertos:"
nc -zv $MCP_SERVER_IP 3001 && echo "✅ Puerto 3001 MCP OK" || echo "❌ Puerto 3001 MCP FAIL"
nc -zv $ZABBIX_SERVER_IP 80 && echo "✅ Puerto 80 Zabbix OK" || echo "❌ Puerto 80 Zabbix FAIL"

# Test HTTP
echo ""
echo "3. Test HTTP:"
curl -s http://$MCP_SERVER_IP:3001/health >/dev/null && echo "✅ MCP Health OK" || echo "❌ MCP Health FAIL"
curl -s http://$ZABBIX_SERVER_IP/zabbix/api_jsonrpc.php >/dev/null && echo "✅ Zabbix API OK" || echo "❌ Zabbix API FAIL"

# Verificar servicios locales
echo ""
echo "4. Servicios locales:"
systemctl is-active nginx && echo "✅ Nginx activo" || echo "❌ Nginx inactivo"
systemctl is-active redis && echo "✅ Redis activo" || echo "❌ Redis inactivo"
systemctl is-active firewalld && echo "✅ Firewall activo" || echo "❌ Firewall inactivo"

echo ""
echo "=== FIN DIAGNÓSTICO ==="
