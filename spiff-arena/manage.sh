#!/bin/bash

# Script de gestión para spiff-arena con contenedores separados

set -e

COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "Script de gestión para spiff-arena con contenedores separados"
    echo ""
    echo "Uso: ./manage.sh [COMANDO]"
    echo ""
    echo "Comandos disponibles:"
    echo "  build       - Construir las imágenes Docker"
    echo "  start       - Iniciar todos los servicios"
    echo "  stop        - Detener todos los servicios"
    echo "  restart     - Reiniciar todos los servicios"
    echo "  logs        - Mostrar logs de todos los servicios"
    echo "  logs-api    - Mostrar logs del contenedor Frontend+API"
    echo "  logs-bg     - Mostrar logs del contenedor Background"
    echo "  logs-db     - Mostrar logs de PostgreSQL"
    echo "  status      - Mostrar estado de los contenedores"
    echo "  clean       - Limpiar contenedores y volúmenes"
    echo "  reset-db    - Resetear la base de datos (CUIDADO: borra todos los datos)"
    echo "  shell-api   - Abrir shell en contenedor Frontend+API"
    echo "  shell-bg    - Abrir shell en contenedor Background"
    echo "  shell-db    - Abrir shell en PostgreSQL"
    echo "  backup-db   - Hacer backup de la base de datos"
    echo "  restore-db  - Restaurar backup de la base de datos"
    echo "  help        - Mostrar esta ayuda"
}

check_requirements() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose no está instalado"
        exit 1
    fi

    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Archivo .env no encontrado, creando uno por defecto..."
        cp .env.example .env 2>/dev/null || true
    fi
}

build_images() {
    print_info "Construyendo imágenes Docker..."
    docker compose -f "$COMPOSE_FILE" build
    print_success "Imágenes construidas exitosamente"
}

start_services() {
    print_info "Iniciando servicios..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    print_info "Esperando a que los servicios estén listos..."
    sleep 10
    
    print_success "Servicios iniciados. Accede a:"
    echo "  - Frontend: http://localhost:${SPIFFWORKFLOW_FRONTEND_PORT:-8001}"
    echo "  - Backend API: http://localhost:${SPIFF_BACKEND_PORT:-8000}"
    echo "  - Connector: http://localhost:${SPIFF_CONNECTOR_PORT:-8004}"
}

stop_services() {
    print_info "Deteniendo servicios..."
    docker compose -f "$COMPOSE_FILE" down
    print_success "Servicios detenidos"
}

restart_services() {
    print_info "Reiniciando servicios..."
    stop_services
    start_services
}

show_logs() {
    docker compose -f "$COMPOSE_FILE" logs -f
}

show_logs_api() {
    docker compose -f "$COMPOSE_FILE" logs -f spiffworkflow-frontend-api
}

show_logs_bg() {
    docker compose -f "$COMPOSE_FILE" logs -f spiffworkflow-background
}

show_logs_db() {
    docker compose -f "$COMPOSE_FILE" logs -f postgres
}

show_status() {
    print_info "Estado de los contenedores:"
    docker compose -f "$COMPOSE_FILE" ps
}

clean_all() {
    print_warning "Esto eliminará todos los contenedores, redes e imágenes no utilizadas"
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Limpiando..."
        docker compose -f "$COMPOSE_FILE" down -v --rmi all
        docker system prune -f
        print_success "Limpieza completada"
    else
        print_info "Operación cancelada"
    fi
}

reset_database() {
    print_warning "Esto eliminará TODOS los datos de la base de datos"
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Reseteando base de datos..."
        docker compose -f "$COMPOSE_FILE" stop postgres
        docker volume rm spiffworkflow_postgres_data 2>/dev/null || true
        docker compose -f "$COMPOSE_FILE" up -d postgres
        print_success "Base de datos reseteada"
    else
        print_info "Operación cancelada"
    fi
}

shell_api() {
    docker compose -f "$COMPOSE_FILE" exec spiffworkflow-frontend-api /bin/bash
}

shell_bg() {
    docker compose -f "$COMPOSE_FILE" exec spiffworkflow-background /bin/bash
}

shell_db() {
    docker compose -f "$COMPOSE_FILE" exec postgres psql -U spiffworkflow -d spiffworkflow_backend
}

backup_database() {
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    print_info "Creando backup en: $BACKUP_FILE"
    docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U spiffworkflow spiffworkflow_backend > "$BACKUP_FILE"
    print_success "Backup creado: $BACKUP_FILE"
}

restore_database() {
    if [ -z "$1" ]; then
        print_error "Especifica el archivo de backup: ./manage.sh restore-db backup_file.sql"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        print_error "Archivo de backup no encontrado: $1"
        exit 1
    fi
    
    print_warning "Esto sobrescribirá la base de datos actual"
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restaurando desde: $1"
        cat "$1" | docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U spiffworkflow -d spiffworkflow_backend
        print_success "Base de datos restaurada"
    else
        print_info "Operación cancelada"
    fi
}

# Main script
check_requirements

case "${1:-help}" in
    "build")
        build_images
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "logs")
        show_logs
        ;;
    "logs-api")
        show_logs_api
        ;;
    "logs-bg")
        show_logs_bg
        ;;
    "logs-db")
        show_logs_db
        ;;
    "status")
        show_status
        ;;
    "clean")
        clean_all
        ;;
    "reset-db")
        reset_database
        ;;
    "shell-api")
        shell_api
        ;;
    "shell-bg")
        shell_bg
        ;;
    "shell-db")
        shell_db
        ;;
    "backup-db")
        backup_database
        ;;
    "restore-db")
        restore_database "$2"
        ;;
    "help")
        show_help
        ;;
    *)
        print_error "Comando no reconocido: $1"
        show_help
        exit 1
        ;;
esac