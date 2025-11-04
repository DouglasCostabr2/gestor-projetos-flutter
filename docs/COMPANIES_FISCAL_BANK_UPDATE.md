# 🏢 Atualização: Dados Fiscais e Bancários para Empresas

## 📋 Visão Geral

A tabela `companies` foi atualizada para ter o **mesmo modelo JSONB dinâmico multi-país** que a tabela `organizations` possui. Isso permite que empresas (companies) vinculadas a clientes tenham dados fiscais e bancários completos e flexíveis para qualquer país do mundo.

---

## 🆕 O Que Foi Adicionado

### 1. **Novos Campos JSONB na Tabela `companies`**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| **`fiscal_data`** | JSONB | Dados fiscais por país (individual/business) |
| **`bank_data`** | JSONB | Dados bancários por país |
| **`fiscal_country`** | VARCHAR(2) | Código ISO do país ativo (BR, US, GB, etc.) |

### 2. **Tabela de Auditoria**

Nova tabela: `companies_fiscal_bank_audit_log`

Registra todas as alterações em dados fiscais e bancários de empresas:
- Quem fez a alteração (user_id, user_name, user_email)
- Tipo de ação (create, update, delete)
- País e tipo de pessoa (country_code, person_type)
- Campos alterados (changed_fields)
- Valores anteriores e novos (previous_values, new_values)
- Data/hora da alteração (created_at)

### 3. **Novos Métodos no Módulo de Empresas**

```dart
// Atualizar dados fiscais e bancários (JSONB)
await companiesModule.updateFiscalBankData(
  companyId: 'uuid-da-empresa',
  fiscalCountry: 'BR',
  fiscalData: {
    'current_country': 'BR',
    'current_person_type': 'business',
    'BR': {
      'individual': {'cpf': '...', 'full_name': '...'},
      'business': {'cnpj': '...', 'legal_name': '...', ...}
    }
  },
  bankData: {
    'BR': {'bank_name': '...', 'agency': '...', 'account': '...', 'pix_key': '...'},
    'US': {'bank_name': '...', 'routing_number': '...', 'account_number': '...'}
  },
);
```

---

## 📊 Estrutura dos Dados JSONB

### **`fiscal_data` - Estrutura Hierárquica**

```json
{
  "current_country": "BR",
  "current_person_type": "business",
  "BR": {
    "individual": {
      "cpf": "123.456.789-00",
      "full_name": "João Silva"
    },
    "business": {
      "cnpj": "12.345.678/0001-90",
      "legal_name": "Empresa XYZ Ltda",
      "state_registration": "123.456.789.012",
      "municipal_registration": "987654"
    }
  },
  "US": {
    "individual": {
      "ssn": "123-45-6789",
      "full_name": "John Doe"
    },
    "business": {
      "ein": "12-3456789",
      "legal_name": "ABC Corp"
    }
  },
  "GB": {
    "individual": {
      "ni_number": "AB123456C",
      "full_name": "John Smith"
    },
    "business": {
      "company_number": "12345678",
      "vat_number": "GB123456789",
      "legal_name": "Smith Ltd"
    }
  }
}
```

### **`bank_data` - Estrutura por País**

```json
{
  "BR": {
    "bank_name": "Banco do Brasil",
    "bank_code": "001",
    "agency": "1234-5",
    "account": "12345-6",
    "account_type": "Corrente",
    "pix_key": "empresa@email.com"
  },
  "US": {
    "bank_name": "Chase",
    "routing_number": "123456789",
    "account_number": "987654321",
    "account_type": "Checking",
    "swift": "CHASUS33"
  },
  "GB": {
    "bank_name": "Barclays",
    "sort_code": "12-34-56",
    "account_number": "12345678",
    "iban": "GB82WEST12345698765432",
    "swift": "BARCGB22"
  },
  "payment_platforms": {
    "paypal": {
      "enabled": true,
      "value": "empresa@paypal.com"
    },
    "stripe": {
      "enabled": true,
      "value": "acct_1234567890"
    },
    "mercadopago": {
      "enabled": false,
      "value": ""
    }
  }
}
```

---

## 🔄 Comparação: Antes vs Depois

### **ANTES (Campos Simples)**

```sql
-- Campos limitados, apenas Brasil
tax_id VARCHAR(50)
tax_id_type VARCHAR(20)
legal_name TEXT
state_registration VARCHAR(50)
municipal_registration VARCHAR(50)
```

❌ **Limitações:**
- Apenas um conjunto de dados fiscais
- Não suporta múltiplos países
- Não tem dados bancários
- Não diferencia pessoa física/jurídica por país

### **DEPOIS (Campos JSONB Dinâmicos)**

```sql
-- Campos flexíveis, multi-país
fiscal_data JSONB  -- Dados fiscais por país (individual + business)
bank_data JSONB    -- Dados bancários por país + plataformas de pagamento
fiscal_country VARCHAR(2)  -- País ativo
```

✅ **Vantagens:**
- Suporta múltiplos países simultaneamente
- Diferencia pessoa física e jurídica por país
- Inclui dados bancários completos
- Suporta plataformas de pagamento (PayPal, Stripe, etc.)
- Preserva histórico de dados ao trocar de país
- Estrutura idêntica às organizações (consistência)

---

## 🌍 Campos Disponíveis por País

### **🇧🇷 Brasil**

**Fiscal (Individual):**
- CPF
- Nome Completo

**Fiscal (Business):**
- CNPJ
- Razão Social
- Inscrição Estadual
- Inscrição Municipal

**Bancário:**
- Nome do Banco
- Código do Banco
- Agência
- Conta
- Tipo de Conta
- Chave PIX

### **🇺🇸 Estados Unidos**

**Fiscal (Individual):**
- SSN (Social Security Number)
- Full Name

**Fiscal (Business):**
- EIN (Employer Identification Number)
- Legal Name

**Bancário:**
- Bank Name
- Routing Number
- Account Number
- Account Type
- SWIFT/BIC Code

### **🇬🇧 Reino Unido**

**Fiscal (Individual):**
- NI Number (National Insurance)
- Full Name

**Fiscal (Business):**
- Company Number
- VAT Number
- Legal Name

**Bancário:**
- Bank Name
- Sort Code
- Account Number
- IBAN
- SWIFT/BIC Code

---

## 📁 Arquivos Criados/Modificados

### **Migrations SQL**
1. `supabase/migrations/20251103_add_fiscal_bank_data_to_companies.sql`
   - Adiciona campos JSONB à tabela companies
   - Cria índices GIN para performance

2. `supabase/migrations/20251103_create_companies_fiscal_bank_audit_log.sql`
   - Cria tabela de auditoria
   - Configura RLS policies

### **Código Dart**
1. `lib/modules/companies/contract.dart`
   - Adiciona método `updateFiscalBankData()`

2. `lib/modules/companies/repository.dart`
   - Implementa método `updateFiscalBankData()`

---

## 🚀 Como Usar

### **1. Atualizar Dados Fiscais e Bancários**

```dart
import 'package:my_business/modules/companies/module.dart';

// Preparar dados fiscais
final fiscalData = {
  'current_country': 'BR',
  'current_person_type': 'business',
  'BR': {
    'business': {
      'cnpj': '12.345.678/0001-90',
      'legal_name': 'Minha Empresa Ltda',
      'state_registration': '123.456.789.012',
      'municipal_registration': '987654',
    }
  }
};

// Preparar dados bancários
final bankData = {
  'BR': {
    'bank_name': 'Banco do Brasil',
    'bank_code': '001',
    'agency': '1234-5',
    'account': '12345-6',
    'account_type': 'Corrente',
    'pix_key': 'empresa@email.com',
  }
};

// Salvar
await companiesModule.updateFiscalBankData(
  companyId: companyId,
  fiscalCountry: 'BR',
  fiscalData: fiscalData,
  bankData: bankData,
);
```

### **2. Ler Dados Fiscais e Bancários**

```dart
// Buscar empresa
final company = await companiesModule.getCompanyById(companyId);

// Acessar dados
final fiscalCountry = company?['fiscal_country']; // 'BR'
final fiscalData = company?['fiscal_data']; // Map<String, dynamic>
final bankData = company?['bank_data']; // Map<String, dynamic>

// Exemplo: Acessar CNPJ
final cnpj = fiscalData?['BR']?['business']?['cnpj'];

// Exemplo: Acessar PIX
final pixKey = bankData?['BR']?['pix_key'];
```

---

## 🔒 Segurança e Auditoria

Todas as alterações em dados fiscais e bancários são registradas na tabela `companies_fiscal_bank_audit_log`:

```sql
SELECT 
  user_name,
  action_type,
  country_code,
  person_type,
  changed_fields,
  previous_values,
  new_values,
  created_at
FROM companies_fiscal_bank_audit_log
WHERE company_id = 'uuid-da-empresa'
ORDER BY created_at DESC;
```

---

## ✅ Próximos Passos

1. **Executar as migrations** no Supabase
2. **Criar interface de usuário** para gerenciar dados fiscais/bancários de empresas (similar à página de organizações)
3. **Implementar service layer** (`CompanyFiscalBankDataService`) para gerenciar cache e transformações
4. **Adicionar validações** específicas por país
5. **Criar testes** para garantir integridade dos dados

---

## 📚 Referências

- Estrutura baseada em: `lib/src/features/organization/pages/fiscal_and_bank_page.dart`
- Modelos reutilizados: `lib/src/features/organization/models/fiscal_bank_models.dart`
- Service de referência: `lib/src/features/organization/services/fiscal_bank_data_service.dart`
- Configurações de países: `lib/src/features/organization/models/country_fiscal_config.dart`

