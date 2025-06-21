#!/bin/bash

# Configuración robusta
RESULTS_DIR=~/lab5_results
OPTIM_DIR="$RESULTS_DIR/optimizacion"
mkdir -p "$OPTIM_DIR"

# Servicios a deshabilitar con validación de estado
declare -A SERVICES=(
    ["bluetooth"]=1
    ["cups"]=1
    ["avahi-daemon"]=1
    ["ModemManager"]=1
    ["fwupd"]=1
    ["whoopsie"]=1
    ["apport"]=1
)

# 1. Medición inicial mejorada
echo "===== MEDICIÓN PRE-OPTIMIZACIÓN [$(date)] =====" > "$OPTIM_DIR/optimizacion.log"
{
    echo "---- Tiempo de arranque ----"
    systemd-analyze
    echo -e "\n---- Uso de recursos ----"
    free -m
    echo -e "\n---- Servicios activos ----"
    systemctl list-units --type=service --state=running | head -n 5
} >> "$OPTIM_DIR/optimizacion.log"

# 2. Deshabilitar servicios con verificación
echo -e "\n===== OPTIMIZACIÓN DE SERVICIOS =====" >> "$OPTIM_DIR/optimizacion.log"
for service in "${!SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo " - Deshabilitando $service (activo)"
        sudo systemctl stop "$service"
        sudo systemctl disable "$service" >> "$OPTIM_DIR/optimizacion.log" 2>&1
    else
        echo " - $service ya está inactivo (omitiendo)"
    fi
done

# 3. Optimización GRUB con respaldo
echo -e "\n===== OPTIMIZACIÓN DE GRUB =====" >> "$OPTIM_DIR/optimizacion.log"
if [ -f /etc/default/grub ]; then
    sudo cp /etc/default/grub /etc/default/grub.bak
    sudo sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    echo " - Archivo GRUB modificado"
    sudo update-grub >> "$OPTIM_DIR/optimizacion.log" 2>&1
    echo " - GRUB actualizado (tiempo reducido a 3s)"
else
    echo " - Advertencia: /etc/default/grub no encontrado"
fi

# 4. Optimización de memoria
echo -e "\n===== OPTIMIZACIÓN DE MEMORIA =====" >> "$OPTIM_DIR/optimizacion.log"
sudo sysctl vm.drop_caches=3 >> "$OPTIM_DIR/optimizacion.log" 2>&1
echo " - Cachés liberadas"

# 5. Configuración visual (solo si hay GUI)
echo -e "\n===== OPTIMIZACIÓN DE INTERFAZ =====" >> "$OPTIM_DIR/optimizacion.log"
if [ -n "$DISPLAY" ]; then
    gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null
    echo " - Animaciones desactivadas"
else
    echo " - Sin entorno gráfico (omitiendo animaciones)"
fi

# 6. Medición final
echo -e "\n===== MEDICIÓN POST-OPTIMIZACIÓN [$(date)] =====" >> "$OPTIM_DIR/optimizacion.log"
{
    echo "---- Tiempo de arranque ----"
    systemd-analyze
    echo -e "\n---- Uso de recursos ----"
    free -m
    echo -e "\n---- Servicios activos ----"
    systemctl list-units --type=service --state=running | head -n 5
} >> "$OPTIM_DIR/optimizacion.log"

# 7. Generar reporte comparativo
echo "Generando reporte comparativo..."
{
    echo "Metrica,Antes,Después,Diferencia"
    
    # Tiempo de arranque
    BOOT_PRE=$(grep "Startup" "$OPTIM_DIR/optimizacion.log" | head -n 1 | awk '{print $NF}' | tr -d 's)')
    BOOT_POST=$(grep "Startup" "$OPTIM_DIR/optimizacion.log" | tail -n 1 | awk '{print $NF}' | tr -d 's)')
    BOOT_DIFF=$(echo "$BOOT_PRE - $BOOT_POST" | bc)
    echo "Tiempo arranque,$BOOT_PRE s,$BOOT_POST s,-$BOOT_DIFF s"
    
    # RAM libre
    RAM_PRE=$(grep "Mem:" "$OPTIM_DIR/optimizacion.log" | head -n 1 | awk '{print $7}')
    RAM_POST=$(grep "Mem:" "$OPTIM_DIR/optimizacion.log" | tail -n 1 | awk '{print $7}')
    RAM_DIFF=$((RAM_POST - RAM_PRE))
    echo "RAM libre,$RAM_PRE MB,$RAM_POST MB,+$RAM_DIFF MB"
    
    # Servicios activos
    SERVICES_PRE=$(grep "services" "$OPTIM_DIR/optimizacion.log" -A 1 | head -n 2 | tail -n 1 | wc -w)
    SERVICES_POST=$(grep "services" "$OPTIM_DIR/optimizacion.log" -A 1 | tail -n 1 | wc -w)
    SERVICES_DIFF=$((SERVICES_PRE - SERVICES_POST))
    echo "Servicios activos,$SERVICES_PRE,$SERVICES_POST,-$SERVICES_DIFF"
} > "$OPTIM_DIR/comparativa.csv"

# 8. Resumen ejecutivo
echo "===== RESUMEN DE OPTIMIZACIÓN =====" > "$OPTIM_DIR/resumen.txt"
echo "Servicios deshabilitados: ${#SERVICES[@]}" >> "$OPTIM_DIR/resumen.txt"
echo "Mejora tiempo arranque: -$BOOT_DIFF segundos" >> "$OPTIM_DIR/resumen.txt"
echo "RAM adicional libre: +$RAM_DIFF MB" >> "$OPTIM_DIR/resumen.txt"
echo "Servicios reducidos: -$SERVICES_DIFF" >> "$OPTIM_DIR/resumen.txt"
echo "Fecha de optimización: $(date)" >> "$OPTIM_DIR/resumen.txt"

echo "¡Optimización completada exitosamente!"
echo "Resultados guardados en: $OPTIM_DIR"
