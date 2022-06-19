const regs = @import("rp2040_ras");

const Peripheral = enum {
    IO_BANK0,
    UART0,
};

pub fn deassert_reset_of(perif: Peripheral) void {
    switch (perif) {
        .IO_BANK0 => {
            regs.RESETS.RESET.modify(.{ .io_bank0 = 0 });
            while ((regs.RESETS.RESET_DONE.read().io_bank0) == 0) {}
        },
        .UART0 => {
            regs.RESETS.RESET.modify(.{ .uart0 = 0 });
            while ((regs.RESETS.RESET_DONE.read().uart0) == 0) {}
        },
    }
}
