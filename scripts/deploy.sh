#!/bin/bash

# HealthMate Deployment Script
# This script handles the complete deployment process for testing and production

set -e  # Exit on any error

echo "🚀 HealthMate Deployment Script"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_status() {
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

# Check if Flutter is installed
check_flutter() {
    print_status "Checking Flutter installation..."
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    flutter --version
    print_success "Flutter is available"
}

# Check if Firebase CLI is installed
check_firebase() {
    print_status "Checking Firebase CLI..."
    if ! command -v firebase &> /dev/null; then
        print_error "Firebase CLI is not installed"
        echo "Install it with: npm install -g firebase-tools"
        exit 1
    fi
    firebase --version
    print_success "Firebase CLI is available"
}

# Run tests
run_tests() {
    print_status "Running test suite..."
    
    # Unit tests
    print_status "Running unit tests..."
    flutter test --reporter=compact
    
    if [ $? -eq 0 ]; then
        print_success "All unit tests passed"
    else
        print_error "Unit tests failed"
        exit 1
    fi
    
    # Widget tests
    print_status "Running widget tests..."
    flutter test test/widgets/ --reporter=compact
    
    if [ $? -eq 0 ]; then
        print_success "All widget tests passed"
    else
        print_error "Widget tests failed"
        exit 1
    fi
}

# Build app
build_app() {
    local build_type=$1
    print_status "Building app for $build_type..."
    
    flutter clean
    flutter pub get
    
    case $build_type in
        "debug")
            flutter build apk --debug
            ;;
        "release")
            flutter build apk --release
            flutter build appbundle --release
            ;;
        "ios")
            flutter build ios --release
            ;;
        *)
            print_error "Unknown build type: $build_type"
            exit 1
            ;;
    esac
    
    print_success "Build completed for $build_type"
}

# Deploy Firebase Functions
deploy_functions() {
    local environment=$1
    print_status "Deploying Firebase Functions to $environment..."
    
    cd functions
    
    # Install dependencies
    npm install
    
    # Run tests
    print_status "Running backend tests..."
    npm run test
    
    # Switch to appropriate Firebase project
    case $environment in
        "staging")
            firebase use staging
            ;;
        "production")
            firebase use production
            ;;
        *)
            print_error "Unknown environment: $environment"
            exit 1
            ;;
    esac
    
    # Deploy
    firebase deploy --only functions
    
    cd ..
    print_success "Functions deployed to $environment"
}

# Deploy Firestore rules
deploy_firestore_rules() {
    local environment=$1
    print_status "Deploying Firestore rules to $environment..."
    
    case $environment in
        "staging")
            firebase use staging
            ;;
        "production")
            firebase use production
            ;;
    esac
    
    firebase deploy --only firestore:rules
    print_success "Firestore rules deployed to $environment"
}

# Performance test
run_performance_tests() {
    print_status "Running performance tests..."
    cd functions
    npm run test:performance
    cd ..
    print_success "Performance tests completed"
}

# Integration tests
run_integration_tests() {
    print_status "Running integration tests..."
    flutter test integration_test/
    print_success "Integration tests completed"
}

# Generate coverage
generate_coverage() {
    print_status "Generating test coverage..."
    flutter test --coverage
    
    # Check if genhtml is available for HTML coverage report
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        print_success "Coverage report generated at coverage/html/index.html"
    else
        print_warning "genhtml not found. Install lcov for HTML coverage reports."
        print_success "Coverage data available at coverage/lcov.info"
    fi
}

# Main deployment function
deploy() {
    local environment=$1
    local build_type=$2
    
    print_status "Starting deployment to $environment environment..."
    
    # Checks
    check_flutter
    check_firebase
    
    # Tests
    run_tests
    
    # Build
    build_app $build_type
    
    # Deploy backend
    deploy_functions $environment
    deploy_firestore_rules $environment
    
    print_success "Deployment to $environment completed successfully!"
}

# Show help
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  test                   Run all tests"
    echo "  test-unit             Run unit tests only"
    echo "  test-widget           Run widget tests only"
    echo "  test-integration      Run integration tests"
    echo "  test-performance      Run performance tests"
    echo "  coverage              Generate test coverage report"
    echo "  build [debug|release|ios]  Build the app"
    echo "  deploy-staging        Deploy to staging environment"
    echo "  deploy-production     Deploy to production environment"
    echo "  deploy-functions [staging|production]  Deploy functions only"
    echo "  deploy-rules [staging|production]      Deploy Firestore rules only"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 test               # Run all tests"
    echo "  $0 build release      # Build release APK and bundle"
    echo "  $0 deploy-staging     # Full deployment to staging"
    echo "  $0 coverage           # Generate coverage report"
}

# Main script logic
case "${1:-help}" in
    "test")
        check_flutter
        run_tests
        ;;
    "test-unit")
        check_flutter
        flutter test --exclude-tags=widget,integration
        ;;
    "test-widget")
        check_flutter
        flutter test test/widgets/
        ;;
    "test-integration")
        check_flutter
        run_integration_tests
        ;;
    "test-performance")
        check_firebase
        run_performance_tests
        ;;
    "coverage")
        check_flutter
        generate_coverage
        ;;
    "build")
        check_flutter
        build_app ${2:-debug}
        ;;
    "deploy-staging")
        deploy "staging" "debug"
        ;;
    "deploy-production")
        deploy "production" "release"
        ;;
    "deploy-functions")
        check_firebase
        deploy_functions ${2:-staging}
        ;;
    "deploy-rules")
        check_firebase
        deploy_firestore_rules ${2:-staging}
        ;;
    "help"|*)
        show_help
        ;;
esac
