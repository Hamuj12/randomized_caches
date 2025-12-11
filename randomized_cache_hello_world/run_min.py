# run_min.py
from m5.objects import *
import m5, os

BIN = os.environ["HELLO_BIN"]

system = System()
system.clk_domain = SrcClockDomain(clock='1GHz', voltage_domain=VoltageDomain())
system.mem_mode = 'timing'
system.mem_ranges = [AddrRange('8GB')]

system.membus = SystemXBar()
system.cpu = TimingSimpleCPU()

# ---- X86 requires an interrupt controller in SE mode ----
system.cpu.createInterruptController()
# Wire the interrupt ports to the membus (X86-specific hookup)
system.cpu.interrupts[0].pio       = system.membus.master
system.cpu.interrupts[0].int_master = system.membus.slave
system.cpu.interrupts[0].int_slave  = system.membus.master
# ---------------------------------------------------------

# No caches for this sanity run: connect directly to membus
system.cpu.icache_port = system.membus.slave
system.cpu.dcache_port = system.membus.slave

# System port
system.system_port = system.membus.slave

# Simple memory (keeps things portable across forks)
system.mem = SimpleMemory(range=system.mem_ranges[0], latency='50ns', bandwidth='25GB/s')
system.mem.port = system.membus.master

# Workload
process = Process()
process.executable = BIN
process.cmd = [BIN]
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system = False, system = system)
m5.instantiate()

ev = m5.simulate(200000)  # small sanity run
print("Exiting @ tick {} because {}".format(m5.curTick(), ev.getCause()))
