# Exemplos de Uso - Atomic Design

Este documento contém exemplos práticos de como usar os componentes da nova estrutura Atomic Design.

---

## 📦 Import Único (Recomendado)

```dart
import 'package:gestor_projetos_flutter/ui/ui.dart';
```

Este import único dá acesso a **todos** os atoms e molecules do projeto.

---

## 🔹 Atoms - Componentes Básicos

### Buttons

#### Primary Button
```dart
PrimaryButton(
  onPressed: () {
    print('Botão clicado!');
  },
  child: const Text('Salvar'),
)
```

#### Secondary Button
```dart
SecondaryButton(
  onPressed: () => Navigator.pop(context),
  child: const Text('Cancelar'),
)
```

#### Outline Button
```dart
OutlineButton(
  onPressed: () => _handleEdit(),
  child: const Text('Editar'),
)
```

#### Danger Button
```dart
DangerButton(
  onPressed: () => _handleDelete(),
  child: const Text('Excluir'),
)
```

#### Success Button
```dart
SuccessButton(
  onPressed: () => _handleApprove(),
  child: const Text('Aprovar'),
)
```

#### Icon Button
```dart
IconButtonCustom(
  icon: Icons.add,
  onPressed: () => _handleAdd(),
  tooltip: 'Adicionar novo item',
)
```

#### Text Button
```dart
TextButtonCustom(
  onPressed: () => _showHelp(),
  child: const Text('Ajuda'),
)
```

### Inputs

#### Text Field
```dart
GenericTextField(
  controller: _nameController,
  label: 'Nome do Projeto',
  hint: 'Digite o nome',
  required: true,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Campo obrigatório';
    }
    return null;
  },
)
```

#### Text Area
```dart
GenericTextArea(
  controller: _descriptionController,
  label: 'Descrição',
  hint: 'Digite a descrição do projeto',
  maxLines: 5,
  maxLength: 500,
)
```

#### Number Field
```dart
GenericNumberField(
  controller: _valueController,
  label: 'Valor',
  hint: '0.00',
  prefix: 'R\$',
  decimals: 2,
  required: true,
)
```

#### Date Picker
```dart
GenericDatePicker(
  controller: _dateController,
  label: 'Data de Entrega',
  firstDate: DateTime.now(),
  lastDate: DateTime.now().add(const Duration(days: 365)),
  required: true,
)
```

#### Checkbox
```dart
GenericCheckbox(
  value: _isActive,
  onChanged: (value) {
    setState(() => _isActive = value ?? false);
  },
  label: 'Projeto Ativo',
)
```

#### Color Picker
```dart
GenericColorPicker(
  controller: _colorController,
  label: 'Cor do Projeto',
  initialColor: Colors.blue,
)
```

### Avatars

#### Cached Avatar
```dart
CachedAvatar(
  imageUrl: user['avatar_url'],
  name: user['name'],
  size: 40,
)
```

---

## 🔸 Molecules - Combinações Simples

### Dropdowns

#### Async Dropdown (carrega dados do servidor)
```dart
AsyncDropdownField<String>(
  label: 'Cliente',
  hint: 'Selecione um cliente',
  required: true,
  value: _selectedClientId,
  onChanged: (value) {
    setState(() => _selectedClientId = value);
  },
  fetchItems: () async {
    final response = await Supabase.instance.client
        .from('clients')
        .select('id, name')
        .order('name');
    
    return (response as List).map((item) {
      return DropdownItem<String>(
        value: item['id'],
        label: item['name'],
      );
    }).toList();
  },
)
```

#### Searchable Dropdown (com busca)
```dart
SearchableDropdownField<String>(
  label: 'Usuário',
  hint: 'Buscar usuário',
  value: _selectedUserId,
  onChanged: (value) {
    setState(() => _selectedUserId = value);
  },
  items: _users.map((user) {
    return DropdownItem<String>(
      value: user['id'],
      label: user['name'],
    );
  }).toList(),
  searchHint: 'Digite para buscar...',
)
```

#### Multi-Select Dropdown (seleção múltipla)
```dart
MultiSelectDropdownField<String>(
  label: 'Tags',
  hint: 'Selecione as tags',
  values: _selectedTags,
  onChanged: (values) {
    setState(() => _selectedTags = values);
  },
  items: _availableTags.map((tag) {
    return DropdownItem<String>(
      value: tag['id'],
      label: tag['name'],
    );
  }).toList(),
)
```

### Table Cells

#### Avatar Cell
```dart
TableCellAvatar(
  imageUrl: row['avatar_url'],
  name: row['name'],
)
```

#### Avatar List Cell (múltiplos avatares)
```dart
TableCellAvatarList(
  users: row['assigned_users'],
  maxVisible: 3,
)
```

#### Badge Cell
```dart
TableCellBadge(
  text: row['status'],
  color: _getStatusColor(row['status']),
)
```

#### Date Cell
```dart
TableCellDate(
  date: row['created_at'],
  format: 'dd/MM/yyyy HH:mm',
)
```

#### Text Cell
```dart
TableCellText(
  text: row['description'],
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

#### Updated By Cell (avatar + data)
```dart
TableCellUpdatedBy(
  user: row['updated_by'],
  date: row['updated_at'],
)
```

### User Components

#### User Avatar + Name
```dart
UserAvatarName(
  user: currentUser,
  size: 32,
  showName: true,
  onTap: () => _showUserProfile(currentUser),
)
```

---

## 🎨 Exemplos Completos

### Formulário Completo

```dart
class ProjectForm extends StatefulWidget {
  const ProjectForm({super.key});

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  final _dateController = TextEditingController();
  
  String? _selectedClientId;
  String? _selectedCompanyId;
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Nome do Projeto
          GenericTextField(
            controller: _nameController,
            label: 'Nome do Projeto',
            required: true,
          ),
          
          const SizedBox(height: 16),
          
          // Descrição
          GenericTextArea(
            controller: _descriptionController,
            label: 'Descrição',
            maxLines: 4,
          ),
          
          const SizedBox(height: 16),
          
          // Cliente (Async Dropdown)
          AsyncDropdownField<String>(
            label: 'Cliente',
            required: true,
            value: _selectedClientId,
            onChanged: (value) => setState(() => _selectedClientId = value),
            fetchItems: _fetchClients,
          ),
          
          const SizedBox(height: 16),
          
          // Empresa (Searchable Dropdown)
          SearchableDropdownField<String>(
            label: 'Empresa',
            value: _selectedCompanyId,
            onChanged: (value) => setState(() => _selectedCompanyId = value),
            items: _companies,
          ),
          
          const SizedBox(height: 16),
          
          // Valor
          GenericNumberField(
            controller: _valueController,
            label: 'Valor',
            prefix: 'R\$',
            decimals: 2,
          ),
          
          const SizedBox(height: 16),
          
          // Data de Entrega
          GenericDatePicker(
            controller: _dateController,
            label: 'Data de Entrega',
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          ),
          
          const SizedBox(height: 16),
          
          // Projeto Ativo
          GenericCheckbox(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value ?? true),
            label: 'Projeto Ativo',
          ),
          
          const SizedBox(height: 24),
          
          // Botões
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SecondaryButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                onPressed: _handleSave,
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<DropdownItem<String>>> _fetchClients() async {
    final response = await Supabase.instance.client
        .from('clients')
        .select('id, name')
        .order('name');
    
    return (response as List).map((item) {
      return DropdownItem<String>(
        value: item['id'],
        label: item['name'],
      );
    }).toList();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      // Salvar projeto
      print('Salvando projeto...');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}
```

### Card com Informações

```dart
class ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  
  const ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com Avatar e Nome
            Row(
              children: [
                CachedAvatar(
                  imageUrl: project['client']['avatar_url'],
                  name: project['client']['name'],
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['name'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        project['client']['name'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TableCellBadge(
                  text: project['status'],
                  color: _getStatusColor(project['status']),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Descrição
            if (project['description'] != null)
              TableCellText(
                text: project['description'],
                maxLines: 3,
              ),
            
            const SizedBox(height: 16),
            
            // Footer com Data e Usuários
            Row(
              children: [
                Expanded(
                  child: TableCellDate(
                    date: project['due_date'],
                    format: 'dd/MM/yyyy',
                  ),
                ),
                TableCellAvatarList(
                  users: project['assigned_users'],
                  maxVisible: 3,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlineButton(
                  onPressed: () => _handleEdit(project),
                  child: const Text('Editar'),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  onPressed: () => _handleView(project),
                  child: const Text('Ver Detalhes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
        return Colors.green;
      case 'pausado':
        return Colors.orange;
      case 'concluído':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _handleEdit(Map<String, dynamic> project) {
    // Implementar edição
  }

  void _handleView(Map<String, dynamic> project) {
    // Implementar visualização
  }
}
```

---

## 💡 Dicas de Uso

### 1. Sempre use o import único
```dart
// ✅ BOM
import 'package:gestor_projetos_flutter/ui/ui.dart';

// ❌ EVITE (a menos que precise de apenas um componente)
import 'package:gestor_projetos_flutter/ui/atoms/buttons/primary_button.dart';
```

### 2. Reutilize componentes
```dart
// ✅ BOM - Criar widget reutilizável
class SaveCancelButtons extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onCancel;
  
  const SaveCancelButtons({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SecondaryButton(onPressed: onCancel, child: const Text('Cancelar')),
        const SizedBox(width: 8),
        PrimaryButton(onPressed: onSave, child: const Text('Salvar')),
      ],
    );
  }
}
```

### 3. Combine atoms para criar molecules
```dart
// Exemplo: Campo de busca com botão
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  
  const SearchField({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GenericTextField(
            controller: controller,
            label: 'Buscar',
            hint: 'Digite para buscar...',
          ),
        ),
        const SizedBox(width: 8),
        IconButtonCustom(
          icon: Icons.search,
          onPressed: onSearch,
          tooltip: 'Buscar',
        ),
      ],
    );
  }
}
```

---

## 📚 Referências

- [README.md](README.md) - Documentação completa
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Guia de migração
- [ATOMIC_DESIGN_STATUS.md](ATOMIC_DESIGN_STATUS.md) - Status da migração

