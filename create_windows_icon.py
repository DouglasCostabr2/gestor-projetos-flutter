#!/usr/bin/env python3
"""
Script para criar o ícone do Windows usando o arquivo ICON SEM FUNDO
"""

from PIL import Image
import os

def create_windows_icon():
    """
    Cria o ícone do Windows (.ico) a partir do arquivo ICON SEM FUNDO
    """
    
    # Caminho do ícone sem fundo
    source_icon = 'C:/Users/PC/Downloads/logo my business ICON SEM FUNDO.png'
    
    print('🎨 Criando ícone do Windows...\n')
    
    try:
        # Abrir a imagem original
        img = Image.open(source_icon)
        print(f'✅ Ícone carregado: {img.size[0]}x{img.size[1]} pixels')
        print(f'   Modo: {img.mode}')
        
        # Criar ícone ICO para Windows com múltiplos tamanhos
        create_ico_from_image(img, 'windows/runner/resources/app_icon.ico')
        
        print('\n✨ Ícone do Windows criado com sucesso!')
        print('📝 Arquivo: logo my business ICON SEM FUNDO.png')
        print('📝 Ícone sem fundo para melhor visualização no Windows')
        
        return True
        
    except Exception as e:
        print(f'❌ Erro ao processar ícone: {e}')
        import traceback
        traceback.print_exc()
        return False

def create_ico_from_image(img, ico_path):
    """
    Converte imagem para ICO com múltiplos tamanhos
    Mantém a transparência para ícones sem fundo
    """
    sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    icons = []

    for size in sizes:
        resized = img.resize(size, Image.Resampling.LANCZOS)
        # Manter o modo RGBA para preservar transparência
        icons.append(resized)

    # Salvar como ICO mantendo transparência
    icons[0].save(ico_path, format='ICO', sizes=sizes)
    print(f'✅ Ícone ICO criado: {ico_path}')
    print(f'   Tamanhos incluídos: 16x16, 32x32, 48x48, 64x64, 128x128, 256x256')
    print(f'   ✨ Transparência preservada!')

if __name__ == '__main__':
    create_windows_icon()

