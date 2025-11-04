import 'package:flutter/material.dart';

/// Gerenciador de TextEditingControllers para formulários
/// 
/// Facilita o gerenciamento de múltiplos controllers:
/// - Criação automática baseada em lista de IDs
/// - Dispose automático de todos os controllers
/// - Métodos para obter/setar valores
/// - Conversão para/de Maps
class FormControllerManager {
  final Map<String, TextEditingController> _controllers = {};

  /// Cria controllers para uma lista de field IDs
  void createControllers(List<String> fieldIds, {Map<String, String>? initialValues}) {
    for (var fieldId in fieldIds) {
      if (!_controllers.containsKey(fieldId)) {
        final initialValue = initialValues?[fieldId] ?? '';
        _controllers[fieldId] = TextEditingController(text: initialValue);
      }
    }
  }

  /// Atualiza controllers existentes com novos valores
  void updateControllers(Map<String, String> values) {
    for (var entry in values.entries) {
      final controller = _controllers[entry.key];
      if (controller != null) {
        controller.text = entry.value;
      }
    }
  }

  /// Recria todos os controllers com novos field IDs e valores
  void recreateControllers(List<String> fieldIds, {Map<String, String>? initialValues}) {
    // Dispose dos controllers antigos
    disposeAll();
    
    // Criar novos controllers
    createControllers(fieldIds, initialValues: initialValues);
  }

  /// Obtém um controller específico
  TextEditingController? getController(String fieldId) {
    return _controllers[fieldId];
  }

  /// Obtém todos os controllers
  Map<String, TextEditingController> getAllControllers() {
    return Map.unmodifiable(_controllers);
  }

  /// Obtém o valor de um campo específico
  String getValue(String fieldId) {
    return _controllers[fieldId]?.text.trim() ?? '';
  }

  /// Define o valor de um campo específico
  void setValue(String fieldId, String value) {
    _controllers[fieldId]?.text = value;
  }

  /// Obtém todos os valores como Map (apenas campos não vazios)
  Map<String, String> getValues({bool includeEmpty = false}) {
    final values = <String, String>{};
    for (var entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (includeEmpty || value.isNotEmpty) {
        values[entry.key] = value;
      }
    }
    return values;
  }

  /// Define múltiplos valores de uma vez
  void setValues(Map<String, String> values) {
    for (var entry in values.entries) {
      setValue(entry.key, entry.value);
    }
  }

  /// Limpa todos os campos
  void clearAll() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
  }

  /// Limpa campos específicos
  void clearFields(List<String> fieldIds) {
    for (var fieldId in fieldIds) {
      _controllers[fieldId]?.clear();
    }
  }

  /// Verifica se um campo existe
  bool hasField(String fieldId) {
    return _controllers.containsKey(fieldId);
  }

  /// Verifica se todos os campos estão vazios
  bool get isEmpty {
    return _controllers.values.every((controller) => controller.text.trim().isEmpty);
  }

  /// Verifica se algum campo tem valor
  bool get isNotEmpty {
    return _controllers.values.any((controller) => controller.text.trim().isNotEmpty);
  }

  /// Número de controllers gerenciados
  int get length => _controllers.length;

  /// Dispose de um controller específico
  void disposeController(String fieldId) {
    _controllers[fieldId]?.dispose();
    _controllers.remove(fieldId);
  }

  /// Dispose de múltiplos controllers
  void disposeControllers(List<String> fieldIds) {
    for (var fieldId in fieldIds) {
      disposeController(fieldId);
    }
  }

  /// Dispose de todos os controllers
  void disposeAll() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  /// Adiciona um listener a um campo específico
  void addListener(String fieldId, VoidCallback listener) {
    _controllers[fieldId]?.addListener(listener);
  }

  /// Remove um listener de um campo específico
  void removeListener(String fieldId, VoidCallback listener) {
    _controllers[fieldId]?.removeListener(listener);
  }

  /// Adiciona um listener a todos os campos
  void addListenerToAll(VoidCallback listener) {
    for (var controller in _controllers.values) {
      controller.addListener(listener);
    }
  }

  /// Remove um listener de todos os campos
  void removeListenerFromAll(VoidCallback listener) {
    for (var controller in _controllers.values) {
      controller.removeListener(listener);
    }
  }

  @override
  String toString() {
    return 'FormControllerManager(fields: ${_controllers.keys.length}, values: ${getValues()})';
  }
}

/// Extension para facilitar o uso com listas de campos
extension FormControllerManagerExtension on FormControllerManager {
  /// Cria controllers a partir de uma lista de objetos com propriedade 'id'
  void createControllersFromFields<T>(
    List<T> fields,
    String Function(T) idExtractor, {
    Map<String, String>? initialValues,
  }) {
    final fieldIds = fields.map(idExtractor).toList();
    createControllers(fieldIds, initialValues: initialValues);
  }

  /// Recria controllers a partir de uma lista de objetos com propriedade 'id'
  void recreateControllersFromFields<T>(
    List<T> fields,
    String Function(T) idExtractor, {
    Map<String, String>? initialValues,
  }) {
    final fieldIds = fields.map(idExtractor).toList();
    recreateControllers(fieldIds, initialValues: initialValues);
  }
}

