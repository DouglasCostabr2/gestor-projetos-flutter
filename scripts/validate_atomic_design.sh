#!/bin/bash

# Script de Validação da Estrutura Atomic Design
# Verifica se a estrutura está correta e se as regras estão sendo seguidas

echo "🔍 Validando Estrutura Atomic Design..."
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
ERRORS=0
WARNINGS=0
SUCCESS=0

# Função para imprimir erro
error() {
    echo -e "${RED}❌ ERRO:${NC} $1"
    ((ERRORS++))
}

# Função para imprimir warning
warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    ((WARNINGS++))
}

# Função para imprimir sucesso
success() {
    echo -e "${GREEN}✅${NC} $1"
    ((SUCCESS++))
}

# Função para imprimir info
info() {
    echo -e "${BLUE}ℹ️${NC}  $1"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Verificando Estrutura de Pastas"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar se lib/ui existe
if [ -d "lib/ui" ]; then
    success "Pasta lib/ui/ existe"
else
    error "Pasta lib/ui/ não encontrada"
fi

# Verificar atoms
if [ -d "lib/ui/atoms" ]; then
    success "Pasta lib/ui/atoms/ existe"
    
    # Verificar subpastas de atoms
    for folder in buttons inputs avatars; do
        if [ -d "lib/ui/atoms/$folder" ]; then
            success "  - lib/ui/atoms/$folder/ existe"
        else
            warning "  - lib/ui/atoms/$folder/ não encontrada"
        fi
    done
else
    error "Pasta lib/ui/atoms/ não encontrada"
fi

# Verificar molecules
if [ -d "lib/ui/molecules" ]; then
    success "Pasta lib/ui/molecules/ existe"
    
    # Verificar subpastas de molecules
    for folder in dropdowns table_cells; do
        if [ -d "lib/ui/molecules/$folder" ]; then
            success "  - lib/ui/molecules/$folder/ existe"
        else
            warning "  - lib/ui/molecules/$folder/ não encontrada"
        fi
    done
else
    error "Pasta lib/ui/molecules/ não encontrada"
fi

# Verificar organisms
if [ -d "lib/ui/organisms" ]; then
    success "Pasta lib/ui/organisms/ existe"
else
    warning "Pasta lib/ui/organisms/ não encontrada (esperado se ainda não migrado)"
fi

# Verificar templates
if [ -d "lib/ui/templates" ]; then
    success "Pasta lib/ui/templates/ existe"
else
    warning "Pasta lib/ui/templates/ não encontrada"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Verificando Barrel Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar barrel file principal
if [ -f "lib/ui/ui.dart" ]; then
    success "lib/ui/ui.dart existe"
else
    error "lib/ui/ui.dart não encontrado"
fi

# Verificar barrel files de categorias
if [ -f "lib/ui/atoms/atoms.dart" ]; then
    success "lib/ui/atoms/atoms.dart existe"
else
    error "lib/ui/atoms/atoms.dart não encontrado"
fi

if [ -f "lib/ui/molecules/molecules.dart" ]; then
    success "lib/ui/molecules/molecules.dart existe"
else
    error "lib/ui/molecules/molecules.dart não encontrado"
fi

if [ -f "lib/ui/organisms/organisms.dart" ]; then
    success "lib/ui/organisms/organisms.dart existe"
else
    warning "lib/ui/organisms/organisms.dart não encontrado"
fi

if [ -f "lib/ui/templates/templates.dart" ]; then
    success "lib/ui/templates/templates.dart existe"
else
    warning "lib/ui/templates/templates.dart não encontrado"
fi

# Verificar barrel files de atoms
for file in buttons.dart inputs.dart avatars.dart; do
    folder="${file%.dart}"
    if [ -f "lib/ui/atoms/$folder/$file" ]; then
        success "lib/ui/atoms/$folder/$file existe"
    else
        warning "lib/ui/atoms/$folder/$file não encontrado"
    fi
done

# Verificar barrel files de molecules
for file in dropdowns.dart table_cells.dart; do
    folder="${file%.dart}"
    if [ -f "lib/ui/molecules/$folder/$file" ]; then
        success "lib/ui/molecules/$folder/$file existe"
    else
        warning "lib/ui/molecules/$folder/$file não encontrado"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Verificando Documentação"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in README.md MIGRATION_GUIDE.md ATOMIC_DESIGN_STATUS.md EXAMPLES.md BEST_PRACTICES.md; do
    if [ -f "lib/ui/$file" ]; then
        success "lib/ui/$file existe"
    else
        warning "lib/ui/$file não encontrado"
    fi
done

if [ -f "CHANGELOG_ATOMIC_DESIGN.md" ]; then
    success "CHANGELOG_ATOMIC_DESIGN.md existe"
else
    warning "CHANGELOG_ATOMIC_DESIGN.md não encontrado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Contando Componentes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Contar atoms
if [ -d "lib/ui/atoms" ]; then
    ATOMS_COUNT=$(find lib/ui/atoms -name "*.dart" ! -name "*_test.dart" ! -name "*.g.dart" ! -name "atoms.dart" ! -name "buttons.dart" ! -name "inputs.dart" ! -name "avatars.dart" | wc -l)
    info "Atoms encontrados: $ATOMS_COUNT"
fi

# Contar molecules
if [ -d "lib/ui/molecules" ]; then
    MOLECULES_COUNT=$(find lib/ui/molecules -name "*.dart" ! -name "*_test.dart" ! -name "*.g.dart" ! -name "molecules.dart" ! -name "dropdowns.dart" ! -name "table_cells.dart" | wc -l)
    info "Molecules encontrados: $MOLECULES_COUNT"
fi

# Contar organisms
if [ -d "lib/ui/organisms" ]; then
    ORGANISMS_COUNT=$(find lib/ui/organisms -name "*.dart" ! -name "*_test.dart" ! -name "*.g.dart" ! -name "organisms.dart" 2>/dev/null | wc -l)
    info "Organisms encontrados: $ORGANISMS_COUNT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Verificando Imports Deprecated"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar se ainda há imports antigos em lib/src/features
DEPRECATED_IMPORTS=$(grep -r "package:gestor_projetos_flutter/widgets/buttons/buttons.dart" lib/src/features 2>/dev/null | wc -l)
if [ "$DEPRECATED_IMPORTS" -gt 0 ]; then
    warning "Encontrados $DEPRECATED_IMPORTS imports deprecated de buttons"
else
    success "Nenhum import deprecated de buttons encontrado"
fi

DEPRECATED_IMPORTS=$(grep -r "package:gestor_projetos_flutter/widgets/inputs/inputs.dart" lib/src/features 2>/dev/null | wc -l)
if [ "$DEPRECATED_IMPORTS" -gt 0 ]; then
    warning "Encontrados $DEPRECATED_IMPORTS imports deprecated de inputs"
else
    success "Nenhum import deprecated de inputs encontrado"
fi

DEPRECATED_IMPORTS=$(grep -r "package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart" lib/src/features 2>/dev/null | wc -l)
if [ "$DEPRECATED_IMPORTS" -gt 0 ]; then
    warning "Encontrados $DEPRECATED_IMPORTS imports deprecated de dropdowns"
else
    success "Nenhum import deprecated de dropdowns encontrado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Verificando Compilação"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Executando flutter analyze..."
ANALYZE_OUTPUT=$(flutter analyze lib/ui/ 2>&1)

# Verificar se há erros reais (não apenas warnings/info)
ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "error -" || true)
WARNING_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "info -" || true)

if [ $ERROR_COUNT -eq 0 ]; then
    success "lib/ui/ compila sem erros"
    if [ $WARNING_COUNT -gt 0 ]; then
        info "Encontrados $WARNING_COUNT warnings (não críticos)"
    fi
else
    error "lib/ui/ tem $ERROR_COUNT erros de compilação"
    echo "$ANALYZE_OUTPUT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo -e "${GREEN}✅ Sucessos:${NC} $SUCCESS"
echo -e "${YELLOW}⚠️  Warnings:${NC} $WARNINGS"
echo -e "${RED}❌ Erros:${NC} $ERRORS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ VALIDAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ VALIDAÇÃO FALHOU - Corrija os erros acima${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi

