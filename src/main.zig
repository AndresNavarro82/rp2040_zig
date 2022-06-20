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
    const PERI_SRC_XOSC = 0x4;
    regs.CLOCKS.CLK_PERI_CTRL.modify(.{ .ENABLE = 1, .AUXSRC = PERI_SRC_XOSC });
}

fn uart0_config() void {
    // uart0 & io_bank0 should be running (reset deasserted)

    // First set 115200 baud rate
    // See RP2040 Datasheet:
    // 4.2.3.2.1. Fractional baud rate divider
    //(12000000/(16/115200)) = 6.514
    //0.514*64 = 32.666
    const BAUD_INT = 6;
    const BAUD_FRAC = 33;
    regs.UART0.UARTIBRD.modify(.{ .BAUD_DIVINT = BAUD_INT });
    regs.UART0.UARTFBRD.modify(.{ .BAUD_DIVFRAC = BAUD_FRAC });

    const LEN8 = 0x3;
    // 8n1 (8 bits, no parity, 1 stop bit), enable FIFOs
    regs.UART0.UARTLCR_H.modify(.{ .WLEN = LEN8, .FEN = 1 });
    // enable uart, no hardware flow control, enable RX & TX
    regs.UART0.UARTCR.modify(.{ .UARTEN = 1, .TXE = 1, .RXE = 1 });

    // set gpio 0 function as TX & gpio 1 function as RX
    // See RP2040 Datasheet:
    // 2.19.2. Function Select
    const UART_FN = gpio.Function.F2;
    gpio.set_function(.P0, UART_FN);
    gpio.set_function(.P1, UART_FN);
}

fn uart_send_char(char:u8) void {
    // wait until uart is ready (FIFO not full)
    while(regs.UART0.UARTFR.read().TXFF == 1) { }
    regs.UART0.UARTDR.modify(.{ .DATA = char });
}

fn uart_send_string(str: [] const u8) void {
    for (str) |char| {
        uart_send_char(char);
    }
}

fn uart_try_get_char() ?u8 {
    // XXX: ignore errors for now (parity, framing, break)
    // only return char is fifo isn't empty
    return if (regs.UART0.UARTFR.read().RXFE == 0) regs.UART0.UARTDR.read().DATA else null;
}

fn uart_get_char() u8 {
    // XXX: ignore errors for now (parity, framing, break)
    // wait until fifo has at least one char
    while (regs.UART0.UARTFR.read().RXFE == 1) {}
    return regs.UART0.UARTDR.read().DATA;
}

// get a line (including carriage return)
// XXX default minicom ends lines with carriage return only
fn uart_get_line(str: [] u8) [] u8 {
    var i:usize = 0;
    while(i < str.len) {
        const c = uart_get_char();
        str[i] = c;
        i += 1;
        if (c == '\r') {
            break;
        }
    }
    return str[0..i];
}

fn led_config() void {
    gpio.set_dir(.P25, .Output);
    gpio.set_function(.P25, .F5);
    sio.set_output_enable(.GPIO25);
}

fn led_blink_once() void {
    sio.set_output(.GPIO25);
    busy_wait();
    sio.clear_output(.GPIO25);
    busy_wait();
}

pub fn hako_main() noreturn {
    clocks_init();

    reset.deassert_reset_of(.IO_BANK0);
    reset.deassert_reset_of(.UART0);

    uart0_config();
    // XXX default minicom doesn't like just \n
    uart_send_string("Hello RP2040!\r\n");

    led_config();
    led_blink_once();

    while (true) {
        var buf:[128]u8 = undefined;
        const line = uart_get_line(&buf);
        uart_send_string(line);
        // XXX add newline for minicom
        if (line[line.len-1] == '\r') {
            uart_send_char('\n');
        }
        led_blink_once();
    }
}

fn busy_wait() void {
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {}
}
