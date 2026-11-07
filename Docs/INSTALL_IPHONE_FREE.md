# Foteka — instalar no iPhone sem Mac (conta Apple gratuita)

## Qual versão usar?

O workflow [Foteka — iPhone device IPA (unsigned)](../.github/workflows/ios-device-ipa.yml) gera dois arquivos com binários reais **iphoneos arm64**, não de simulador:

| Arquivo | Recursos | Requisitos |
|---|---|---|
| `Foteka-Free-unsigned.ipa` | Galeria, Vision (IA local), OCR, álbuns PhotoKit, regras e App Intents/Atalhos (a validar no aparelho) | Assinatura de desenvolvimento para o iPhone com uma conta Apple gratuita, por exemplo via AltStore Classic |
| `Foteka-Full-unsigned.ipa` | Tudo acima, mais Share Extension e App Group para fila compartilhada | Assinatura e perfil de provisionamento que incluam o App Group dos dois targets; normalmente exige conta do Apple Developer Program |

A edição Free preserva o bundle ID `br.com.orgaia.gallery`. Ela **não possui Share Extension** nem capacidade de receber automaticamente arquivos de outros apps por acesso à sua pasta privada. Para testar, salve imagens no Fotos e use a análise da Galeria. A ação do Atalhos utiliza a pasta local do app e deverá ser testada em dispositivo real.

## GitHub Actions → Arquivo .ipa

1. Acesse **Actions → Foteka — iPhone device IPA (unsigned)**.
2. Abra a execução com sucesso, baixe o artefato **Foteka-iPhone-unsigned-IPA**.
3. Extraia o ZIP de artifacts. Para uma conta Apple gratuita, escolha `Foteka-Free-unsigned.ipa`.

**Importante:** um IPA sem assinatura não é instalável ao tocá-lo no iPhone. É necessário assiná-lo com uma conta Apple e associá-lo ao dispositivo.

## Instalação usando Windows e AltStore Classic

1. Instale o AltServer a partir da página oficial: https://altstore.io/ (instruções: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
2. Instale os componentes Apple para Windows indicados pelo AltStore e conecte o iPhone ao computador, desbloqueando e confirmando a confiança.
3. Instale o AltStore Classic no iPhone com o AltServer. Ative o **Modo de Desenvolvedor** em Ajustes → Privacidade e Segurança caso o iOS solicite.
4. Com AltServer executando, abra o AltStore no iPhone, na aba **My Apps**, toque no botão **+**, selecione `Foteka-Free-unsigned.ipa` e siga o fluxo de assinatura.
5. Autorize o app quando o iOS solicitar e conceda acesso à biblioteca de Fotos para testar a análise e a criação de álbuns.

Com conta gratuita, a Apple limita a 3 apps de desenvolvimento instalados por dispositivo, até 10 App IDs e perfis que vencem após 7 dias. O AltStore pode renovar apps enquanto o AltServer estiver disponível; não há instalação permanente. Links de referência: https://developer.apple.com/help/account/basics/about-your-developer-account/ e https://faq.altstore.io/altstore-classic/your-altstore.

## Limitações e segurança

- **Apenas iPhone, sem computador e sem assinatura Apple Developer paga:** não há um caminho oficial geral para instalar um IPA próprio e não assinado diretamente do Safari/Arquivos. O primeiro provisionamento gratuito normalmente exige apoio de computador.
- **Não envie sua senha Apple, certificados privados nem chaves de assinatura ao GitHub ou nesta conversa.**
- A compilação e os testes XCTest no simulador são diferentes de um teste de instalação e de permissão do Fotos em um iPhone físico.
- Não usamos TestFlight, App Store nem distribuição por OTA; essas etapas exigem um programa Apple Developer e configuração de assinatura adequada.
- A versão Free usa armazenamento privado em Application Support, em vez de App Groups. O fluxo da Share Extension só existe na versão Full.
- Sem garantia de que todas as versões do iOS aceitem as mesmas ferramentas de assinatura de terceiros; valide com a documentação oficial atualizada.

## Verificação objetiva de release

```
unzip -tq Foteka-Free-unsigned.ipa
unzip -l Foteka-Free-unsigned.ipa | grep 'Payload/OrgaIA.app/Info.plist'
```

O workflow confirma a presença do binário de dispositivo, do Info.plist, dos metadados da extensão no Full e a **ausência da extensão no Free**. Ambos continuam **sem assinatura**, mesmo depois de passar nesses testes.
