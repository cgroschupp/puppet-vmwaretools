# == Class: vmwaretools::params
#
# This class handles parameters for the vmwaretools module, including the logic
# that decided if we should install a new version of VMware Tools.
#
# == Actions:
#
# None
#
# === Authors:
#
# Craig Watson <craig@cwatson.org>
#
# === Copyright:
#
# Copyright (C) 2013 Craig Watson
# Published under the GNU General Public License v3
#
class vmwaretools::params {

  $awk_path = $::osfamily ? {
    'RedHat' => '/bin/awk',
    'Debian' => '/usr/bin/awk',
    default  => '/usr/bin/awk',
  }

  if $::osfamily == 'RedHat' and $::lsbmajdistrelease == '5' {
    if ('PAE' in $::kernelrelease) {
      $kernel_extension = regsubst($::kernelrelease, 'PAE$', '')
      $redhat_devel_package = "kernel-PAE-devel-${kernel_extension}"
    } elsif ('xen' in $::kernelrelease) {
      $kernel_extension = regsubst($::kernelrelease, 'xen$', '')
      $redhat_devel_package = "kernel-xen-devel-${kernel_extension}"
    } else {
      $redhat_devel_package = "kernel-devel-${::kernelrelease}"
    }
  } else {
    $redhat_devel_package = "kernel-devel-${::kernelrelease}"
  }

  $version = '9.0.0-782409'
  $working_dir = '/tmp/vmwaretools'
  $redhat_install_devel = false
  $archive_url = 'puppet'
  $archive_md5 = ''
  $fail_on_non_vmware = false
  $keep_working_dir = false
  $prevent_downgrade = true
  $timesync = undef
  $purge_package_list = ['open-vm-tools', 'open-vm-dkms', 'vmware-tools-services', 'vmware-tools-foundation', 'open-vm-tools-desktop']
  $purge_package_mode = absent
}
