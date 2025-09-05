#!/bin/bash

# SlightBuild Cost Monitoring Script Wrapper
# This script provides easy access to cost monitoring functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Node.js is installed
check_node() {
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js is not installed. Please install Node.js 14+ to run this script.${NC}"
        exit 1
    fi
    
    # Check Node.js version
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 14 ]; then
        echo -e "${RED}❌ Node.js version 14+ is required. Current version: $(node -v)${NC}"
        exit 1
    fi
}

# Install dependencies if needed
install_deps() {
    if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
        echo -e "${BLUE}📦 Installing dependencies...${NC}"
        cd "$SCRIPT_DIR"
        npm install --silent
        echo -e "${GREEN}✅ Dependencies installed${NC}"
    fi
}

# Check AWS CLI configuration
check_aws() {
    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}⚠️  AWS CLI is not installed. Some features may not work.${NC}"
        return 1
    fi
    
    # Check if AWS is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${YELLOW}⚠️  AWS CLI is not configured. Run 'aws configure' first.${NC}"
        return 1
    fi
    
    return 0
}

# Show help
show_help() {
    echo -e "${BLUE}SlightBuild Cost Monitoring Script${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  report     Generate detailed cost report"
    echo "  alert      Check budget alerts and thresholds" 
    echo "  optimize   Get cost optimization recommendations"
    echo "  all        Run all monitoring tasks (default)"
    echo "  setup      Install dependencies"
    echo "  help       Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION           AWS region (default: us-east-1)"
    echo "  APP_NAME            Application name (default: slightbuild)"
    echo "  COST_BUDGET_LIMIT   Monthly budget limit in USD (default: 10.0)"
    echo "  SNS_ALERT_TOPIC     SNS topic ARN for alerts (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 report                    # Generate cost report"
    echo "  APP_NAME=myapp $0 alert     # Check alerts for custom app"
    echo "  COST_BUDGET_LIMIT=25 $0 all # Set custom budget limit"
}

# Main execution
main() {
    local command=${1:-all}
    
    case $command in
        setup)
            check_node
            install_deps
            echo -e "${GREEN}✅ Setup complete${NC}"
            ;;
        report)
            check_node
            install_deps
            check_aws
            echo -e "${BLUE}📊 Generating cost report...${NC}"
            cd "$SCRIPT_DIR"
            node cost-monitor.js --report
            ;;
        alert)
            check_node
            install_deps
            check_aws
            echo -e "${YELLOW}🚨 Checking cost alerts...${NC}"
            cd "$SCRIPT_DIR"
            node cost-monitor.js --alert
            ;;
        optimize)
            check_node
            install_deps
            check_aws
            echo -e "${GREEN}⚡ Generating optimization recommendations...${NC}"
            cd "$SCRIPT_DIR"
            node cost-monitor.js --optimize
            ;;
        all)
            check_node
            install_deps
            check_aws
            echo -e "${BLUE}🔄 Running all monitoring tasks...${NC}"
            cd "$SCRIPT_DIR"
            node cost-monitor.js
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"