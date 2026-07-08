<p align="center">
  <img src="https://github.com/user-attachments/assets/106afa2b-d0c8-4507-8444-199aeb1ff235" width="260"  alt="Banner Image" />
</p>

<pre align="center">
              __                            
  ____ ______/ /__________ ____  __  _______
 / __ `/ ___/ __/ ___/ __ `/ _ \/ / / / ___/
/ /_/ (__  ) /_/ /  / /_/ /  __/ /_/ (__  ) 
 \__,_/____/\__/_/   \__,_/\___/\__,_/____/  
</pre>

<p align="center">
  <img src="https://img.shields.io/github/stars/gxtontata/astraeus-obfuscator?style=flat-square" alt="Stars" />
  <img src="https://img.shields.io/github/forks/gxtontata/astraeus-obfuscator?style=flat-square" alt="Forks" />
  <img src="https://img.shields.io/github/issues/gxtontata/astraeus-obfuscator?style=flat-square" alt="Issues" />
  <img src="https://img.shields.io/github/license/gxtontata/astraeus-obfuscator?style=flat-square" alt="License" />
  <img src="https://img.shields.io/github/last-commit/gxtontata/astraeus-obfuscator?style=flat-square" alt="Last Commit" />
  <br>
</p>

---

**Astraeus** is a powerful Lua obfuscator designed to make your Lua code *nearly* impossible to reverse-engineer. By combining multiple layers of advanced obfuscation techniques, Astraeus ensures your scripts remain secure from prying eyes.

> [!CAUTION]
> **Obfuscation is not a foolproof method for protecting your code!** Always consider additional security measures depending on your use case.

> [!NOTE]
> Astraeus is actively under development (version `2.0.0`). While we strive for excellence, there may still be room for improvement. We are committed to making it one of the best obfuscators available.

---

## Features

Astraeus employs a wide arsenal of obfuscation techniques to protect your Lua scripts:

| Feature | Description |
| :--- | :--- |
| **String Encoding** | Transforms strings into indecipherable formats using an advanced Caesar Cipher variant. |
| **Variable Renaming** | Replaces original variable names with randomly generated identifiers to mask intent. |
| **Control Flow Obfuscation** | Introduces deceptive control flow structures to mislead static analysis tools. |
| **Garbage Code Insertion** | Injects meaningless code snippets to bloat scripts and complicate analysis. |
| **Bytecode Encoding** | Converts critical script sections into bytecode, adding a layer of complexity. |
| **Function Inlining** | Embeds function bodies directly into their call sites to disguise logic flow. |
| **Opaque Predicates** | Utilizes conditions that always evaluate to true/false, creating confusion about functionality. |
| **Dynamic Code Generator** | Generates code blocks dynamically from the script itself to hinder static analysis. |
| **String to Expressions** | Turns string literals into complex mathematical expressions. |
| **Virtual Machinery** | Employs a virtual machine environment to execute obfuscated code (supports opcode shuffling & superinstructions). |
| **Wrap In Function** | Encapsulates entire scripts within a function to obscure entry points. |
| **Anti Tamper** | Implements runtime integrity checks to block unauthorized overrides of core functions. |
| **Constant Encryption** | Encrypts numeric constants using XOR cipher with random keys to hide configuration values. |
| **String Splitting** | Splits strings into randomized fragments stored in shuffled tables and reassembles them at runtime. |
| **Environment Proxy** | Wraps global function references via encrypted proxy tables using metatables. |
| **Custom Virtual Machine v2** | Features opcode shuffling, XOR-encoded bytecode, superinstructions, and fully randomized internal variable names. |

> [!TIP]
> You can customize every module's behavior through the `config.lua` file.

---

## Installation & Usage

### Prerequisites
- **Lua 5.4** (Highly recommended)

### Installation
1. Clone the repository (or download the ZIP):
   ```bash
   git clone https://github.com/gxtontata/astraeus-obfuscator.git
   cd astraeus-obfuscator/src
   ```
2. Run the obfuscator on your script:
   ```bash
   lua astraeus.lua path/to/your/script.lua
   ```

### Basic Usage
To obfuscate a Lua script, run the following command from the `src/` directory:

```bash
lua astraeus.lua path/to/your/script.lua
```

**Output**: This generates `*_obfuscated.lua` in the same directory as the original script.

### Advanced Usage & Flags

| Flag | Description |
| :--- | :--- |
| `--overwrite` | Overwrites the original script instead of creating a new file. |
| `--light` / `--balanced` / `--heavy` / `--maximum` | Applies a predefined set of obfuscation modules. |
| `-c` / `--compressor` | Enables the Compressor module individually. |
| `--antitamper` / `--target luau` | Enables specific modules or targets Luau (Roblox) runtime. |

**Example**:
```bash
lua astraeus.lua my_script.lua --maximum
lua astraeus.lua my_script.lua -c --antitamper --target luau
```

---

## Adding a New Module

Astraeus is designed to be modular. To add a new obfuscation step to the pipeline and have it tested automatically, follow these steps:

### 1. Create the Module File
Create a new Lua file in `src/modules/` (e.g., `my_module.lua`). It must export a `process` function:

```lua
-- modules/my_module.lua
local M = {}

function M.process(code, some_option)
    -- Transform the code here
    return code
end

return M
```

### 2. Register It in `config.lua`
Add a default configuration entry under `settings`:

```lua
settings = {
    -- ... existing settings ...
    my_module = { enabled = false },  -- or true
},
```
*If your module has configurable parameters, add them here as well.*

### 3. Wire It Into `pipeline.lua`
- Add the `require` statement at the top:
  ```lua
  local MyModule = require("modules/my_module")
  ```
- Call it inside `Pipeline.process(code)` at the correct position:
  ```lua
  if config.get("settings.my_module.enabled") then
      local param = config.get("settings.my_module.some_parameter")
      code = MyModule.process(code, param)
  end
  ```

> [!IMPORTANT]
> **Order matters!** Later passes transform the output of earlier passes. Ensure your module is placed appropriately. Refer to `pipeline.lua` to determine the correct execution order.

### 4. Register It in `test.lua`
- Add the module name to `ALL_MODULES`:
  ```lua
  local ALL_MODULES = {
      "VirtualMachine",
      -- ... existing modules ...
      "my_module",
  }
  ```
- Map it to its config path in `MODULE_PATHS`:
  ```lua
  local MODULE_PATHS = {
      -- ... existing mappings ...
      my_module = "settings.my_module.enabled",
  }
  ```

### 5. Verify
Run the test suite to ensure everything works:

```bash
cd src
lua test.lua --quick --verbose
```

---

## Testing

Astraeus includes a comprehensive end-to-end test suite that verifies all valid module combinations against a realistic Lua fixture.

### Supported Targets

| Target | Supported Modules | Notes |
| :--- | :--- | :--- |
| **Lua 5.4** | 17/17 | Full support, including VirtualMachine and bytecode encoding. |
| **Luau** | 15/17 | VirtualMachine and bytecode encoding are disabled (incompatible). |

### Fast Parallel Sweep (Recommended)
Use the Python runner to test all combinations quickly across multiple worker processes:

```bash
# Full sweep with auto-detected workers (Lua target)
python3 test_py.py

# Explicitly specify worker count
python3 test_py.py --jobs 8

# Test for Luau target
python3 test_py.py --target luau

# Test both Lua and Luau
python3 test_py.py --target both
```

### Interactive Lua Test Runner
For quick checks and selective test groups:

```bash
# Quick mode: baseline + 14 singles + 64 core combos (~5 seconds)
lua test.lua --quick

# Full combination sweep (single process)
lua test.lua --test full_combinations --verbose

# Run all tests
lua test.lua --verbose

# Test a specific fixture
lua test.lua --test fixture_sweep_main_script --verbose

# Run only single module tests
lua test.lua --group single --verbose

# List all available tests
lua test.lua --list

# Show help
lua test.lua --help
```

> [!NOTE]
> All test commands must be executed from the `src/` directory.

---

## Support & Contact

- **Discord Bot**: [Invite Link](https://discord.com/oauth2/authorize?client_id=1293608330123804682)
- **Direct Contact**: `shitzusqualo` on Discord for any queries.

If you decide to use or fork Astraeus, please **star the repository** to show your support. It helps a lot!#