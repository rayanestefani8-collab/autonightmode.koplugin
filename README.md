# 🌙 autonightmode.koplugin

Plugin for [KOReader](https://github.com/koreader/koreader) that
automatically enables and disables night mode at configurable times,
with support for light temperature and brightness control.

------------------------------------------------------------------------

## ✨ Features

-   **Automatic scheduling** do modo noturno por horário
    (ex: liga às 20:00, desliga às 07:00)
-   **Support for schedules that cross midnight** (ex: 22:00
    → 06:00)
-   **Light temperature control** (warmth) separado para
    período noturno e diurno --- apenas em dispositivos com luz quente
-   **Brightness control** separado para noite e dia ---
    opcional
-   **Does not interfere** em outras configurações do
    KOReader (cor de papel, tema de UI, etc.)
-   **Compatible with any launcher**: SimpleUI, ZenUI,
    FileManager padrão, etc.
-   **Compatible with any device**: detecta com segurança se
    o hardware suporta luz quente ou frontlight antes de tentar usá-los
-   Menu available at **Configurações → Tela → Auto Night Mode**
-   Settings saved in a dedicated file (`autonightmode.lua`), separado
    do `G_reader_settings`

------------------------------------------------------------------------

## 📦 Installation

1.  Download or clone this repository

2.  Copy the folder `autonightmode.koplugin/` para o diretório de
    plugins do KOReader:

        koreader/plugins/autonightmode.koplugin/

3.  Restart KOReader

4.  Go to **⚙️ → Tela → Auto Night Mode** para configurar

> **Note:** If the plugin does not appear, check in **⚙️ → Mais
> ferramentas → Gerenciamento de plugins** whether it is enabled.

------------------------------------------------------------------------

## ⚙️ Configuration

All options are available in **Configurações → Tela → Auto Night Mode**:

  -----------------------------------------------------------------------
  Opção                               Description
  ----------------------------------- -----------------------------------
  Agendamento: ativado/desativado     Enables or disables automatic operation

  Liga o modo noturno às              Time when night mode is enabled

  Desliga o modo noturno às          Time when night mode is disabled

  Temperatura noturna / diurna       Warmth level for each period (0 = cold, 100 = warm). 
                                     Value -1 = do not change. Only shown on devices with warm light.

  Brilho noturno / diurno            Brightness level for each period (0–100%). 
                                     Value -1 = do not change. Only shown on devices with frontlight.

  Notificações                        Displays a brief message when switching modes.

  Aplicar agora                       Forces a check and immediately applies the correct mode.

  Estado agora                       Displays the current period and the configured schedule.
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 🔧 Compatibility

Tested on: - **Kobo Libra Colour** com KOReader v2026.03 e SimpleUI -
**Kindle 10ª geração** com KOReader

It should work on any device supported by KOReader. O plugin usa `pcall`
para detectar com segurança as capacidades do hardware --- em
dispositivos sem luz quente ou sem frontlight, as opções correspondentes
simplesmente não aparecem no menu, sem erros.

APIs utilizadas: - `self.ui:handleEvent(Event:new("SetNightMode", ...))`
para aplicar o modo noturno via `DeviceListener` (caminho oficial do
KOReader) - `G_reader_settings` para leitura do estado atual -
`Device:getPowerDevice()` para warmth e brilho

------------------------------------------------------------------------

## 📁 Structure

    autonightmode.koplugin/
    ├── main.lua      # Main plugin logic
    └── _meta.lua     # Metadata (name, version, author)

------------------------------------------------------------------------

## 🤝 Credits

Plugin developed in collaboration between the repository author and
[Claude](https://claude.ai) (Anthropic) --- modelo Claude Sonnet 4.6.

The idea was inspired by the auto night mode module of
[zen_ui.koplugin](https://github.com/AnthonyGress/zen_ui.koplugin) de
Anthony Gress.

------------------------------------------------------------------------

## 📄 License

MIT License --- see the `LICENSE` file for details.
