#!/bin/bash

# FluxBeam UI Integration Script
# Version: 1.2.0
# This script sets up the FluxBeam subscription UI in your project

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="fluxbeam-ui"
UI_FRAMEWORK="react"  # Options: react, next, vite

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  FluxBeam UI Integration v1.2.0${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    print_success "Node.js $(node --version) found"
    
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm first."
        exit 1
    fi
    print_success "npm $(npm --version) found"
    
    echo ""
}

select_framework() {
    print_info "Select your UI framework:"
    echo "1) React (Create React App)"
    echo "2) Next.js"
    echo "3) Vite + React"
    echo "4) Existing React project"
    read -p "Enter choice [1-4]: " framework_choice
    
    case $framework_choice in
        1) UI_FRAMEWORK="react" ;;
        2) UI_FRAMEWORK="next" ;;
        3) UI_FRAMEWORK="vite" ;;
        4) UI_FRAMEWORK="existing" ;;
        *) print_error "Invalid choice. Exiting."; exit 1 ;;
    esac
    
    echo ""
}

create_project() {
    if [ "$UI_FRAMEWORK" = "existing" ]; then
        print_info "Using existing project..."
        return
    fi
    
    print_info "Creating new $UI_FRAMEWORK project..."
    
    case $UI_FRAMEWORK in
        "react")
            npx create-react-app $PROJECT_NAME
            cd $PROJECT_NAME
            ;;
        "next")
            npx create-next-app@latest $PROJECT_NAME --typescript --tailwind --app --no-src-dir
            cd $PROJECT_NAME
            ;;
        "vite")
            npm create vite@latest $PROJECT_NAME -- --template react-ts
            cd $PROJECT_NAME
            npm install
            ;;
    esac
    
    print_success "Project created successfully"
    echo ""
}

install_dependencies() {
    print_info "Installing required dependencies..."
    
    # Core dependencies
    npm install lucide-react
    print_success "Installed lucide-react"
    
    # Stacks.js dependencies for blockchain integration
    npm install @stacks/connect @stacks/transactions @stacks/network
    print_success "Installed Stacks.js libraries"
    
    # Tailwind CSS (if not already installed)
    if [ "$UI_FRAMEWORK" = "react" ] || [ "$UI_FRAMEWORK" = "existing" ]; then
        print_info "Installing Tailwind CSS..."
        npm install -D tailwindcss postcss autoprefixer
        npx tailwindcss init -p
        print_success "Installed Tailwind CSS"
    fi
    
    echo ""
}

create_directory_structure() {
    print_info "Creating directory structure..."
    
    # Create directories based on framework
    if [ "$UI_FRAMEWORK" = "next" ]; then
        mkdir -p app/subscriptions
        mkdir -p components/fluxbeam
        mkdir -p lib/stacks
        mkdir -p types
    else
        mkdir -p src/components/fluxbeam
        mkdir -p src/lib/stacks
        mkdir -p src/types
        mkdir -p src/pages
    fi
    
    print_success "Directory structure created"
    echo ""
}

create_subscription_manager() {
    print_info "Creating SubscriptionManager component..."
    
    local component_path
    if [ "$UI_FRAMEWORK" = "next" ]; then
        component_path="components/fluxbeam/SubscriptionManager.tsx"
    else
        component_path="src/components/fluxbeam/SubscriptionManager.tsx"
    fi
    
    cat > "$component_path" << 'EOF'
import React, { useState } from 'react';
import { Calendar, CreditCard, Zap, Check, X, RefreshCw, AlertCircle, TrendingUp, Users, Clock } from 'lucide-react';

export default function SubscriptionManager() {
  const [activeTab, setActiveTab] = useState('browse');
  const [selectedTier, setSelectedTier] = useState(null);
  const [autoRenew, setAutoRenew] = useState(true);

  // Mock data - Replace with actual blockchain data
  const [services] = useState([
    {
      id: 1,
      name: 'CloudAPI Pro',
      provider: 'SP2X...',
      description: 'Professional API access with advanced features',
      status: 'active'
    }
  ]);

  const [tiers] = useState([
    {
      id: 1,
      serviceId: 1,
      serviceName: 'CloudAPI Pro',
      name: 'Basic',
      price: 1000000,
      durationBlocks: 4320,
      durationDays: 30,
      features: ['100 API calls/day', 'Email support', 'Basic analytics'],
      status: 'active',
      popular: false
    },
    {
      id: 2,
      serviceId: 1,
      serviceName: 'CloudAPI Pro',
      name: 'Professional',
      price: 5000000,
      durationBlocks: 4320,
      durationDays: 30,
      features: ['1,000 API calls/day', 'Priority support', 'Advanced analytics'],
      status: 'active',
      popular: true
    }
  ]);

  const [balance] = useState(25000000);

  const formatSTX = (microSTX) => {
    return (microSTX / 1000000).toFixed(2);
  };

  const handleSubscribe = (tier) => {
    setSelectedTier(tier);
    console.log(`Subscribing to ${tier.name} with auto-renew: ${autoRenew}`);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-12 h-12 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
              <Zap className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">FluxBeam Subscriptions</h1>
              <p className="text-gray-600">Manage your recurring service payments</p>
            </div>
          </div>
          
          {/* Balance Card */}
          <div className="mt-4 bg-gradient-to-r from-indigo-600 to-purple-600 rounded-xl p-6 text-white shadow-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-indigo-100 text-sm mb-1">Available Balance</p>
                <p className="text-4xl font-bold">{formatSTX(balance)} STX</p>
              </div>
              <CreditCard className="w-12 h-12 text-indigo-200" />
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 mb-6 bg-white rounded-lg p-1 shadow-sm">
          <button
            onClick={() => setActiveTab('browse')}
            className={`flex-1 py-3 px-4 rounded-lg font-medium transition-all ${
              activeTab === 'browse'
                ? 'bg-indigo-600 text-white shadow-md'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            Browse Plans
          </button>
          <button
            onClick={() => setActiveTab('my-subscriptions')}
            className={`flex-1 py-3 px-4 rounded-lg font-medium transition-all ${
              activeTab === 'my-subscriptions'
                ? 'bg-indigo-600 text-white shadow-md'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            My Subscriptions
          </button>
        </div>

        {/* Browse Plans Tab */}
        {activeTab === 'browse' && (
          <div className="space-y-8">
            {services.map(service => {
              const serviceTiers = tiers.filter(t => t.serviceId === service.id);
              
              return (
                <div key={service.id} className="bg-white rounded-xl shadow-sm p-6">
                  <div className="mb-6">
                    <h2 className="text-2xl font-bold text-gray-900 mb-2">{service.name}</h2>
                    <p className="text-gray-600">{service.description}</p>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {serviceTiers.map(tier => (
                      <div
                        key={tier.id}
                        className={`relative border-2 rounded-xl p-6 transition-all hover:shadow-lg ${
                          tier.popular
                            ? 'border-indigo-600 shadow-md'
                            : 'border-gray-200 hover:border-indigo-300'
                        }`}
                      >
                        {tier.popular && (
                          <div className="absolute -top-3 left-1/2 -translate-x-1/2 bg-gradient-to-r from-indigo-600 to-purple-600 text-white px-4 py-1 rounded-full text-xs font-semibold">
                            MOST POPULAR
                          </div>
                        )}

                        <div className="mb-4">
                          <h3 className="text-xl font-bold text-gray-900 mb-2">{tier.name}</h3>
                          <div className="flex items-baseline gap-1">
                            <span className="text-3xl font-bold text-gray-900">
                              {formatSTX(tier.price)}
                            </span>
                            <span className="text-gray-600">STX</span>
                          </div>
                          <p className="text-sm text-gray-500 mt-1">per {tier.durationDays} days</p>
                        </div>

                        <ul className="space-y-3 mb-6">
                          {tier.features.map((feature, idx) => (
                            <li key={idx} className="flex items-start gap-2">
                              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                              <span className="text-sm text-gray-700">{feature}</span>
                            </li>
                          ))}
                        </ul>

                        <button
                          onClick={() => handleSubscribe(tier)}
                          className={`w-full py-3 px-4 rounded-lg font-semibold transition-all ${
                            tier.popular
                              ? 'bg-gradient-to-r from-indigo-600 to-purple-600 text-white hover:from-indigo-700 hover:to-purple-700 shadow-md'
                              : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
                          }`}
                        >
                          Subscribe Now
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* My Subscriptions Tab */}
        {activeTab === 'my-subscriptions' && (
          <div className="bg-white rounded-xl shadow-sm p-12 text-center">
            <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-2">No Active Subscriptions</h3>
            <p className="text-gray-600 mb-6">Browse available plans to get started</p>
            <button
              onClick={() => setActiveTab('browse')}
              className="bg-indigo-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-indigo-700 transition-all"
            >
              Browse Plans
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
EOF
    
    print_success "SubscriptionManager component created"
    echo ""
}

create_stacks_integration() {
    print_info "Creating Stacks blockchain integration..."
    
    local lib_path
    if [ "$UI_FRAMEWORK" = "next" ]; then
        lib_path="lib/stacks"
    else
        lib_path="src/lib/stacks"
    fi
    
    # Create contract interface
    cat > "$lib_path/fluxbeam-contract.ts" << 'EOF'
import {
  uintCV,
  stringUtf8CV,
  boolCV,
  PostConditionMode,
  FungibleConditionCode,
  makeStandardSTXPostCondition,
} from '@stacks/transactions';
import { openContractCall } from '@stacks/connect';
import { StacksTestnet, StacksMainnet } from '@stacks/network';

// Configuration
const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const CONTRACT_NAME = 'fluxbeam';
const NETWORK = process.env.NEXT_PUBLIC_NETWORK === 'mainnet' ? new StacksMainnet() : new StacksTestnet();

export interface SubscriptionTier {
  id: number;
  serviceId: number;
  name: string;
  price: number;
  durationBlocks: number;
  features: string;
  status: string;
}

export interface Subscription {
  id: number;
  tierId: number;
  userId: string;
  startBlock: number;
  endBlock: number;
  autoRenew: boolean;
  status: string;
}

// Create subscription tier
export const createSubscriptionTier = async (
  serviceId: number,
  tierName: string,
  price: number,
  durationBlocks: number,
  features: string
) => {
  return await openContractCall({
    network: NETWORK,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'create-subscription-tier',
    functionArgs: [
      uintCV(serviceId),
      stringUtf8CV(tierName),
      uintCV(price),
      uintCV(durationBlocks),
      stringUtf8CV(features),
    ],
    postConditionMode: PostConditionMode.Deny,
    onFinish: (data) => {
      console.log('Tier created:', data);
      return data;
    },
  });
};

// Subscribe to a tier
export const subscribe = async (
  tierId: number,
  autoRenew: boolean,
  userAddress: string,
  price: number
) => {
  const postConditions = [
    makeStandardSTXPostCondition(
      userAddress,
      FungibleConditionCode.LessEqual,
      price
    ),
  ];

  return await openContractCall({
    network: NETWORK,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'subscribe',
    functionArgs: [
      uintCV(tierId),
      boolCV(autoRenew),
    ],
    postConditions,
    postConditionMode: PostConditionMode.Deny,
    onFinish: (data) => {
      console.log('Subscribed:', data);
      return data;
    },
  });
};

// Renew subscription
export const renewSubscription = async (
  subscriptionId: number,
  userAddress: string,
  price: number
) => {
  const postConditions = [
    makeStandardSTXPostCondition(
      userAddress,
      FungibleConditionCode.LessEqual,
      price
    ),
  ];

  return await openContractCall({
    network: NETWORK,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'renew-subscription',
    functionArgs: [uintCV(subscriptionId)],
    postConditions,
    postConditionMode: PostConditionMode.Deny,
    onFinish: (data) => {
      console.log('Subscription renewed:', data);
      return data;
    },
  });
};

// Cancel subscription
export const cancelSubscription = async (subscriptionId: number) => {
  return await openContractCall({
    network: NETWORK,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'cancel-subscription',
    functionArgs: [uintCV(subscriptionId)],
    postConditionMode: PostConditionMode.Allow,
    onFinish: (data) => {
      console.log('Subscription cancelled:', data);
      return data;
    },
  });
};

// Toggle auto-renewal
export const toggleAutoRenew = async (subscriptionId: number) => {
  return await openContractCall({
    network: NETWORK,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'toggle-auto-renew',
    functionArgs: [uintCV(subscriptionId)],
    postConditionMode: PostConditionMode.Allow,
    onFinish: (data) => {
      console.log('Auto-renew toggled:', data);
      return data;
    },
  });
};

// Deposit funds
export const depositFunds = async (amount: number, userAddress: string) => {
  const postConditions = [
    makeStandardSTXPostCondition(
      userAddress,
      FungibleConditionCode.Equal,
      amount
    ),
  ];

  return await openContractCall({
    network: NETWORK,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'deposit-funds',
    functionArgs: [uintCV(amount)],
    postConditions,
    postConditionMode: PostConditionMode.Deny,
    onFinish: (data) => {
      console.log('Funds deposited:', data);
      return data;
    },
  });
};
EOF
    
    print_success "Stacks integration created"
    echo ""
}

create_env_file() {
    print_info "Creating environment configuration..."
    
    cat > ".env.local" << 'EOF'
# FluxBeam Configuration
NEXT_PUBLIC_CONTRACT_ADDRESS=ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
NEXT_PUBLIC_CONTRACT_NAME=fluxbeam
NEXT_PUBLIC_NETWORK=testnet

# API Configuration (Optional)
NEXT_PUBLIC_API_URL=http://localhost:3000/api
EOF
    
    print_success "Environment file created (.env.local)"
    print_warning "Don't forget to update CONTRACT_ADDRESS after deployment!"
    echo ""
}

configure_tailwind() {
    if [ "$UI_FRAMEWORK" = "react" ] || [ "$UI_FRAMEWORK" = "existing" ]; then
        print_info "Configuring Tailwind CSS..."
        
        cat > "tailwind.config.js" << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF
        
        mkdir -p src
        cat > "src/index.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF
        
        print_success "Tailwind CSS configured"
        echo ""
    fi
}

create_example_page() {
    print_info "Creating example page..."
    
    if [ "$UI_FRAMEWORK" = "next" ]; then
        cat > "app/subscriptions/page.tsx" << 'EOF'
import SubscriptionManager from '@/components/fluxbeam/SubscriptionManager';

export default function SubscriptionsPage() {
  return <SubscriptionManager />;
}
EOF
        print_success "Created app/subscriptions/page.tsx"
    else
        cat > "src/pages/Subscriptions.tsx" << 'EOF'
import SubscriptionManager from '../components/fluxbeam/SubscriptionManager';

export default function SubscriptionsPage() {
  return <SubscriptionManager />;
}
EOF
        
        # Update App.tsx
        if [ -f "src/App.tsx" ]; then
            print_info "Updating App.tsx..."
            cat > "src/App.tsx" << 'EOF'
import React from 'react';
import SubscriptionManager from './components/fluxbeam/SubscriptionManager';
import './index.css';

function App() {
  return (
    <div className="App">
      <SubscriptionManager />
    </div>
  );
}

export default App;
EOF
            print_success "Updated App.tsx"
        fi
    fi
    
    echo ""
}

create_readme() {
    print_info "Creating integration README..."
    
    cat > "FLUXBEAM_INTEGRATION.md" << 'EOF'
# FluxBeam UI Integration Guide

## Setup Complete! 🎉

Your FluxBeam subscription UI has been integrated successfully.

## Project Structure

```
├── components/fluxbeam/          # FluxBeam components
│   └── SubscriptionManager.tsx   # Main subscription UI
├── lib/stacks/                   # Blockchain integration
│   └── fluxbeam-contract.ts      # Smart contract interface
└── .env.local                    # Configuration
```

## Next Steps

### 1. Update Contract Address

After deploying your FluxBeam smart contract, update `.env.local`:

```bash
NEXT_PUBLIC_CONTRACT_ADDRESS=YOUR_DEPLOYED_CONTRACT_ADDRESS
```

### 2. Run Development Server

```bash
npm run dev
```

### 3. Connect Wallet

Users need to install and connect a Stacks wallet:
- Hiro Wallet (Recommended): https://wallet.hiro.so/

### 4. Test Subscriptions

1. Navigate to the subscriptions page
2. Browse available plans
3. Click "Subscribe Now"
4. Approve the transaction in your wallet

## Available Functions

### Create Subscription Tier (Service Providers)
```typescript
import { createSubscriptionTier } from './lib/stacks/fluxbeam-contract';

await createSubscriptionTier(
  1,              // serviceId
  'Premium',      // tierName
  5000000,        // price (5 STX in micro-STX)
  4320,           // durationBlocks (30 days)
  'Features...'   // features description
);
```

### Subscribe to Tier
```typescript
import { subscribe } from './lib/stacks/fluxbeam-contract';

await subscribe(
  1,              // tierId
  true,           // autoRenew
  userAddress,    // user's Stacks address
  5000000         // price
);
```

### Manage Subscriptions
```typescript
import { 
  renewSubscription, 
  cancelSubscription, 
  toggleAutoRenew 
} from './lib/stacks/fluxbeam-contract';

// Renew
await renewSubscription(subscriptionId, userAddress, price);

// Cancel
await cancelSubscription(subscriptionId);

// Toggle auto-renewal
await toggleAutoRenew(subscriptionId);
```

## Customization

### Styling
The UI uses Tailwind CSS. Customize in your component files or `tailwind.config.js`.

### Data Fetching
Replace mock data in `SubscriptionManager.tsx` with actual blockchain queries:

```typescript
import { callReadOnlyFunction } from '@stacks/transactions';

const getTier = async (tierId: number) => {
  const result = await callReadOnlyFunction({
    contractAddress: CONTRACT_ADDRESS,
    contractName: CONTRACT_NAME,
    functionName: 'get-tier',
    functionArgs: [uintCV(tierId)],
    network: NETWORK,
    senderAddress: userAddress,
  });
  
  return result;
};
```

## Troubleshooting

### Wallet Connection Issues
- Ensure Hiro Wallet extension is installed
- Check network settings (testnet vs mainnet)
- Clear browser cache and reconnect

### Transaction Failures
- Verify sufficient STX balance
- Check contract address is correct
- Ensure subscription tier is active

### Build Issues
- Clear node_modules and reinstall: `rm -rf node_modules && npm install`
- Check Node.js version: `node --version` (requires 16+)

## Resources

- FluxBeam Docs: [Link to docs]
- Stacks.js Docs: https://docs.stacks.co/
- Hiro Wallet: https://wallet.hiro.so/

## Support

For issues or questions:
- GitHub Issues: [Your repo link]
- Discord: [Your discord]
- Email: [Your email]
EOF
    
    print_success "Created FLUXBEAM_INTEGRATION.md"
    echo ""
}

print_completion_message() {
    echo ""
    print_header
    print_success "FluxBeam UI Integration Complete! 🎉"
    echo ""
    print_info "Next steps:"
    echo "  1. Update CONTRACT_ADDRESS in .env.local after deployment"
    echo "  2. Run 'npm run dev' to start development server"
    echo "  3. Open browser and test the subscription UI"
    echo "  4. Read FLUXBEAM_INTEGRATION.md for detailed guide"
    echo ""
    print_info "Quick start:"
    if [ "$UI_FRAMEWORK" = "existing" ]; then
        echo "  cd $(pwd)"
    else
        echo "  cd $PROJECT_NAME"
    fi
    echo "  npm run dev"
    echo ""
    print_success "Happy coding! 🚀"
    echo ""
}

# Main execution
main() {
    print_header
    
    # Check if script is run from correct location
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "FluxBeam UI Integration Script"
        echo ""
        echo "Usage: ./integrate-ui.sh"
        echo ""
        echo "This script will:"
        echo "  - Check dependencies (Node.js, npm)"
        echo "  - Create/setup your project"
        echo "  - Install required packages"
        echo "  - Create FluxBeam components"
        echo "  - Setup Stacks blockchain integration"
        echo "  - Configure Tailwind CSS"
        echo "  - Create example pages"
        echo ""
        exit 0
    fi
    
    # Run setup steps
    check_dependencies
    select_framework
    create_project
    install_dependencies
    create_directory_structure
    create_subscription_manager
    create_stacks_integration
    create_env_file
    configure_tailwind
    create_example_page
    create_readme
    print_completion_message
}

# Run main function
main "$@"
