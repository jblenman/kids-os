# Hardware notes

What the reference machine taught us. Everything here was observed, not read in a manual; where a lesson is general it says so.

## The reference machine: a 2011 Sandy Bridge desktop
Gigabyte **Z68XP-UD3** (BIOS F10, Gigabyte "Hybrid EFI"), Core i5-2500K, 16 GB, Intel HD 3000 graphics, a discrete NVIDIA GTX TITAN X, two 2.5-inch 320 GB laptop HDDs, a TP-Link TL-WN725N USB Wi-Fi dongle, a 4K TV on the motherboard's HDMI port.

### Firmware ("Hybrid EFI")
- It is a legacy Award BIOS with a bolted-on EFI loader: no EFI runtime variables, no Secure Boot, no TPM. Linux sees a plain BIOS boot (`/sys/firmware/efi` absent) even when the firmware took the EFI path to GRUB.
- **It jumps at any GPT disk that carries an EFI System Partition.** With ChromeOS Flex installed (GPT + ESP) the setup key stopped responding at the splash (Del sometimes powered the box off or restarted it); F12's boot menu still worked. Holding Del from the moment the splash appears gets in. The installer therefore types the installed boot partition as a plain Linux partition (`kids-os-install`), and the USB image — which must also boot UEFI machines — keeps its ESP.
- *Init Display First = Onboard* makes POST and the boot menu appear on the motherboard HDMI instead of the discrete card's ports. *First Boot Device = USB-HDD* boots a stick with no key press; the BIOS remembers that entry **per USB port** — move the stick to another port and the box boots to a blank screen.
- BIOS Windows (MBR, "System Reserved" partition) on another disk is chainloaded from GRUB with the os-prober recipe (`search --fs-uuid` of System Reserved, `drivemap -s (hd0) ${root}`, `chainloader +1`). A UEFI Windows cannot be chainloaded by BIOS GRUB.

### Graphics
- Intel HD 3000 (`i915`, Mesa crocus) drives the TV at 1920x1080. The board's VGA connector reports a **phantom 1024x768 display** (also seen on Flex, where it forced mirror mode at 1024x768): `video=VGA-1:d` on the kernel command line disables it.
- `nouveau` is blacklisted; the NVIDIA card stays dark and Chrome renders on the iGPU. For 4K60 through the card NVIDIA's 580 driver branch (the last with Maxwell support) would be the route. Sandy Bridge decodes H.264 in hardware (the legacy `i965` VA driver); VP9/AV1 are software — fine at 1080p, not at 4K.
- HDMI audio comes from the Intel PCH codec; the NVIDIA card's HDA device is disabled in WirePlumber so it never becomes the default sink. The sink appears only once the session starts cleanly ("Dummy Output" at boot is an ordering artefact, not a fault).

### Sleep
- S3 suspend ends in a black screen with dead input on this board (seen on Flex, where idle suspend was the default). The image never suspends; the display turns off through DPMS only.

### Wi-Fi
- TP-Link TL-WN725N (`0bda:8179`, `rtl8xxxu`, `firmware-realtek`) works out of the box and keeps its MAC, so a DHCP reservation holds. Ethernet (`r8169`) works too.

## USB sticks (general lessons)
- A USB 2.0 stick is fine for the first boots and painful after that: Chrome's random writes starve everything else (load > 10, D-state processes, journald hitting its 3-minute watchdog during package installs). Use a USB 3 stick, or install to an SSD.
- Cheap no-name sticks may report more capacity than they have. The image caps its data partition (`SizeMaxBytes` in `usr/lib/repart.d/20-data.conf`) so a fake-capacity stick cannot silently wrap writes; raise or remove the cap for media you trust (verify with F3 first).
- When writing on macOS, a stick that drops off the bus mid-write (`dd: Device not configured`) leaves the old content beyond the point reached — the next boot ends in the initrd's emergency shell. Write again (another port helped here) and always verify; `tools/write-usb-macos.sh` reads the written range back and compares hashes.
- Boot from a USB 2.0 stick takes about two minutes to the desktop on this machine; from an SSD a fraction of that.

## Internal drives on the reference machine
- Both internal drives are 2.5-inch laptop HDDs; the minutes-long boots on Flex came from them. A cheap SATA SSD is the single biggest improvement for a machine like this.
