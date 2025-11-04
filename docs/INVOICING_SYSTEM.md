# 🧾 Sistema de Invoicing - Guia Completo

## 📋 Visão Geral

O sistema de invoicing foi implementado com uma **abordagem híbrida** que suporta:
- ✅ **Clientes internacionais** (qualquer país do mundo)
- ✅ **Pessoa física** (CPF, SSN, etc.)
- ✅ **Pessoa jurídica** (CNPJ, VAT, EIN, etc.)
- ✅ **Múltiplas empresas por cliente**
- ✅ **Dados fiscais completos** para emissão de notas fiscais/invoices

---

## 🗄️ Estrutura de Dados

### 1. **CLIENTS** (Clientes)
Armazena dados de **pessoa física** ou dados básicos do cliente.

**Novos campos fiscais:**
- `tax_id` (VARCHAR 50) - Número de identificação fiscal (CPF, SSN, NIF, etc.)
- `tax_id_type` (VARCHAR 20) - Tipo de ID fiscal (cpf, ssn, nif, vat, etc.)
- `legal_name` (TEXT) - Nome legal/completo para invoicing

**Campos de endereço existentes:**
- `address`, `city`, `state`, `zip_code`, `country`

**Quando usar:**
- Cliente é pessoa física (CPF, SSN, etc.)
- Cliente não tem empresa cadastrada
- Dados básicos de contato

---

### 2. **COMPANIES** (Empresas)
Armazena dados de **pessoa jurídica** vinculada a um cliente.

**Novos campos fiscais:**
- `tax_id` (VARCHAR 50) - CNPJ, VAT, EIN, etc.
- `tax_id_type` (VARCHAR 20) - Tipo de ID fiscal (cnpj, vat, ein, etc.)
- `legal_name` (TEXT) - Razão social
- `state_registration` (VARCHAR 50) - Inscrição Estadual (Brasil)
- `municipal_registration` (VARCHAR 50) - Inscrição Municipal (Brasil)

**Novos campos de endereço:**
- `address`, `city`, `state`, `zip_code`, `country`

**Novos campos de contato:**
- `email`, `phone`, `website`

**Quando usar:**
- Cliente tem empresa (pessoa jurídica)
- Precisa de CNPJ/VAT/EIN
- Múltiplas empresas por cliente

---

### 3. **ORGANIZATION_SETTINGS** (Sua Empresa)
Armazena os dados da **SUA empresa** (emissor de invoices).

**Campos principais:**
- **Básicos:** `company_name`, `legal_name`, `trade_name`
- **Fiscais:** `tax_id`, `tax_id_type`, `state_registration`, `municipal_registration`
- **Endereço:** `address`, `address_number`, `address_complement`, `neighborhood`, `city`, `state`, `zip_code`, `country`
- **Contato:** `email`, `phone`, `mobile`, `website`
- **Branding:** `logo_url`, `primary_color`
- **Invoice:** `invoice_prefix`, `next_invoice_number`, `invoice_notes`, `payment_terms`
- **Bancários:** `bank_name`, `bank_account`, `bank_agency`, `pix_key`

**Permissões:**
- ✅ Todos podem **visualizar**
- 🔒 Apenas **admins** podem **editar**

---

## 🌍 Tipos de Tax ID Suportados

### Brasil
- `cpf` - Cadastro de Pessoa Física (11 dígitos)
- `cnpj` - Cadastro Nacional de Pessoa Jurídica (14 dígitos)

### Estados Unidos
- `ssn` - Social Security Number
- `ein` - Employer Identification Number

### União Europeia
- `vat` - Value Added Tax Number
- `nif` - Número de Identificação Fiscal (Portugal, Espanha)

### Reino Unido
- `utr` - Unique Taxpayer Reference
- `vat` - VAT Registration Number

### Austrália
- `abn` - Australian Business Number
- `tfn` - Tax File Number

### Canadá
- `sin` - Social Insurance Number
- `bn` - Business Number

### Outros
- `tin` - Taxpayer Identification Number (genérico)

---

## 🔄 Lógica de Invoicing (Abordagem Híbrida)

### Ao Emitir Invoice:

```dart
Future<InvoiceData> getInvoiceRecipient(String clientId) async {
  // 1. Buscar cliente
  final client = await clientsModule.getClientById(clientId);
  
  // 2. Buscar empresas do cliente
  final companies = await companiesModule.getCompanies(clientId);
  
  // 3. Decidir qual usar
  if (companies.isNotEmpty) {
    // Cliente tem empresa → usar dados da empresa (CNPJ/VAT)
    return InvoiceData.fromCompany(companies.first);
  } else {
    // Cliente não tem empresa → usar dados do cliente (CPF/SSN)
    return InvoiceData.fromClient(client);
  }
}

Future<InvoiceData> getInvoiceIssuer() async {
  // Buscar dados da sua empresa
  final orgSettings = await getOrganizationSettings();
  return InvoiceData.fromOrganization(orgSettings);
}
```

---

## 📝 Exemplos de Uso

### Exemplo 1: Cliente Pessoa Física (Brasil)

**Cliente:**
```json
{
  "name": "João Silva",
  "tax_id": "123.456.789-00",
  "tax_id_type": "cpf",
  "legal_name": "João da Silva Santos",
  "address": "Rua das Flores, 123",
  "city": "São Paulo",
  "state": "SP",
  "zip_code": "01234-567",
  "country": "Brazil"
}
```

**Invoice:**
- **Para:** João da Silva Santos (CPF: 123.456.789-00)
- **Endereço:** Rua das Flores, 123 - São Paulo/SP - CEP 01234-567

---

### Exemplo 2: Cliente Pessoa Jurídica (Brasil)

**Cliente:**
```json
{
  "name": "Empresa XYZ"
}
```

**Empresa (vinculada ao cliente):**
```json
{
  "name": "XYZ Tecnologia",
  "legal_name": "XYZ Tecnologia Ltda",
  "tax_id": "12.345.678/0001-90",
  "tax_id_type": "cnpj",
  "state_registration": "123.456.789.012",
  "address": "Av. Paulista, 1000",
  "city": "São Paulo",
  "state": "SP",
  "zip_code": "01310-100",
  "country": "Brazil"
}
```

**Invoice:**
- **Para:** XYZ Tecnologia Ltda (CNPJ: 12.345.678/0001-90)
- **IE:** 123.456.789.012
- **Endereço:** Av. Paulista, 1000 - São Paulo/SP - CEP 01310-100

---

### Exemplo 3: Cliente Internacional (EUA)

**Cliente:**
```json
{
  "name": "John Doe",
  "tax_id": "123-45-6789",
  "tax_id_type": "ssn",
  "legal_name": "John Michael Doe",
  "address": "123 Main Street",
  "city": "New York",
  "state": "NY",
  "zip_code": "10001",
  "country": "United States"
}
```

**Invoice:**
- **To:** John Michael Doe (SSN: 123-45-6789)
- **Address:** 123 Main Street - New York, NY 10001 - United States

---

### Exemplo 4: Empresa Internacional (Reino Unido)

**Empresa:**
```json
{
  "name": "Tech Solutions UK",
  "legal_name": "Tech Solutions Limited",
  "tax_id": "GB123456789",
  "tax_id_type": "vat",
  "address": "10 Downing Street",
  "city": "London",
  "zip_code": "SW1A 2AA",
  "country": "United Kingdom"
}
```

**Invoice:**
- **To:** Tech Solutions Limited (VAT: GB123456789)
- **Address:** 10 Downing Street - London, SW1A 2AA - United Kingdom

---

## 🚀 Próximos Passos

### 1. Executar Migrations
```bash
# No Supabase SQL Editor, execute na ordem:
1. 2025-10-31_add_tax_fields_to_clients.sql
2. 2025-10-31_add_tax_and_address_fields_to_companies.sql
3. 2025-10-31_create_organization_settings.sql
```

### 2. Atualizar Formulários
- ✅ Adicionar campos fiscais no formulário de clientes
- ✅ Adicionar campos fiscais no formulário de empresas
- ✅ Criar página de configurações da organização

### 3. Implementar Geração de Invoices
- Criar módulo de invoices
- Implementar templates de invoice (PDF)
- Adicionar numeração automática
- Integrar com sistema de pagamentos

---

## 🔒 Segurança e Permissões

### Organization Settings
- **SELECT:** Todos os usuários autenticados
- **INSERT/UPDATE/DELETE:** Apenas admins

### Clients e Companies
- Seguem as políticas RLS existentes
- Campos fiscais têm as mesmas permissões dos outros campos

---

## 📊 Relatórios e Queries Úteis

### Listar clientes com dados fiscais
```sql
SELECT 
  name,
  tax_id,
  tax_id_type,
  legal_name,
  country
FROM clients
WHERE tax_id IS NOT NULL
ORDER BY name;
```

### Listar empresas com CNPJ/VAT
```sql
SELECT 
  c.name as company_name,
  c.legal_name,
  c.tax_id,
  c.tax_id_type,
  cl.name as client_name
FROM companies c
JOIN clients cl ON c.client_id = cl.id
WHERE c.tax_id IS NOT NULL
ORDER BY c.name;
```

---

## ✅ Checklist de Implementação

- [x] Migration para campos fiscais em `clients`
- [x] Migration para campos fiscais em `companies`
- [x] Migration para tabela `organization_settings`
- [x] Atualizar `ClientsContract` e `ClientsRepository`
- [x] Atualizar `CompaniesContract` e `CompaniesRepository`
- [ ] Atualizar formulário de clientes
- [ ] Atualizar formulário de empresas
- [ ] Criar página de configurações da organização
- [ ] Implementar módulo de invoices
- [ ] Criar templates de invoice (PDF)

---

## 🆘 Suporte

Para dúvidas ou problemas:
1. Verifique se as migrations foram executadas corretamente
2. Confirme que os campos estão aparecendo no Supabase
3. Teste com dados de exemplo antes de usar em produção

