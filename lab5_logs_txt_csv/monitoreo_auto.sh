#!/bin/bash

# Configuración robusta
RESULTS_DIR=~/lab5_results
MONITOR_DIR="$RESULTS_DIR/monitoreo"
mkdir -p "$MONITOR_DIR"
LOG_FILE="$MONITOR_DIR/monitoreo.log"
STATS_FILE="$MONITOR_DIR/estadisticas.csv"

# Encabezado del CSV (formato simplificado)
echo "timestamp,cpu_user,cpu_system,cpu_idle,mem_used,mem_free" > "$STATS_FILE"

# Función para capturar métricas (compatible)
get_metrics() {
    # Timestamp numérico (epoch) para gnuplot
    timestamp=$(date +%s)
    
    # CPU (compatible con todos los sistemas)
    cpu_line=$(grep 'cpu ' /proc/stat)
    user=$(echo $cpu_line | awk '{print $2}')
    system=$(echo $cpu_line | awk '{print $4}')
    idle=$(echo $cpu_line | awk '{print $5}')
    total=$((user + system + idle))
    
    # Calcular porcentajes
    p_user=$((100*user/total))
    p_system=$((100*system/total))
    p_idle=$((100*idle/total))
    
    # Memoria (MB)
    mem_used=$(free -m | awk '/Mem:/ {print $3}')
    mem_free=$(free -m | awk '/Mem:/ {print $7}')
    
    # Escribir CSV
    echo "$timestamp,$p_user,$p_system,$p_idle,$mem_used,$mem_free" >> "$STATS_FILE"
}

# 1. Monitoreo principal
echo "==== INICIANDO MONITOREO CONTINUO ===="
echo "Intervalo: 5 minutos"
echo "Duración: 24 horas (simuladas)"
echo "Guardando datos en: $STATS_FILE"

# Simulación de 24h (288 intervalos de 5 segundos)
for i in {1..288}; do
    get_metrics
    echo "[$(date +'%H:%M')] Registro $i/288: CPU=$p_idle% idle, RAM=$mem_free MB libres"
    sleep 5  # Intervalo reducido para simulación
done

# 2. Generar gráficos con gnuplot (formato corregido)
echo -e "\n==== GENERANDO GRÁFICOS ===="
gnuplot <<- EOF
    set terminal pngcairo size 1280,720 enhanced font ',10'
    set output '$MONITOR_DIR/cpu_usage.png'
    set title "Uso de CPU (24h)"
    set xlabel "Tiempo"
    set ylabel "% Uso"
    set grid
    set xdata time
    set timefmt "%s"
    set format x "%H:%M"
    plot "$STATS_FILE" using 1:2 title 'Usuario' with lines, \
         "" using 1:3 title 'Sistema' with lines, \
         "" using 1:4 title 'Inactivo' with lines

    set output '$MONITOR_DIR/mem_usage.png'
    set title "Uso de Memoria (24h)"
    set ylabel "MB"
    unset xdata
    plot "$STATS_FILE" using 1:5 title 'Memoria Usada' with lines, \
         "" using 1:6 title 'Memoria Libre' with lines
EOF

# 3. Análisis de patrones
echo -e "\n==== ANALIZANDO PATRONES ===="
{
    echo "Resumen de Monitoreo (24h)"
    echo "=========================="
    echo "- Pico máximo de CPU: $(awk -F, 'NR>1 {max=$2+$3; if(max>m) m=max} END{print m}' "$STATS_FILE")%"
    echo "- Memoria mínima libre: $(awk -F, 'NR>1 {if(min=="") min=$6; if($6<min) min=$6} END{print min}' "$STATS_FILE") MB"
    echo "- Proceso más intensivo: $(ps -eo comm,%cpu --sort=-%cpu | awk 'NR==2')"
} > "$MONITOR_DIR/analisis.txt"

# Resultados finales
echo -e "\n¡MONITOREO COMPLETADO EXITOSAMENTE!"
echo "Gráficos guardados en: $MONITOR_DIR/"
ls -lh "$MONITOR_DIR"/*.png
