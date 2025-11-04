/// Módulo de organizações - Singleton global
library;

import 'contract.dart';
import 'repository.dart';

/// Instância global do módulo de organizações
final OrganizationsContract organizationsModule = OrganizationsRepository();

