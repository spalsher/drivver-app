#!/bin/bash

# Drivrr Microservices Management Script
# Usage: ./manage-services.sh [start|stop|restart|status]

OTP_SERVICE_DIR="/home/iteck/Dev_Projects/drivrr2/backend"
WEBSOCKET_SERVICE_DIR="/home/iteck/Dev_Projects/drivrr2/go-backend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}🚀 Drivrr Microservices Manager${NC}"
    echo "=================================="
}

check_service_status() {
    local service_name=$1
    local port=$2
    
    if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
        local pid=$(netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1)
        echo -e "${GREEN}✅ $service_name${NC} - Running (PID: $pid, Port: $port)"
        return 0
    else
        echo -e "${RED}❌ $service_name${NC} - Stopped (Port: $port)"
        return 1
    fi
}

start_otp_service() {
    echo -e "${YELLOW}🔐 Starting OTP Authentication Service...${NC}"
    cd "$OTP_SERVICE_DIR"
    nohup npm start > otp-service.log 2>&1 &
    sleep 3
    if check_service_status "OTP Service" "3000"; then
        echo -e "${GREEN}✅ OTP Service started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start OTP Service${NC}"
        echo "Check log: tail -f $OTP_SERVICE_DIR/otp-service.log"
    fi
}

start_websocket_service() {
    echo -e "${YELLOW}📡 Starting WebSocket Real-time Service...${NC}"
    cd "$WEBSOCKET_SERVICE_DIR"
    nohup go run . > websocket-service.log 2>&1 &
    sleep 3
    if check_service_status "WebSocket Service" "8081"; then
        echo -e "${GREEN}✅ WebSocket Service started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start WebSocket Service${NC}"
        echo "Check log: tail -f $WEBSOCKET_SERVICE_DIR/websocket-service.log"
    fi
}

stop_otp_service() {
    echo -e "${YELLOW}🛑 Stopping OTP Authentication Service...${NC}"
    pkill -f "node src/server.js" || echo "No OTP service process found"
    sleep 1
    if ! check_service_status "OTP Service" "3000" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OTP Service stopped${NC}"
    fi
}

stop_websocket_service() {
    echo -e "${YELLOW}🛑 Stopping WebSocket Real-time Service...${NC}"
    pkill -f "go run" || echo "No Go service process found"
    pkill -f "drivrr-backend" || echo "No compiled Go binary found"
    sleep 1
    if ! check_service_status "WebSocket Service" "8081" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ WebSocket Service stopped${NC}"
    fi
}

show_status() {
    print_header
    echo -e "${BLUE}📊 Service Status:${NC}"
    echo ""
    check_service_status "OTP Authentication Service" "3000"
    check_service_status "WebSocket Real-time Service" "8081"
    echo ""
    echo -e "${BLUE}📋 Service Details:${NC}"
    echo "• OTP Service: Handles phone verification, user auth, profile management"
    echo "• WebSocket Service: Handles real-time ride requests, driver matching"
    echo ""
    echo -e "${BLUE}🔗 Endpoints:${NC}"
    echo "• OTP API: http://localhost:3000/api"
    echo "• WebSocket: ws://localhost:8081/ws"
}

start_all() {
    print_header
    echo -e "${BLUE}🚀 Starting all microservices...${NC}"
    echo ""
    
    # Stop any existing services first
    stop_otp_service > /dev/null 2>&1
    stop_websocket_service > /dev/null 2>&1
    sleep 2
    
    start_otp_service
    echo ""
    start_websocket_service
    echo ""
    show_status
}

stop_all() {
    print_header
    echo -e "${BLUE}🛑 Stopping all microservices...${NC}"
    echo ""
    stop_otp_service
    stop_websocket_service
    echo ""
    show_status
}

restart_all() {
    print_header
    echo -e "${BLUE}🔄 Restarting all microservices...${NC}"
    echo ""
    stop_all > /dev/null 2>&1
    sleep 3
    start_all
}

# Main script logic
case "$1" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        restart_all
        ;;
    status)
        show_status
        ;;
    *)
        print_header
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start both microservices"
        echo "  stop    - Stop both microservices"  
        echo "  restart - Restart both microservices"
        echo "  status  - Show current status"
        echo ""
        show_status
        ;;
esac
