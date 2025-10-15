#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKEND_DIR="$SCRIPT_DIR"
VENV_DIR="$PROJECT_ROOT/.venv"
PID_FILE="$BACKEND_DIR/backend.pid"
LOG_FILE="$BACKEND_DIR/backend.log"
SERVICE_NAME="ai-hedge-fund-backend"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

check_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "Virtual environment not found at $VENV_DIR"
        echo "Please create a virtual environment first"
        exit 1
    fi
}

start_backend() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Backend is already running (PID: $PID)"
            exit 0
        else
            rm -f "$PID_FILE"
        fi
    fi

    check_venv
    
    echo "Starting backend server..."
    cd "$PROJECT_ROOT"
    
    nohup "$VENV_DIR/bin/uvicorn" app.backend.main:app \
        --host 0.0.0.0 \
        --port 8000 \
        --log-level info \
        > "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    echo "Backend started (PID: $(cat $PID_FILE))"
    echo "Log file: $LOG_FILE"
}

stop_backend() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Backend is not running (no PID file found)"
        exit 0
    fi

    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping backend (PID: $PID)..."
        kill "$PID"
        
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Force killing backend..."
            kill -9 "$PID"
        fi
        
        rm -f "$PID_FILE"
        echo "Backend stopped"
    else
        echo "Backend is not running (PID $PID not found)"
        rm -f "$PID_FILE"
    fi
}

restart_backend() {
    echo "Restarting backend..."
    stop_backend
    sleep 2
    start_backend
}

init_service() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run with sudo to initialize systemd service"
        exit 1
    fi

    if [ ! -d "$VENV_DIR" ]; then
        echo "Virtual environment not found at $VENV_DIR"
        echo "Please create a virtual environment first"
        exit 1
    fi

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=AI Hedge Fund Backend Service
After=network.target

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=$PROJECT_ROOT
Environment="PATH=$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$VENV_DIR/bin/uvicorn app.backend.main:app --host 0.0.0.0 --port 8000 --log-level info
Restart=always
RestartSec=10
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    echo "Systemd service installed successfully"
    echo "Service file: $SERVICE_FILE"
    echo ""
    echo "Available commands:"
    echo "  sudo systemctl start $SERVICE_NAME    - Start the service"
    echo "  sudo systemctl stop $SERVICE_NAME     - Stop the service"
    echo "  sudo systemctl restart $SERVICE_NAME  - Restart the service"
    echo "  sudo systemctl status $SERVICE_NAME   - Check service status"
    echo "  sudo systemctl disable $SERVICE_NAME  - Disable auto-start"
}

case "$1" in
    start)
        start_backend
        ;;
    stop)
        stop_backend
        ;;
    restart)
        restart_backend
        ;;
    initService)
        init_service
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|initService}"
        echo ""
        echo "Commands:"
        echo "  start       - Start backend in background"
        echo "  stop        - Stop backend"
        echo "  restart     - Restart backend"
        echo "  initService - Initialize systemd service (requires sudo)"
        exit 1
        ;;
esac

exit 0
