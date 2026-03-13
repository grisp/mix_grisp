# Current CLI Flow

This document describes the current `mix grisp.configure` flow as implemented in
`mix_grisp`.

## Main Flow

```mermaid
flowchart TD
    A["mix grisp.configure"] --> B["OptionParser.parse/2"]
    B --> C["MixGrisp.Configure.run/2"]
    C --> D["merge defaults + CLI opts"]
    D --> E["normalize booleans + strings"]
    E --> F{"interactive?"}

    F -->|yes| G["Prompter.maybe_prompt/2"]
    F -->|no| H["default network_type = ethernet when network=true"]

    G --> I["Validator.validate!/1"]
    H --> I["Validator.validate!/1"]

    I --> J["TemplatePlan.build/1"]
    J --> K["Renderer.apply/3"]
    I --> L["MixExsPatcher.apply/2"]
    I --> M["ConfigPatcher.apply/2"]

    K --> N["created / skipped files"]
    L --> O["mix.exs updated or manual steps"]
    M --> P["config/config.exs updated or manual steps"]

    N --> Q["task prints results"]
    O --> Q
    P --> Q
```

## Interactive Branch

```mermaid
flowchart TD
    A["Prompter.maybe_prompt/2"] --> B["name"]
    B --> C["network?"]
    C -->|true| D["network_type: ethernet or wifi"]
    C -->|false| E["skip network-specific prompts"]
    D -->|wifi| F["ssid"]
    F --> G["psk"]
    D -->|ethernet| H["skip wifi details"]
    G --> I["grisp_io?"]
    H --> I["grisp_io?"]
    E --> I["grisp_io?"]
    I -->|true| J["grisp_io_linking?"]
    J -->|true| K["token"]
    J -->|false| L["continue"]
    K --> L
    I -->|false| L
    L --> M["epmd?"]
    M -->|true| N["node_name"]
    N --> O["cookie"]
    M -->|false| P["done"]
    O --> P
```

## Generated Files

```mermaid
flowchart TD
    A["validated config"] --> B{"network?"}
    A --> C["config/config.exs"]

    B -->|true| D["grisp.ini.mustache"]
    B -->|false| E["no network files"]

    D --> F{"network_type == wifi?"}
    F -->|yes| G["wpa_supplicant.conf"]
    F -->|no| H["no wpa_supplicant.conf"]

    D --> I{"grisp_io?"}
    I -->|false| J["erl_inetrc"]
    I -->|true| K["no erl_inetrc"]
```

## Patchers

```mermaid
flowchart LR
    A["validated config"] --> B["MixExsPatcher"]
    A --> C["ConfigPatcher"]

    B --> D["project/0"]
    B --> E["deps/0"]
    B --> F["application/0"]
    B --> G["grisp/0 + releases/0 helpers"]

    C --> H["append GRiSP.io runtime config"]
    C --> I["device_linking_token when linking"]
```

## Module Map

- [`lib/mix/tasks/grisp/configure.ex`](../lib/mix/tasks/grisp/configure.ex)
  CLI entrypoint and result printing
- [`lib/mix_grisp/configure.ex`](../lib/mix_grisp/configure.ex)
  orchestration
- [`lib/mix_grisp/configure/prompter.ex`](../lib/mix_grisp/configure/prompter.ex)
  interactive prompts
- [`lib/mix_grisp/configure/validator.ex`](../lib/mix_grisp/configure/validator.ex)
  config validation
- [`lib/mix_grisp/configure/template_plan.ex`](../lib/mix_grisp/configure/template_plan.ex)
  file selection
- [`lib/mix_grisp/configure/renderer.ex`](../lib/mix_grisp/configure/renderer.ex)
  file rendering/copying
- [`lib/mix_grisp/configure/mix_exs_patcher.ex`](../lib/mix_grisp/configure/mix_exs_patcher.ex)
  conservative `mix.exs` patching
- [`lib/mix_grisp/configure/config_patcher.ex`](../lib/mix_grisp/configure/config_patcher.ex)
  conservative `config/config.exs` patching
- [`lib/mix_grisp/configure/snippets.ex`](../lib/mix_grisp/configure/snippets.ex)
  shared snippets and manual-step text
