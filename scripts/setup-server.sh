#!/bin/bash
#
# Maya Website - Server Setup Script
# Installs all dependencies and configures the environment
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/scripts/setup-server.sh | bash
#   or
#   ./scripts/setup-server.sh
#
# Supports: Ubuntu/Debian, CentOS/RHEL/Fedora, Amazon Linux
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root or with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            log_error "This script requires root privileges. Please run as root or install sudo."
            exit 1
        fi
    else
        SUDO=""
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        log_error "Unsupported operating system"
        exit 1
    fi
    log_info "Detected OS: $OS $VERSION"
}

# Install Docker on Debian/Ubuntu
install_docker_debian() {
    log_info "Installing Docker on Debian/Ubuntu..."
    
    # Remove old versions
    $SUDO apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update and install prerequisites
    $SUDO apt-get update
    $SUDO apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git \
        openssl
    
    # Add Docker's official GPG key
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    $SUDO apt-get update
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Install Docker on CentOS/RHEL/Fedora
install_docker_rhel() {
    log_info "Installing Docker on CentOS/RHEL/Fedora..."
    
    # Remove old versions
    $SUDO yum remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # Install prerequisites
    $SUDO yum install -y yum-utils git openssl
    
    # Add Docker repository
    $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    $SUDO yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    $SUDO systemctl start docker
    $SUDO systemctl enable docker
}

# Install Docker on Amazon Linux
install_docker_amazon() {
    log_info "Installing Docker on Amazon Linux..."
    
    # Install Docker
    $SUDO yum update -y
    $SUDO yum install -y docker git openssl
    
    # Start and enable Docker
    $SUDO systemctl start docker
    $SUDO systemctl enable docker
    
    # Install Docker Compose plugin
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    $SUDO mkdir -p /usr/local/lib/docker/cli-plugins
    $SUDO curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    $SUDO chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
}

# Install Docker based on OS
install_docker() {
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed: $(docker --version)"
        
        # Check if Docker Compose plugin is available
        if docker compose version &> /dev/null; then
            log_info "Docker Compose is available: $(docker compose version)"
            return 0
        fi
    fi
    
    case $OS in
        ubuntu|debian)
            install_docker_debian
            ;;
        centos|rhel|rocky|almalinux)
            install_docker_rhel
            ;;
        fedora)
            install_docker_rhel
            ;;
        amzn)
            install_docker_amazon
            ;;
        *)
            log_warning "Unknown OS, trying generic Docker installation..."
            curl -fsSL https://get.docker.com | $SUDO sh
            ;;
    esac
    
    log_success "Docker installed successfully"
}

# Configure Docker for current user
configure_docker_user() {
    log_info "Configuring Docker for user: $USER"
    
    # Add user to docker group
    if ! groups $USER | grep -q docker; then
        $SUDO usermod -aG docker $USER
        log_success "Added $USER to docker group"
        log_warning "You may need to log out and back in for group changes to take effect"
        log_warning "Or run: newgrp docker"
    else
        log_info "User $USER is already in docker group"
    fi
    
    # Start and enable Docker service
    $SUDO systemctl start docker 2>/dev/null || true
    $SUDO systemctl enable docker 2>/dev/null || true
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        $SUDO ufw allow 80/tcp || true
        $SUDO ufw allow 443/tcp || true
        log_success "UFW configured for ports 80 and 443"
    fi
    
    # Firewalld (CentOS/RHEL/Fedora)
    if command -v firewall-cmd &> /dev/null; then
        $SUDO firewall-cmd --permanent --add-service=http || true
        $SUDO firewall-cmd --permanent --add-service=https || true
        $SUDO firewall-cmd --reload || true
        log_success "Firewalld configured for HTTP and HTTPS"
    fi
}

# Setup project directory
setup_project() {
    local PROJECT_DIR="${1:-/var/www/maya-website}"
    
    log_info "Setting up project directory: $PROJECT_DIR"
    
    # Create directory if it doesn't exist
    if [ ! -d "$PROJECT_DIR" ]; then
        $SUDO mkdir -p "$PROJECT_DIR"
        $SUDO chown $USER:$USER "$PROJECT_DIR"
    fi
    
    # Check if we're already in a project directory
    if [ -f "./docker-compose.yml" ]; then
        log_info "Project files found in current directory"
        PROJECT_DIR="$(pwd)"
    fi
    
    echo "$PROJECT_DIR"
}

# Generate secure credentials
generate_credentials() {
    log_info "Generating secure credentials..."
    
    local ENV_FILE="${1:-.env}"
    
    if [ -f "$ENV_FILE" ]; then
        log_warning ".env file already exists, skipping credential generation"
        return 0
    fi
    
    # Generate secure random strings
    local DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
    local SESSION_SECRET=$(openssl rand -base64 48)
    
    cat > "$ENV_FILE" << EOF
# Database Configuration
POSTGRES_USER=maya_user
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=maya_website

# Application Configuration
NODE_ENV=production
PORT=3000

# Session Secret
SESSION_SECRET=$SESSION_SECRET

# Domain Configuration
# UPDATE THESE WITH YOUR ACTUAL DOMAIN!
DOMAIN_URL=https://localhost
FRONTEND_URL=https://localhost
EOF
    
    chmod 600 "$ENV_FILE"
    log_success "Generated .env file with secure credentials"
    log_warning "Remember to update DOMAIN_URL and FRONTEND_URL with your actual domain!"
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Setup Complete!${NC}"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. If you just added your user to the docker group, run:"
    echo "   ${YELLOW}newgrp docker${NC}"
    echo ""
    echo "2. Navigate to the project directory:"
    echo "   ${YELLOW}cd /var/www/maya-website${NC}"
    echo ""
    echo "3. Clone the repository (if not already done):"
    echo "   ${YELLOW}git clone <your-repo-url> .${NC}"
    echo ""
    echo "4. Update .env with your domain:"
    echo "   ${YELLOW}nano .env${NC}"
    echo ""
    echo "5. For local testing with self-signed SSL:"
    echo "   ${YELLOW}./scripts/generate-self-signed.sh${NC}"
    echo "   ${YELLOW}docker compose up -d${NC}"
    echo ""
    echo "6. For production with Let's Encrypt SSL:"
    echo "   ${YELLOW}./scripts/init-ssl.sh yourdomain.com your@email.com${NC}"
    echo ""
    echo "Your site will be available at:"
    echo "   ${GREEN}https://yourdomain.com${NC}"
    echo ""
    echo "Admin panel:"
    echo "   ${GREEN}https://yourdomain.com/admin${NC}"
    echo "   Default credentials: admin / admin"
    echo "   ${RED}(Change this immediately!)${NC}"
    echo ""
}

# Main function
main() {
    echo ""
    echo "=============================================="
    echo "  Maya Website - Server Setup Script"
    echo "=============================================="
    echo ""
    
    check_sudo
    detect_os
    install_docker
    configure_docker_user
    configure_firewall
    
    # Setup project directory
    PROJECT_DIR=$(setup_project)
    
    # Generate credentials if .env doesn't exist
    if [ -f "./docker-compose.yml" ]; then
        generate_credentials ".env"
    fi
    
    print_summary
}

# Run main function
main "$@"
