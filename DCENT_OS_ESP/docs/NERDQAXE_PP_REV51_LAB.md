# NerdQaxe++ Rev 5.1 lab build

This is a first-build guide for the NerdQaxe++ marked **Rev 5.1**. In this source tree, the `nerdqaxe-pp` feature is registered as a four-chip BM1370 target. It is still an internal, experimental, lab-only target. The target registry retains the revision-identity, first-article, accepted-share, thermal-fault, OTA-rollback, and sustained-soak blockers; identifying the PCB silkscreen does not close those qualification gates.

The feature selects the Nerd-family pin map and TPS5364x power driver. It also selects `display-none`, so the onboard display is not supported by this build; configure and monitor it through the web UI. The first preset to use for hardware bring-up is **Low Power** (400 MHz / 1150 mV). Do not start with the 525 MHz / 1200 mV Default preset; the source marks it as requiring overclock.

## WSL 2 / Ubuntu build

The Windows host already has WSL 2 with Ubuntu installed. Start it from PowerShell:

```powershell
wsl -d Ubuntu
```

Run the remaining commands inside the Ubuntu shell. Keep the source and build output in the Linux home directory (for example, `~/src` and `~/nqpp-build`), not under `/mnt/c`; this avoids slow cross-filesystem build traffic and keeps ESP-IDF paths short.

Install the host packages:

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build clang llvm-dev libclang-dev \
  libudev-dev libuv1-dev pkg-config python3 python3-venv python3-pip git curl \
  libssl-dev libusb-1.0-0
```

If `rustup` is not installed in Ubuntu, install it using the official installer, then initialize it in the current shell. Windows Rust installs are separate from WSL installs.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
cargo install espup --locked
espup install --targets esp32s3
source "$HOME/export-esp.sh"
```

Clone the fork branch into the Linux filesystem and build just the NerdQaxe++ target:

```bash
mkdir -p ~/src
cd ~/src
git clone -b lab/nerdqaxe-pp-rev51 https://github.com/yumtech-mining/DCENT_OS.git
cd DCENT_OS/DCENT_OS_ESP
bash scripts/build-nerdqaxe-pp.sh
```

In each new Ubuntu terminal, run `source "$HOME/export-esp.sh"` before building. The helper defaults the build output to `~/nqpp-build`; set `CARGO_TARGET_DIR` first if you want a different Linux-side directory.

After a successful build, the ELF is at `~/nqpp-build/xtensa-esp32s3-espidf/release/dcentaxe`. WSL can compile the firmware, but USB flashing through the Windows COM5 port remains a separate step. The helper does not package or flash the device.

## Windows toolchain

Install Git, Python 3, and Rust with `rustup`. Then install the Espressif Xtensa toolchain for ESP32-S3. The repository pins the Rust toolchain name to `esp` and ESP-IDF to v5.4 in `.cargo/config.toml`.

In PowerShell, install `espup` using its Windows release and set up the ESP32-S3 toolchain:

```powershell
Invoke-WebRequest 'https://github.com/esp-rs/espup/releases/latest/download/espup-x86_64-pc-windows-msvc.exe' -OutFile "$env:TEMP\espup.exe"
& "$env:TEMP\espup.exe" install --targets esp32s3
```

Open a new PowerShell window after installation so the toolchain environment is available. The `esp-idf-sys` build uses the repository's ESP-IDF v5.4 setting.

## Build only this target

From the repository root (`DCENT_OS`):

```powershell
Set-Location .\DCENT_OS_ESP
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-nerdqaxe-pp.ps1
```

The script validates the target registry and refuses to build if `nerdqaxe-pp` no longer maps to four BM1370 chips or is no longer marked internal/lab-only. It builds only that Cargo feature and writes the ELF under `C:\bt\nerdqaxe-pp-rev51\xtensa-esp32s3-espidf\release\dcentaxe` by default. Pass `-CargoTargetDir C:\bt\nqpp` to choose another short build directory.

This is a compile step only. It does not create a factory image, change release policy, or flash the miner. Do not feed the ELF to a tool expecting a `.bin` file. The public DCENT Toolbox install route intentionally refuses internal targets.

## Before first power-up and mining test

Keep the working NerdOS v1.1.0.1 recovery path available. For a later lab flash, use only a board-specific factory image after checking the complete factory flash map and the board's actual flash size. On first boot, verify all four ASICs, the expected power controller and rail readings, fan operation, plausible temperatures, and web UI access before connecting a pool.

Use the Low Power preset for initial checks. Verify that the miner submits and receives accepted shares, test thermal fault handling and recovery/rollback, and complete a sustained soak before treating the image as usable. Do not rely on the onboard display. If using a pool that already charges a 2% fee, check DCENT's own donation setting in the UI so fees are not unintentionally stacked.
