const gpio = @import("hal/gpio.zig");
const sio = @import("hal/sio.zig");
const reset = @import("hal/reset.zig");

const regs = @import("rp2040_ras");

// inits following
// https://github.com/ataradov/mcu-starter-projects/blob/master/rp2040/main.c
// https://github.com/dwelch67/raspberrypi-pico/blob/main/uart01/notmain.c

fn clocks_init() void {
    // Initialize the XOSC
    // See RP2040 Datasheet:
    // 2.15.2.2. Crystal Oscillator
    // 2.16.3. Startup Delay

    // TODO these constants should probably be somewhere in rp2040_ras.zig
    const FREQ_RANGE_1_15_MHZ = 0xaa0;
    const DELAY_1MS = 47;
    const XOSC_ENABLE = 0xfab;

    regs.XOSC.CTRL.modify(.{ .FREQ_RANGE = FREQ_RANGE_1_15_MHZ });
    regs.XOSC.STARTUP.modify(.{ .DELAY = DELAY_1MS });
    regs.XOSC.CTRL.modify(.{ .ENABLE = XOSC_ENABLE });

    while ((regs.XOSC.STATUS.read().STABLE) == 0) {}

    // TODO these constants should probably be somewhere in rp2040_ras.zig
    const REF_SRC_XOSC = 0x2;
    const SYS_SRC_REF = 0x0;

    // Configure ref & sys clock to use XOSC directly (no PLLs, 12MHz)
    regs.CLOCKS.CLK_REF_CTRL.modify(.{ .SRC = REF_SRC_XOSC });
    regs.CLOCKS.CLK_SYS_CTRL.modify(.{ .SRC = SYS_SRC_REF });

    // Configure peri clock to XOSC (12MHz)
    const PERI_ENABLE = 0x1;
    const PERI_SRC_XOSC = 0x4;
    regs.CLOCKS.CLK_PERI_CTRL.modify(.{ .ENABLE = PERI_ENABLE, .AUXSRC = PERI_SRC_XOSC });
}

pub fn hako_main() noreturn {
    clocks_init();

    reset.deassert_reset_of(.IO_BANK0);

    gpio.set_dir(.P25, .Output);
    gpio.set_function(.P25, .F5);

    sio.set_output_enable(.GPIO25);

    while (true) {
        sio.set_output(.GPIO25);
        busy_wait();
        busy_wait();
        busy_wait();

        sio.clear_output(.GPIO25);
        busy_wait();
    }
}

fn busy_wait() void {
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {}
}
