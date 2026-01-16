# Open Banking Brazil Integration

## Overview

This document outlines the requirements for integrating Brazilian Open Finance (Open Banking) into Maybe Finance, enabling automatic bank account synchronization for users in Brazil.

## Background

### Current State
- Maybe Finance uses **Plaid** for bank connections (US, Canada, Europe)
- Brazil is **not supported** by Plaid
- Brazilian users currently rely on CSV/PDF import or manual account tracking

### Brazil Open Finance
- Regulated by **Banco Central do Brasil (BCB)**
- Launched in phases starting 2021, now mature
- Covers: accounts, credit cards, loans, investments, insurance, pensions
- Supports **PIX** (instant payment system) data

## Recommended Approach

### Option 1: Pluggy (Recommended)
- **Website**: https://pluggy.ai
- **Why**: Brazilian company, Plaid-like API, good documentation
- **Coverage**: 30+ Brazilian banks including Itaú, Bradesco, Santander, BB, Caixa, Nubank, Inter
- **Pricing**: Per-connection model similar to Plaid

### Option 2: Belvo
- **Website**: https://belvo.com
- **Why**: LatAm focused, supports Brazil + Mexico + Colombia
- **Coverage**: Similar to Pluggy
- **Pricing**: Competitive with Pluggy

### Option 3: Direct BCB Integration
- **Why**: No intermediary fees
- **Complexity**: Very high - requires certification with each bank
- **Not recommended** for initial implementation

## Technical Requirements

### 1. Database Schema

```ruby
# New migration
class CreateBrazilOpenBankingConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :brazil_open_banking_connections, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :provider, null: false  # 'pluggy' or 'belvo'
      t.string :external_id, null: false
      t.string :institution_name
      t.string :institution_id
      t.string :status, default: 'active'
      t.datetime :last_synced_at
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :brazil_open_banking_connections, :external_id, unique: true
  end
end
```

### 2. Provider Implementation

```
app/models/provider/
├── pluggy.rb                 # Pluggy API client
├── belvo.rb                  # Belvo API client (optional)
└── brasil_open_banking.rb    # Common interface
```

#### Provider Interface

```ruby
module Provider
  class BrasilOpenBanking
    def create_connect_token(family)
      # Generate token for widget/link flow
    end

    def exchange_token(public_token)
      # Exchange public token for access credentials
    end

    def sync_accounts(connection)
      # Fetch and sync account data
    end

    def sync_transactions(connection, start_date:, end_date:)
      # Fetch and sync transactions
    end

    def delete_connection(connection)
      # Remove connection and revoke access
    end
  end
end
```

### 3. Environment Variables

```bash
# Pluggy
PLUGGY_CLIENT_ID=
PLUGGY_CLIENT_SECRET=
PLUGGY_WEBHOOK_URL=

# Belvo (if using)
BELVO_SECRET_ID=
BELVO_SECRET_PASSWORD=
BELVO_WEBHOOK_URL=
```

### 4. Controller & Routes

```ruby
# config/routes.rb
resources :brazil_open_banking_connections, only: [:create, :destroy] do
  member do
    post :sync
  end
end

# Webhook endpoint
post '/webhooks/pluggy', to: 'webhooks/pluggy#receive'
```

### 5. UI Components

1. **Connection Widget**
   - Embed Pluggy Connect or Belvo Widget
   - Similar flow to Plaid Link

2. **Account Selection**
   - Allow user to select which accounts to sync
   - Show institution logo and account details

3. **Connection Management**
   - View connected banks
   - Reconnect expired connections
   - Delete connections

### 6. Data Mapping

| Pluggy Field | Maybe Field |
|--------------|-------------|
| `account.name` | `account.name` |
| `account.balance` | `account.balance` |
| `account.type` | `account.accountable_type` |
| `transaction.description` | `entry.name` |
| `transaction.amount` | `entry.amount` |
| `transaction.date` | `entry.date` |
| `transaction.category` | `transaction.category_id` (mapped) |

### 7. Brazilian Account Types

| Brazilian Type | Maybe Type |
|----------------|------------|
| Conta Corrente | Depository (checking) |
| Conta Poupança | Depository (savings) |
| Cartão de Crédito | CreditCard |
| Investimento | Investment |
| Empréstimo | Loan |

## Implementation Phases

### Phase 1: Basic Connection (MVP)
- [ ] Pluggy account setup and API integration
- [ ] Connect widget implementation
- [ ] Account sync (balances only)
- [ ] Connection management UI

### Phase 2: Transaction Sync
- [ ] Transaction import from connected accounts
- [ ] Category mapping (Brazilian categories → Maybe categories)
- [ ] Merchant extraction from transaction descriptions
- [ ] PIX transaction identification

### Phase 3: Advanced Features
- [ ] Credit card support with statement sync
- [ ] Investment account sync
- [ ] Loan tracking
- [ ] Webhook-based real-time updates

### Phase 4: Polish
- [ ] Portuguese UI translations for connection flow
- [ ] Brazilian bank logos
- [ ] Error handling for Brazilian banking quirks
- [ ] Rate limiting and retry logic

## Security Considerations

1. **Data Storage**
   - Never store raw credentials
   - Encrypt access tokens at rest
   - Use secure webhook verification

2. **Compliance**
   - Follow BCB Open Finance security requirements
   - Implement proper consent management
   - Allow users to revoke access anytime

3. **Error Handling**
   - Handle bank maintenance windows gracefully
   - Retry failed syncs with exponential backoff
   - Notify users of connection issues

## Cost Estimation

### Pluggy Pricing (approximate)
- Setup: Free
- Per active connection: ~$2-5/month
- API calls: Included in connection fee

### Development Effort
- Phase 1: 2-3 weeks
- Phase 2: 2-3 weeks
- Phase 3: 3-4 weeks
- Phase 4: 1-2 weeks

**Total: 8-12 weeks** for full implementation

## References

- [Pluggy Documentation](https://docs.pluggy.ai/)
- [Belvo Documentation](https://docs.belvo.com/)
- [BCB Open Finance Portal](https://openfinancebrasil.org.br/)
- [Open Finance Brasil API Specs](https://github.com/OpenBanking-Brasil)

## Notes

- Start with Pluggy for faster time-to-market
- Consider Belvo if expanding to other LatAm countries
- Direct BCB integration only if scale justifies complexity
