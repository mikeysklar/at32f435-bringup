# source this on bravo before building anything AT32
export PATH=$HOME/arm-toolchain/bin:$HOME/.cargo/bin:$HOME/.local/openocd-at32/bin:$HOME/.local/bin:$PATH
export AT32=$HOME/at32
# Zephyr (ArteryTek fork workspace)
export ZEPHYR_SDK_INSTALL_DIR=$HOME/siwx917/zephyr-sdk-1.0.1
alias west-at32='source $HOME/siwx917/.venv/bin/activate'
# OpenOCD (ArteryTek fork): openocd -f interface/atlink_dap_v2.cfg -f target/at32f435xM.cfg
# probe-rs: probe-rs info --chip AT32F435ZMT7
