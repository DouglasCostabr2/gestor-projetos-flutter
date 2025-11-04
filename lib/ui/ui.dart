// UI Components - Atomic Design
//
// Este é o barrel file principal que exporta todos os componentes de UI
// organizados seguindo o padrão Atomic Design.
//
// Estrutura:
// - Atoms: Componentes básicos indivisíveis (botões, inputs, avatares)
// - Molecules: Combinações simples de átomos (dropdowns, table cells)
// - Organisms: Componentes complexos (navigation, tables, editors, sections)
// - Templates: Layouts de página reutilizáveis
//
// Hierarquia de Dependências:
// Pages → Templates → Organisms → Molecules → Atoms
//
// Boas Práticas:
// - Prefira importar este arquivo em vez de imports individuais
// - Atoms não devem importar molecules ou organisms
// - Molecules não devem importar organisms
// - Mantenha componentes simples e reutilizáveis

// Atoms - Componentes básicos
export 'atoms/atoms.dart';

// Molecules - Combinações simples
export 'molecules/molecules.dart';

// Organisms - Componentes complexos
export 'organisms/organisms.dart';

// Templates - Layouts de página
export 'templates/templates.dart';

