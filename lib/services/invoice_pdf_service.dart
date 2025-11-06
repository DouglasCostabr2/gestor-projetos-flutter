import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/src/utils/money.dart';
import 'package:printing/printing.dart';
import 'google_drive_oauth_service.dart';

/// Serviço para geração de PDF de Invoice/Fatura
class InvoicePdfService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Gera um PDF de invoice para preview (sem salvar número no banco)
  ///
  /// Retorna os bytes do PDF gerado com número temporário "DRAFT"
  Future<Uint8List> generateInvoicePdf(String projectId) async {
    return _generatePdf(projectId, saveToDatabase: false);
  }

  /// Gera um PDF de invoice final, salva o número no banco de dados e faz upload para o Google Drive
  ///
  /// Retorna um Map com os bytes do PDF e a URL do Google Drive
  Future<Map<String, dynamic>> generateAndSaveInvoicePdf(String projectId) async {
    final pdfBytes = await _generatePdf(projectId, saveToDatabase: true);

    // Fazer upload para o Google Drive
    String? driveUrl;
    try {
      driveUrl = await _uploadToGoogleDrive(projectId, pdfBytes);
    } catch (e) {
      debugPrint('⚠️ Erro ao fazer upload para o Google Drive: $e');
      // Continua mesmo se o upload falhar
    }

    return {
      'pdfBytes': pdfBytes,
      'driveUrl': driveUrl,
    };
  }

  /// Método interno para gerar o PDF
  Future<Uint8List> _generatePdf(String projectId, {required bool saveToDatabase}) async {
    // Carregar fontes com suporte a Unicode
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Buscar dados do projeto
    final projectData = await _fetchProjectData(projectId);

    // Buscar dados do cliente
    final clientData = await _fetchClientData(projectData['client_id'] as String?);

    // Buscar dados da organização (quem emite a invoice)
    final organizationData = await _fetchOrganizationData(projectData['organization_id'] as String?);

    // Buscar dados da empresa do cliente (company)
    final companyData = await _fetchCompanyData(projectData['company_id'] as String?);

    // Gerar número da invoice
    final invoiceNumber = saveToDatabase
        ? await _generateInvoiceNumber(
            projectData['organization_id'] as String,
            projectId,
          )
        : await _getPreviewInvoiceNumber(
            projectData['organization_id'] as String,
            projectId,
          );

    // Buscar itens do catálogo (produtos/pacotes)
    final catalogItems = await _fetchCatalogItems(projectId);

    // Buscar custos adicionais
    final additionalCosts = await _fetchAdditionalCosts(projectId);

    // Buscar descontos
    final discounts = await _fetchDiscounts(projectId);

    // Criar o documento PDF com tema personalizado
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    // Adicionar página
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(projectData, clientData, organizationData, companyData, invoiceNumber),
          _buildItemsTable(
            catalogItems,
            additionalCosts,
            discounts,
            projectData['currency_code'] as String? ?? 'BRL',
          ),
          _buildFooter(organizationData),
        ],
      ),
    );

    return pdf.save();
  }

  // ============================================================================
  // MÉTODOS DE BUSCA DE DADOS
  // ============================================================================

  /// Obtém o número de preview da invoice (sem salvar no banco)
  /// Retorna o número existente ou o próximo número previsto
  Future<String> _getPreviewInvoiceNumber(String organizationId, String projectId) async {
    try {
      // Obter ano atual
      final currentYear = DateTime.now().year;

      // Verificar se já existe invoice para este projeto
      final existingInvoice = await _client
          .from('invoices')
          .select('invoice_number')
          .eq('project_id', projectId)
          .maybeSingle();

      if (existingInvoice != null) {
        // Já existe invoice para este projeto, retornar o número existente
        return existingInvoice['invoice_number'] as String;
      }

      // Buscar o próximo número sequencial para preview (sem salvar)
      final result = await _client
          .rpc('get_next_invoice_number', params: {
        'p_organization_id': organizationId,
        'p_year': currentYear,
      }).single();

      // Retornar com prefixo DRAFT para indicar que é preview
      return 'DRAFT-${result['invoice_number']}';
    } catch (e) {
      debugPrint('❌ Erro ao obter preview do número da invoice: $e');
      // Fallback: usar DRAFT
      return 'DRAFT';
    }
  }

  /// Gera o número da invoice no formato YYYY-NNNN e salva no banco
  /// Exemplo: 2025-0001, 2025-0002, etc.
  Future<String> _generateInvoiceNumber(String organizationId, String projectId) async {
    try {
      // Obter ano atual
      final currentYear = DateTime.now().year;

      // Verificar se já existe invoice para este projeto
      final existingInvoice = await _client
          .from('invoices')
          .select('invoice_number')
          .eq('project_id', projectId)
          .maybeSingle();

      if (existingInvoice != null) {
        // Já existe invoice para este projeto, retornar o número existente
        return existingInvoice['invoice_number'] as String;
      }

      // Buscar o próximo número sequencial para este ano
      final result = await _client
          .rpc('get_next_invoice_number', params: {
        'p_organization_id': organizationId,
        'p_year': currentYear,
      }).single();

      debugPrint('📊 Resultado da função get_next_invoice_number: $result');

      final invoiceNumber = result['invoice_number'] as String;

      // Registrar a invoice no banco de dados
      await _client.from('invoices').insert({
        'organization_id': organizationId,
        'project_id': projectId,
        'invoice_year': currentYear,
        'invoice_sequence': result['invoice_sequence'],
        'invoice_number': invoiceNumber,
        'created_by': _client.auth.currentUser?.id,
      });

      return invoiceNumber;
    } catch (e) {
      debugPrint('❌ Erro ao gerar número da invoice: $e');
      // Fallback: usar ID do projeto
      return 'INV-${projectId.substring(0, 8).toUpperCase()}';
    }
  }

  /// Faz upload do Invoice para o Google Drive e atualiza o registro no banco
  Future<String?> _uploadToGoogleDrive(String projectId, Uint8List pdfBytes) async {
    try {
      // Buscar dados do projeto para obter nomes e organização
      final projectData = await _fetchProjectData(projectId);
      final clientData = await _fetchClientData(projectData['client_id'] as String?);
      final companyData = await _fetchCompanyData(projectData['company_id'] as String?);

      // Buscar organização (não usado no momento, mas pode ser útil no futuro)
      // final organizationId = projectData['organization_id'] as String?;

      // Buscar invoice number
      final invoiceData = await _client
          .from('invoices')
          .select('invoice_number')
          .eq('project_id', projectId)
          .single();

      final invoiceNumber = invoiceData['invoice_number'] as String;
      final projectName = projectData['name'] as String? ?? 'Projeto';
      final clientName = clientData?['name'] as String? ?? 'Cliente';
      final companyName = companyData?['name'] as String?;

      // Nome do arquivo: Invoice_2025-0001.pdf
      final filename = 'Invoice_$invoiceNumber.pdf';

      // Fazer upload para o Google Drive
      final driveService = GoogleDriveOAuthService();
      final client = await driveService.getAuthedClient();

      // Fazer upload diretamente na pasta do projeto (usa a estrutura correta automaticamente)
      final uploaded = await driveService.uploadToProjectSubfolder(
        client: client,
        clientName: clientName,
        projectName: projectName,
        subfolderName: 'Invoices',
        filename: filename,
        bytes: pdfBytes,
        mimeType: 'application/pdf',
        companyName: companyName,
      );

      // Atualizar o registro da invoice com a URL do Drive
      await _client.from('invoices').update({
        'pdf_url': uploaded.publicViewUrl,
      }).eq('project_id', projectId);

      debugPrint('✅ Invoice enviada para o Google Drive: ${uploaded.publicViewUrl}');

      return uploaded.publicViewUrl;
    } catch (e) {
      debugPrint('❌ Erro ao fazer upload para o Google Drive: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchProjectData(String projectId) async {
    final response = await _client
        .from('projects')
        .select('id, name, description, value_cents, currency_code, created_at, client_id, company_id, organization_id')
        .eq('id', projectId)
        .single();
    return response;
  }

  Future<Map<String, dynamic>?> _fetchClientData(String? clientId) async {
    if (clientId == null) return null;
    try {
      final response = await _client
          .from('clients')
          .select('id, name, email, phone, company, address')
          .eq('id', clientId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchOrganizationData(String? organizationId) async {
    if (organizationId == null) return null;
    try {
      final response = await _client
          .from('organizations')
          .select('id, name, email, phone, mobile, address, address_number, address_complement, neighborhood, city, state_province, postal_code, country, fiscal_data, bank_data, fiscal_country')
          .eq('id', organizationId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchCompanyData(String? companyId) async {
    if (companyId == null) return null;
    try {
      final response = await _client
          .from('companies')
          .select('id, name, email, phone, address, city, state, zip_code, country, tax_id, tax_id_type, legal_name, state_registration, municipal_registration, fiscal_data, bank_data, fiscal_country')
          .eq('id', companyId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCatalogItems(String projectId) async {
    try {
      final response = await _client
          .from('project_catalog_items')
          .select('''
            kind,
            item_id,
            name,
            currency_code,
            unit_price_cents,
            quantity,
            position,
            comment,
            products!project_catalog_items_product_id_fkey(description),
            packages!project_catalog_items_package_id_fkey(description)
          ''')
          .eq('project_id', projectId)
          .order('position', ascending: true);

      // Processar resposta para adicionar descrição
      final items = List<Map<String, dynamic>>.from(response);
      for (final item in items) {
        String? description;

        // Buscar descrição do produto ou pacote
        if (item['kind'] == 'product' && item['products'] != null) {
          description = item['products']['description'] as String?;
        } else if (item['kind'] == 'package' && item['packages'] != null) {
          description = item['packages']['description'] as String?;
        }

        // Adicionar descrição ao item
        item['description'] = description;

        // Remover objetos aninhados
        item.remove('products');
        item.remove('packages');
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAdditionalCosts(String projectId) async {
    try {
      final response = await _client
          .from('project_additional_costs')
          .select('description, amount_cents, currency_code, type')
          .eq('project_id', projectId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDiscounts(String projectId) async {
    try {
      final response = await _client
          .from('project_discounts')
          .select('description, value_cents, type')
          .eq('project_id', projectId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // MÉTODOS DE CONSTRUÇÃO DO PDF
  // ============================================================================

  /// Helper para decodificar campos JSONB do Supabase
  Map<String, dynamic>? _decodeJsonb(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        return jsonDecode(value) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  pw.Widget _buildHeader(
    Map<String, dynamic> projectData,
    Map<String, dynamic>? clientData,
    Map<String, dynamic>? organizationData,
    Map<String, dynamic>? companyData,
    String invoiceNumber,
  ) {
    // Extrair dados fiscais da organização (quem emite a invoice)
    final orgFiscalData = _decodeJsonb(organizationData?['fiscal_data']);
    final orgFiscalCountry = organizationData?['fiscal_country'] as String?;

    String? taxNumber;
    String? taxLabel;
    String? legalName;
    String? countryCode;

    // Tentar extrair Tax Number e Legal Name do fiscal_data
    if (orgFiscalData != null) {
      // Determinar qual país usar
      countryCode = orgFiscalCountry;

      // Se não tiver fiscal_country, tentar pegar do current_country dentro do JSONB
      if (countryCode == null || countryCode.isEmpty) {
        countryCode = orgFiscalData['current_country'] as String?;
      }

      // Se ainda não tiver, tentar BR como fallback
      countryCode ??= 'BR';

      // Buscar dados do país específico
      final countryData = orgFiscalData[countryCode] as Map<String, dynamic>?;
      if (countryData != null) {
        // Determinar se é business ou individual
        String personType = orgFiscalData['current_person_type'] as String? ?? 'business';

        final personData = countryData[personType] as Map<String, dynamic>?;
        if (personData != null) {
          // Extrair legal_name
          legalName = personData['legal_name'] as String?;

          // Extrair tax_id com label específico por país
          if (countryCode == 'BR') {
            if (personType == 'business') {
              taxNumber = personData['cnpj'] as String?;
              taxLabel = 'CNPJ Nº';
            } else {
              taxNumber = personData['cpf'] as String?;
              taxLabel = 'CPF Nº';
            }
          } else if (countryCode == 'PL') {
            taxNumber = personData['tax_id'] as String? ?? personData['tax_id_individual'] as String?;
            taxLabel = 'NIP';
          } else if (countryCode == 'US') {
            if (personType == 'business') {
              taxNumber = personData['tax_id'] as String?;
              taxLabel = 'EIN';
            } else {
              taxNumber = personData['tax_id_individual'] as String?;
              taxLabel = 'SSN';
            }
          } else if (countryCode == 'GB') {
            if (personType == 'business') {
              taxNumber = personData['tax_id'] as String?;
              taxLabel = 'VAT Number';
            } else {
              taxNumber = personData['tax_id_individual'] as String?;
              taxLabel = 'NI Number';
            }
          } else {
            // Genérico
            taxNumber = personData['tax_id'] as String? ?? personData['tax_id_individual'] as String?;
            taxLabel = 'Tax Number';
          }
        }
      }
    }

    // Usar legal_name se disponível, senão usar nome comercial
    final displayName = legalName ?? organizationData?['name'] as String? ?? 'EMPRESA';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header com INVOICE à esquerda e dados da organização à direita
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Título INVOICE à esquerda
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
            ),

            // Informações da organização à direita
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Nome legal da organização (quem emite)
                pw.Text(
                  displayName,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right,
                ),
                pw.SizedBox(height: 4),

                // Endereço da organização em duas linhas
                if (organizationData?['address'] != null) ...[
                  ...(_buildOrganizationAddress(organizationData!).map((line) => pw.Text(
                    line,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right,
                  ))),
                ],

                // Telefone
                if (organizationData?['phone'] != null)
                  pw.Text(
                    'Phone Number: ${organizationData!['phone']}',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right,
                  ),

                // Email (cor preta)
                if (organizationData?['email'] != null)
                  pw.Text(
                    organizationData!['email'] as String,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right,
                  ),

                // Tax Number se disponível
                if (taxNumber != null)
                  pw.Text(
                    '${taxLabel ?? "Tax Number"}: $taxNumber',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.right,
                  ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // Informações do cliente e invoice
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Invoice To (Empresa do Cliente)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Invoice To:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  // Legal Name, Tax Number e endereço da empresa do cliente
                  if (companyData != null) ...[
                    // Extrair Legal Name e Tax ID da empresa do cliente
                    // Prioridade: fiscal_data (JSONB) > legal_name (campo direto) > name (nome comercial)
                    ..._buildCompanyTaxInfo(
                      _decodeJsonb(companyData['fiscal_data']),
                      companyData['tax_id'] as String?,
                      companyData['legal_name'] as String?,
                      companyData['fiscal_country'] as String?,
                      companyData['name'] as String?, // Nome comercial como fallback
                    ),
                    // Endereço completo da empresa
                    if (companyData['address'] != null)
                      pw.Text(
                        _buildFullAddress(companyData),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ] else ...[
                    // Fallback para dados do cliente se não houver empresa
                    if (clientData?['name'] != null)
                      pw.Text(
                        clientData!['name'] as String,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    if (clientData?['company'] != null)
                      pw.Text(
                        'Tax Number: ${clientData!['company']}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    if (clientData?['address'] != null)
                      pw.Text(
                        clientData!['address'] as String,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ],
              ),
            ),

            // Invoice Number e Data
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Invoice No. $invoiceNumber',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Date: ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Helper para construir endereço da organização em duas linhas
  /// Linha 1: Rua, Número, Bairro
  /// Linha 2: Cidade, Estado, CEP, País
  List<String> _buildOrganizationAddress(Map<String, dynamic> data) {
    final lines = <String>[];

    // Linha 1: Rua, Número, Bairro
    final line1Parts = <String>[];
    final street = data['address'] as String?;
    final number = data['address_number'] as String?;
    final neighborhood = data['neighborhood'] as String?;

    if (street != null && street.isNotEmpty) {
      if (number != null && number.isNotEmpty) {
        line1Parts.add('$street $number');
      } else {
        line1Parts.add(street);
      }
    }

    if (neighborhood != null && neighborhood.isNotEmpty) {
      line1Parts.add(neighborhood);
    }

    if (line1Parts.isNotEmpty) {
      lines.add(line1Parts.join(', '));
    }

    // Linha 2: Cidade, Estado, CEP, País
    final line2Parts = <String>[];
    final city = data['city'] as String?;
    final state = (data['state_province'] ?? data['state']) as String?;
    final postalCode = (data['postal_code'] ?? data['zip_code']) as String?;
    final country = data['country'] as String?;

    if (city != null && city.isNotEmpty) line2Parts.add(city);
    if (state != null && state.isNotEmpty) line2Parts.add(state);
    if (postalCode != null && postalCode.isNotEmpty) line2Parts.add(postalCode);
    if (country != null && country.isNotEmpty) line2Parts.add(country.toUpperCase());

    if (line2Parts.isNotEmpty) {
      lines.add(line2Parts.join(', '));
    }

    return lines;
  }

  /// Helper para construir endereço completo em uma linha (para companies)
  /// Suporta tanto organizations (address_number, state_province, postal_code)
  /// quanto companies (state, zip_code)
  String _buildFullAddress(Map<String, dynamic> data) {
    final parts = <String>[];

    // Rua e número
    final street = data['address'] as String?;
    final number = data['address_number'] as String?; // organizations only
    if (street != null) {
      if (number != null && number.isNotEmpty) {
        parts.add('$street, $number');
      } else {
        parts.add(street);
      }
    }

    // Complemento (organizations only)
    final complement = data['address_complement'] as String?;
    if (complement != null && complement.isNotEmpty) {
      parts.add(complement);
    }

    // Bairro (organizations only)
    final neighborhood = data['neighborhood'] as String?;
    if (neighborhood != null && neighborhood.isNotEmpty) {
      parts.add(neighborhood);
    }

    // Cidade, Estado, CEP
    final city = data['city'] as String?;
    // Suporta tanto 'state_province' (organizations) quanto 'state' (companies)
    final state = (data['state_province'] ?? data['state']) as String?;
    // Suporta tanto 'postal_code' (organizations) quanto 'zip_code' (companies)
    final postalCode = (data['postal_code'] ?? data['zip_code']) as String?;

    final cityStateParts = <String>[];
    if (city != null && city.isNotEmpty) cityStateParts.add(city);
    if (state != null && state.isNotEmpty) cityStateParts.add(state);
    if (postalCode != null && postalCode.isNotEmpty) cityStateParts.add(postalCode);

    if (cityStateParts.isNotEmpty) {
      parts.add(cityStateParts.join(' - '));
    }

    // País
    final country = data['country'] as String?;
    if (country != null && country.isNotEmpty && country != 'Brasil') {
      parts.add(country);
    }

    return parts.join(', ');
  }

  /// Helper para extrair e exibir Tax ID da empresa do cliente
  /// Suporta tanto fiscal_data (JSONB) quanto campos diretos (tax_id, legal_name)
  /// Suporta múltiplos países (BR, PL, US, etc.)
  List<pw.Widget> _buildCompanyTaxInfo(
    Map<String, dynamic>? fiscalData,
    String? taxId,
    String? legalName,
    String? fiscalCountry,
    String? commercialName, // Nome comercial como último fallback
  ) {
    final widgets = <pw.Widget>[];

    String? taxNumber;
    String? taxLabel;
    String? companyLegalName;

    // Prioridade 1: Tentar extrair do fiscal_data (JSONB)
    if (fiscalData != null) {
      // Determinar qual país usar
      String? countryCode = fiscalCountry;

      // Se não tiver fiscal_country, tentar pegar do current_country dentro do JSONB
      if (countryCode == null || countryCode.isEmpty) {
        countryCode = fiscalData['current_country'] as String?;
      }

      // Se ainda não tiver, tentar BR como fallback
      countryCode ??= 'BR';

      // Buscar dados do país específico
      final countryData = fiscalData[countryCode] as Map<String, dynamic>?;
      if (countryData != null) {
        // Determinar se é business ou individual
        String personType = fiscalData['current_person_type'] as String? ?? 'business';

        final personData = countryData[personType] as Map<String, dynamic>?;
        if (personData != null) {
          // Extrair legal_name
          companyLegalName = personData['legal_name'] as String?;

          // Extrair tax_id com label específico por país
          if (countryCode == 'BR') {
            if (personType == 'business') {
              taxNumber = personData['cnpj'] as String?;
              taxLabel = 'CNPJ Nº';
            } else {
              taxNumber = personData['cpf'] as String?;
              taxLabel = 'CPF Nº';
            }
          } else if (countryCode == 'PL') {
            taxNumber = personData['tax_id'] as String? ?? personData['tax_id_individual'] as String?;
            taxLabel = 'NIP';
          } else if (countryCode == 'US') {
            if (personType == 'business') {
              taxNumber = personData['tax_id'] as String?;
              taxLabel = 'EIN';
            } else {
              taxNumber = personData['tax_id_individual'] as String?;
              taxLabel = 'SSN';
            }
          } else if (countryCode == 'GB') {
            if (personType == 'business') {
              taxNumber = personData['tax_id'] as String?;
              taxLabel = 'VAT Number';
            } else {
              taxNumber = personData['tax_id_individual'] as String?;
              taxLabel = 'NI Number';
            }
          } else {
            // Genérico
            taxNumber = personData['tax_id'] as String? ?? personData['tax_id_individual'] as String?;
            taxLabel = 'Tax Number';
          }
        }
      }
    }

    // Prioridade 2: Usar campos diretos se JSONB não tiver dados
    taxNumber ??= taxId;
    companyLegalName ??= legalName;

    // Prioridade 3: Usar nome comercial se não tiver legal name
    companyLegalName ??= commercialName;

    // Exibir Razão Social/Legal Name se disponível
    if (companyLegalName != null && companyLegalName.isNotEmpty) {
      widgets.add(
        pw.Text(
          companyLegalName,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    // Exibir Tax Number se disponível
    if (taxNumber != null && taxNumber.isNotEmpty) {
      widgets.add(
        pw.Text(
          '${taxLabel ?? "Tax Number"}: $taxNumber',
          style: const pw.TextStyle(fontSize: 9),
        ),
      );
    }

    return widgets;
  }

  pw.Widget _buildItemsTable(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> additionalCosts,
    List<Map<String, dynamic>> discounts,
    String currency,
  ) {
    if (items.isEmpty) {
      return pw.Text('Nenhum item no projeto', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey));
    }

    // Calcular subtotal dos itens
    final subtotal = items.fold<int>(0, (sum, item) {
      final quantity = (item['quantity'] as int?) ?? 1;
      final unitPrice = (item['unit_price_cents'] as int?) ?? 0;
      return sum + (quantity * unitPrice);
    });

    // Calcular total de custos adicionais
    final totalAdditionalCosts = additionalCosts.fold<int>(0, (sum, cost) {
      final amount = (cost['amount_cents'] as int?) ?? 0;
      return sum + amount;
    });

    // Calcular total de descontos
    int totalDiscounts = 0;
    for (final discount in discounts) {
      final type = discount['type'] as String?;
      final valueCents = (discount['value_cents'] as int?) ?? 0;

      if (type == 'percentage') {
        // Desconto percentual sobre o subtotal
        totalDiscounts += ((subtotal * valueCents) / 10000).round();
      } else {
        // Desconto fixo
        totalDiscounts += valueCents;
      }
    }

    // Total final
    final totalGeral = subtotal + totalAdditionalCosts - totalDiscounts;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),

        // Cabeçalho da tabela
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 2),
            ),
          ),
          child: pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                children: [
                  _buildTableCell('DESCRIPTION', isHeader: true),
                  _buildTableCell('UNIT PRICE', isHeader: true, alignment: pw.Alignment.centerRight),
                  _buildTableCell('QTY', isHeader: true, alignment: pw.Alignment.center),
                  _buildTableCell('TOTAL', isHeader: true, alignment: pw.Alignment.centerRight),
                ],
              ),
            ],
          ),
        ),

        // Linhas de itens
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            ...items.map((item) {
              final quantity = (item['quantity'] as int?) ?? 1;
              final unitPrice = (item['unit_price_cents'] as int?) ?? 0;
              final total = quantity * unitPrice;
              final name = item['name'] as String? ?? '-';
              final description = item['description'] as String?;
              final comment = item['comment'] as String?;

              return pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                children: [
                  // Coluna DESCRIPTION: Nome + Descrição + Comentário
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Nome do item (negrito)
                        pw.Text(
                          name,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        // Descrição (se existir)
                        if (description != null && description.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            description,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                        // Comentário (se existir)
                        if (comment != null && comment.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            comment,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildTableCell(Money.formatWithSymbol(unitPrice, currency), alignment: pw.Alignment.centerRight),
                  _buildTableCell(quantity.toString(), alignment: pw.Alignment.center),
                  _buildTableCell(Money.formatWithSymbol(total, currency), alignment: pw.Alignment.centerRight),
                ],
              );
            }),
          ],
        ),

        // Linha de Subtotal (se houver custos adicionais ou descontos)
        if (additionalCosts.isNotEmpty || discounts.isNotEmpty)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 1),
              ),
            ),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  children: [
                    _buildTableCell('Subtotal', isHeader: false),
                    _buildTableCell('', alignment: pw.Alignment.centerRight),
                    _buildTableCell('', alignment: pw.Alignment.center),
                    _buildTableCell(
                      Money.formatWithSymbol(subtotal, currency),
                      isHeader: false,
                      alignment: pw.Alignment.centerRight,
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Additional Costs
        if (additionalCosts.isNotEmpty)
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              ...additionalCosts.map((cost) {
                final description = cost['description'] as String? ?? 'Additional cost';
                final amount = (cost['amount_cents'] as int?) ?? 0;

                return pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        description,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    _buildTableCell('', alignment: pw.Alignment.centerRight),
                    _buildTableCell('', alignment: pw.Alignment.center),
                    _buildTableCell(
                      Money.formatWithSymbol(amount, currency),
                      alignment: pw.Alignment.centerRight,
                    ),
                  ],
                );
              }),
            ],
          ),

        // Discounts
        if (discounts.isNotEmpty)
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              ...discounts.map((discount) {
                final description = discount['description'] as String? ?? 'Discount';
                final type = discount['type'] as String?;
                final valueCents = (discount['value_cents'] as int?) ?? 0;

                // Calcular valor do desconto
                int discountAmount;
                String displayText;

                if (type == 'percentage') {
                  discountAmount = ((subtotal * valueCents) / 10000).round();
                  final percentage = (valueCents / 100).toStringAsFixed(2);
                  displayText = '$description ($percentage%)';
                } else {
                  discountAmount = valueCents;
                  displayText = description;
                }

                return pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        displayText,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    _buildTableCell('', alignment: pw.Alignment.centerRight),
                    _buildTableCell('', alignment: pw.Alignment.center),
                    _buildTableCell(
                      '-${Money.formatWithSymbol(discountAmount, currency)}',
                      alignment: pw.Alignment.centerRight,
                    ),
                  ],
                );
              }),
            ],
          ),

        // Linha TOTAL
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 2),
              bottom: pw.BorderSide(color: PdfColors.black, width: 2),
            ),
          ),
          child: pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                children: [
                  _buildTableCell('TOTAL', isHeader: true),
                  _buildTableCell('', alignment: pw.Alignment.centerRight),
                  _buildTableCell('', alignment: pw.Alignment.center),
                  _buildTableCell(
                    Money.formatWithSymbol(totalGeral, currency),
                    isHeader: true,
                    alignment: pw.Alignment.centerRight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(Map<String, dynamic>? organizationData) {
    final bankData = _decodeJsonb(organizationData?['bank_data']);
    final fiscalData = _decodeJsonb(organizationData?['fiscal_data']);
    final fiscalCountry = organizationData?['fiscal_country'] as String?;

    // Determinar qual país usar para dados bancários
    String? countryCode = fiscalCountry;

    // Se não tiver fiscal_country, tentar pegar do current_country dentro do fiscal_data
    if ((countryCode == null || countryCode.isEmpty) && fiscalData != null) {
      countryCode = fiscalData['current_country'] as String?;
    }

    // Se ainda não tiver, tentar BR como fallback
    countryCode ??= 'BR';

    // Extrair dados bancários do país específico
    String? bankName;
    String? bankCode;
    String? account;
    String? pixKey;
    String? routingNumber;
    String? swift;
    String? iban;

    if (bankData != null) {
      final countryBankData = bankData[countryCode] as Map<String, dynamic>?;
      if (countryBankData != null) {
        bankName = countryBankData['bank_name'] as String?;

        // Campos específicos por país
        if (countryCode == 'BR') {
          bankCode = countryBankData['bank_code'] as String?;
          account = countryBankData['account'] as String?;
          pixKey = countryBankData['pix_key'] as String?;
        } else if (countryCode == 'US') {
          routingNumber = countryBankData['routing_number'] as String?;
          account = countryBankData['account_number'] as String?;
          swift = countryBankData['swift'] as String?;
        } else if (countryCode == 'GB') {
          account = countryBankData['account_number'] as String?;
          iban = countryBankData['iban'] as String?;
          swift = countryBankData['swift'] as String?;
        } else if (countryCode == 'PL') {
          account = countryBankData['account_number'] as String?;
          swift = countryBankData['swift'] as String?;
        } else {
          // Genérico
          account = countryBankData['account_number'] as String?;
          swift = countryBankData['swift'] as String?;
        }
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),

        // Nota sobre VAT/impostos
        pw.Text(
          'VAT is not applicable.',
          style: const pw.TextStyle(fontSize: 9),
        ),

        pw.SizedBox(height: 16),

        // Instruções de pagamento
        pw.Text(
          'Please transfer the money to the following bank account.',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Payment is due immediately.',
          style: const pw.TextStyle(fontSize: 9),
        ),

        pw.SizedBox(height: 12),

        // Informações bancárias
        if (bankName != null || bankCode != null || account != null || pixKey != null || routingNumber != null || swift != null || iban != null) ...[
          if (bankName != null)
            pw.Text(
              bankName,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          if (organizationData?['name'] != null)
            pw.Text(
              organizationData!['name'] as String,
              style: const pw.TextStyle(fontSize: 9),
            ),

          // Campos específicos por país
          if (countryCode == 'BR') ...[
            if (bankCode != null)
              pw.Text(
                'Bank Code: $bankCode',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (account != null)
              pw.Text(
                'Account: $account',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (pixKey != null)
              pw.Text(
                'PIX Key: $pixKey',
                style: const pw.TextStyle(fontSize: 9),
              ),
          ] else if (countryCode == 'US') ...[
            if (routingNumber != null)
              pw.Text(
                'Routing Number: $routingNumber',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (account != null)
              pw.Text(
                'Account Number: $account',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (swift != null)
              pw.Text(
                'SWIFT/BIC: $swift',
                style: const pw.TextStyle(fontSize: 9),
              ),
          ] else if (countryCode == 'GB') ...[
            if (iban != null)
              pw.Text(
                'IBAN: $iban',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (account != null)
              pw.Text(
                'Account Number: $account',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (swift != null)
              pw.Text(
                'SWIFT/BIC: $swift',
                style: const pw.TextStyle(fontSize: 9),
              ),
          ] else if (countryCode == 'PL') ...[
            if (account != null)
              pw.Text(
                'Account Number (IBAN): $account',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (swift != null)
              pw.Text(
                'SWIFT/BIC: $swift',
                style: const pw.TextStyle(fontSize: 9),
              ),
          ] else ...[
            // Genérico
            if (account != null)
              pw.Text(
                'Account Number: $account',
                style: const pw.TextStyle(fontSize: 9),
              ),
            if (swift != null)
              pw.Text(
                'SWIFT/BIC: $swift',
                style: const pw.TextStyle(fontSize: 9),
              ),
          ],
        ],

        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),

        // Rodapé final
        pw.Center(
          child: pw.Text(
            '1',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.Alignment? alignment}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignment ?? pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '-';

    DateTime? date;
    if (dateValue is DateTime) {
      date = dateValue;
    } else if (dateValue is String) {
      try {
        date = DateTime.parse(dateValue);
      } catch (_) {
        return '-';
      }
    }

    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}
