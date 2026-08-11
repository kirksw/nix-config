# `ry6b` Hardware Stability Incident

## Purpose

This document records the evidence, configuration changes, and controlled tests used to diagnose repeated hard lockups on `nixos-ry6b`.
It distinguishes observed facts from working hypotheses so that the record can be shared with the manufacturer.

## Hardware and software

- System: Minisforum Venus-series mini PC
- Board identifier: F7BFC
- Processor: AMD Ryzen 9 6900HX with integrated AMD graphics
- BIOS: version 1.20, dated 2024-03-06
- Memory: two removable DDR5 SODIMMs, identified in this document as stick A and stick B
- NVMe: Kingston OM8PGP41024Q-A0, 1.02 TB, firmware ELFK0S.6
- Operating system: NixOS 26.11
- Kernel during the replacement-unit tests: Linux 6.18.42
- Role: secondary K3s worker node
- Hostname: `nixos-ry6b`
- LAN address during testing: `192.168.10.67`

## Failure signature

The node becomes completely unresponsive without a controlled shutdown.
It stops responding to ICMP and SSH, and its Kubernetes lease stops renewing.
Recovery requires a manual power cycle.
The system journal ends abruptly without recording a kernel panic or orderly shutdown.
During one reproduced failure, the connected display became a solid green screen while the entire host stopped responding.

## Previous unit observations

The previous faulty unit remained unstable after its memory was swapped.
It appeared more stable with one DIMM installed in the lower physical slot, although this was not tested for an extended period.
It would not reach the BIOS when a single DIMM was installed in the top physical slot.
The inability to boot from the top slot alone is not conclusive because the manufacturer has not yet confirmed whether that slot supports a single-DIMM configuration.
The previous-unit evidence makes a single defective DIMM less likely, but it does not exclude memory compatibility, a slot or channel fault, memory training, or an integrated memory-controller fault.

## Replacement unit timeline

### Initial unexpected shutdown

The Kubernetes lease and host journal stopped abruptly on 2026-08-09 at approximately 14:00 CEST.
There was no clean shutdown record, kernel panic, OOM event, thermal event, NVMe fault, MCE, or EDAC report.
The next boot required XFS journal recovery and PostgreSQL WAL recovery, which is consistent with an abrupt reset or loss of power.
Firmware reported `Previous system reset reason [0x00200800]: ACPI power state transition occurred` after reboot.

### Suspend and CPU idle-state test

All system sleep modes were disabled declaratively:

- Suspend
- Hibernate
- Hybrid sleep
- Suspend-then-hibernate

Deep CPU idle states were disabled with the kernel parameter `processor.max_cstate=1`.
Runtime verification showed only `POLL` and `C1` CPU idle states.
The node subsequently hard-locked again, so system sleep and CPU C2/C3 states are not sufficient explanations.

### Green-screen failure

The node hard-locked again shortly after a controlled reboot on 2026-08-10.
The display became completely green during the lockup.
The host simultaneously stopped responding to ping and SSH, and its Kubernetes lease stopped renewing.
The failed boot journal ended abruptly at 09:53:20 CEST.
No panic, OOM event, MCE, EDAC error, PCIe AER fault, NVMe error, thermal shutdown, or pstore crash record was captured.

Before the GPU driver was disabled, AMDGPU initialization repeatedly logged:

```text
REG_WAIT timeout 1us * 100000 tries - optc31_disable_crtc
```

### AMDGPU isolation test

The `amdgpu` kernel module was blacklisted declaratively.
Runtime verification confirmed that the module was not loaded and that the integrated GPU PCI device was unbound.
The CPU idle-state limit remained active during this test.
The node subsequently froze again and stopped responding to ping and SSH.
This result makes the Linux AMDGPU driver unlikely to be the primary cause.
It does not exclude a physical APU, shared-memory, motherboard, or power fault.

### Power-adapter and single-DIMM test

The power adapters for `ry6a` and `ry6b` were swapped.
Stick A was removed from the top physical slot of `ry6b`.
Stick B remained alone in the lower physical slot.
The AMDGPU blacklist and C-state limit remained active.
In this configuration, `ry6b` briefly renewed its Kubernetes lease and then became unreachable again.
The last observed lease renewal was 2026-08-10 at 10:50:31 CEST.
This configuration was therefore unstable.

Because the power adapter and memory configuration changed together, this test alone cannot independently attribute the failure to either component.
However, instability continued with the alternate adapter, so the original adapter is not a sufficient explanation.

## NVMe evidence

NVMe SMART data did not indicate media failure:

| Attribute | Result |
| --- | --- |
| Critical warning | 0 |
| Temperature | 35°C |
| Available spare | 100% |
| Percentage used | 0% |
| Data read | 212.40 GB |
| Data written | 460.42 GB |
| Power-on hours | 61 |
| Power cycles | 82 |
| Unsafe shutdowns | 42 |
| Media errors | 0 |
| Error-log entries | 274 |

The 274 error-log entries reported `Invalid Field in Command`, not media or LBA failures.
The 42 unsafe shutdowns in 61 power-on hours corroborate repeated abrupt resets but do not identify the NVMe as their cause.

## Tests and outcomes

| Test | Configuration | Outcome | Interpretation |
| --- | --- | --- | --- |
| Disable system sleep | All sleep and hibernation modes disabled | Froze again | Sleep is unlikely to be the cause |
| Disable deep CPU idle | `processor.max_cstate=1`, only `POLL` and `C1` available | Froze again | C2/C3 are unlikely to be the cause |
| Check NVMe SMART | SMART and error logs inspected | No critical or media errors | NVMe media failure is unlikely |
| Disable Linux GPU driver | AMDGPU blacklisted and PCI device unbound | Froze again | AMDGPU software is unlikely to be the cause |
| Alternate power adapter plus stick B only | Alternate adapter, stick B in lower slot, top slot empty | Unstable | Original adapter is not a sufficient cause; stick B or the remaining memory subsystem is still suspect |

## Current assessment

The remaining leading possibilities are:

1. A defective or incompatible DIMM.
2. A motherboard memory-slot or memory-channel fault.
3. An unstable APU-integrated memory controller.
4. A BIOS memory-training or timing problem.
5. Motherboard or APU power-delivery instability.
6. A broader motherboard or APU hardware fault.

The integrated GPU uses system memory, so memory-subsystem corruption could explain both the solid green display and the complete host lock.
Passing a memory test would reduce but not eliminate the possibility of an intermittent memory-controller, motherboard, or power fault.

## Next controlled test

The next test changes only the DIMM:

1. Power off and unplug `ry6b`.
2. Remove stick B from the lower physical slot.
3. Install stick A in the same lower physical slot.
4. Leave the top physical slot empty.
5. Keep the currently swapped power adapter.
6. Reset memory settings to standard JEDEC defaults and leave XMP or EXPO disabled.
7. Run MemTest86 for at least four passes, preferably overnight.
8. If MemTest86 passes, run NixOS in this configuration for 24 to 48 hours under controlled load.

The result should be interpreted as follows:

- Stick A is stable while stick B was unstable in the same slot: stick B is the leading suspect.
- Both sticks are unstable in the same lower slot: the motherboard, APU memory controller, memory compatibility, or power delivery is the leading suspect.
- MemTest86 reports errors: record the failing test, address, CPU, and photograph the result.
- MemTest86 passes but NixOS freezes: continue to suspect an intermittent controller, board, or power fault.

## Operational mitigation

Authentik server, worker, and PostgreSQL workloads were migrated to `nixos-ry6a` before further hardware testing.
The PostgreSQL database was cleanly stopped, logically backed up, physically copied, and verified byte-for-byte before the storage binding was moved.
All Authentik components subsequently became Ready on `nixos-ry6a`, and the public endpoint returned HTTP 302.
No critical workload should be scheduled on `ry6b` while hardware testing continues.

## Relevant configuration changes

The diagnostic NixOS settings are in `hosts/nixos/ry6b/default.nix`.
Commit `68a50a6` adds the C-state limit and AMDGPU blacklist.
The Authentik placement change is in the `k8s-config` repository.
Commit `1feb24d` pins the Authentik server, worker, and PostgreSQL components to `nixos-ry6a`.

## Manufacturer questions

1. Is BIOS 1.20 the recommended firmware for this exact board revision and Ryzen 9 6900HX configuration?
2. Does the top physical SODIMM slot support booting as the only populated slot?
3. Are there known compatibility restrictions for 64 GB DDR5 kits on this model?
4. Are there known memory-training, dual-channel, solid-color display, or complete-lockup issues with this model?
5. Is there a manufacturer diagnostic for the memory channels, APU memory controller, motherboard power delivery, or external power adapter?
6. Do these repeated complete lockups qualify the replacement unit for further hardware service or RMA?
