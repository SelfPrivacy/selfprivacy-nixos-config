{ pkgs, ... }: {
  # taken from https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/profiles/hardened.nix
  security.lockKernelModules = true;
  security.protectKernelImage = true;
  security.forcePageTableIsolation = true;
  security.unprivilegedUsernsClone = true;

  security.apparmor.enable = true;
  security.apparmor.killUnconfinedConfinables = true;

  boot.kernelParams = [
    # Don't merge slabs
    "slab_nomerge"

    # Enable page allocator randomization
    "page_alloc.shuffle=1"

    # Disable debugfs
    "debugfs=off"
  ];

  systemd.coredump.enable = false;

  security.sudo.enable = false;

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1; # TODO why is it here by default, for VPN only?
    "kernel.core_pattern" = "|${pkgs.coreutils}/bin/false"; # Ignore coredumps
    "kernel.yama.ptrace_scope" = "3"; # Disable ptrace()
    "kernel.io_uring_disabled" = "2"; # io_uring has huge attack surface and is not used by any module in SelfPrivacy.

    "dev.tty.ldisc_autoload" = "0";

    "kernel.kexec_load_disabled" = "1";
    "kernel.unprivileged_bpf_disabled" = "1"; # Only systemd uses eBPF.
    "kernel.kptr_restrict" = "2"; # Hide kernel pointer locations.

    "vm.unprivileged_userfaultfd" = "0"; # Reduce attack surface
  };
}
