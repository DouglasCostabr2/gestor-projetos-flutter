/// Ponto de entrada central para todos os módulos do sistema
///
/// Este arquivo exporta todos os contratos e instâncias dos módulos.
/// É o ÚNICO ponto de acesso que as features devem usar para interagir
/// com a lógica de negócio.
library;
/// 
/// ARQUITETURA: Monolito Modular
/// - Cada módulo é isolado e se comunica apenas através de contratos (interfaces)
/// - Não há chamadas diretas entre módulos
/// - A comunicação é feita via chamadas de função (não rede)
/// - Facilita futura migração para microsserviços se necessário

// Auth Module
export 'auth/module.dart';

// Users Module
export 'users/module.dart';

// Clients Module
export 'clients/module.dart';

// Companies Module
export 'companies/module.dart';

// Projects Module
export 'projects/module.dart';

// Tasks Module
export 'tasks/module.dart';

// Catalog Module
export 'catalog/module.dart';

// Files Module
export 'files/module.dart';

// Comments Module
export 'comments/module.dart';

// Finance Module
export 'finance/module.dart';

// Products Module
export 'products/module.dart';

// Monitoring Module
export 'monitoring/module.dart';

// Time Tracking Module
export 'time_tracking/module.dart';

// Favorites Module
export 'favorites/module.dart';

// Notifications Module
export 'notifications/module.dart';

// Organizations Module
export 'organizations/module.dart';

// Audit Module
export 'audit/audit.dart';
