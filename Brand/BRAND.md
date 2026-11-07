# Foteka — Identidade visual V2

**Aprovada: Layer · Coleções**. O símbolo usa três fotografias sobrepostas em verde-petróleo/turquesa, com uma montanha e um sol brancos.

## Paleta de marca

| Papel | Cor |
|---|---|
| Verde-petróleo | `#007B6E` |
| Verde profundo | `#005750` |
| Turquesa | `#11D7B8` |
| Verde-lima | `#78DD2C` |
| Fundo claro | `#F8F7F3` |
| Superfície | `#FFFEFC` |
| Títulos | `#18333B` |

## Como gerar o ícone iOS

```bash
python3 -m pip install cairosvg
python3 scripts/generate_brand_assets.py
xcodegen generate
```

O gerador exporta um PNG opaco 1024×1024 e o `Contents.json` para `App/Assets.xcassets/AppIcon.appiconset`. O workflow CI executa esse processo em macOS e Linux; a fonte vetorial permanece editável em `Brand/FotekaLayerIcon.svg`.

**Nome apresentado:** Foteka. **Linha de produto:** Visual Collections. Nome interno de target, bundle IDs e repositório continuam OrgaIA, para manter compatibilidade com App Groups e a Share Extension.

Não reproduzir nos apps contagens ou percentuais fictícios dos mockups. As fotos e imagens reais permanecem com proporção preservada.
