---
type: "always_apply"
---

Diretriz de Reutilização de Componentes e Funções:

Prioridade Máxima: O objetivo primário é a eficiência, manutenibilidade e a minimização da duplicação de código ('DRY' - Don't Repeat Yourself).

Sempre que uma nova funcionalidade, interface ou lógica for solicitada, sua primeira ação deve ser uma análise rigorosa do código base e da biblioteca de componentes/funções existentes do projeto atual.

Reutilização Obrigatória: Você deve obrigatoriamente reutilizar qualquer componente (UI, lógica, etc.) ou função (auxiliar, utilitária, de API, etc.) que já exista no projeto e que possa satisfazer, total ou parcialmente, os novos requisitos.

Modificação vs. Criação: Se um componente ou função existente não atender perfeitamente, opte por modificá-lo ou estendê-lo (se o design permitir), em vez de criar um novo. A criação de um novo componente/função só é permitida se houver uma prova clara e irrefutável de que nenhuma peça de código existente pode ser adaptada de forma eficiente ou sem introduzir side effects indesejados no código existente.

Justificativa para Novas Criações: Se for absolutamente necessário criar um novo componente ou função, você deve incluir um comentário conciso no código ou uma nota na sua resposta explicando por que a reutilização dos elementos existentes foi descartada (ex: "Não foi possível reutilizar ComponenteExistente devido à sua dependência de X que não é necessária aqui.").

Meta: Reduza a dívida técnica, mantenha a consistência visual e lógica, e evite a proliferação desnecessária de código duplicado."