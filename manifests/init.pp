# == Class: vmwaretools
#
# This class handles installing the VMware Tools via the archives distributed
# by VMware. Upgrades and downgrades are also supported.
#
# The archive can either be placed on an HTTP-accessible location, or within
# this module's 'files' directory.
#
# === Parameters:
#
# [*version*]
#   The numeric version of the tools that you want to install. This can be
#   found by looking at the filename of the archive - e.g. 8.6.5-621624
#
# [*working_dir*]
#   The directory to store files in.
#   Default: '/tmp/vmwaretools' (string)
#
# [*redhat_install_devel*]
#   If you really want to install kernel headers on RedHat-derivative operating
#   systems - you will likely not need this as most RH distros have
#   pre-compiled kernel modules.
#   Default: false (boolean)
#
# [*redhat_devel_package*]
#   Name of the redhat devel Package
#   Default: Operating system dependent (string)
#
# [*awk_path*]
#   Path to the awk binary
#   Default: Operating system dependent (string)
#
# [*archive_url*]
#   Specify an HTTP location to download the archive from - this is useful when
#   you want to avoid packaging the installer with your Puppet code.  NOTE that
#   this does NOT include the filename, just the path to the file. The filename
#   will be constucted as 'VMwareTools-$version.tar.gz'.
#   Default: 'puppet' (string)
#
# [*archive_md5*]
#   md5sum of the archive - required if using an HTTP location above.
#   Default: '' (empty string)
#
# [*fail_on_non_vmware*]
#   Output a hard failure message if the module is run on non-vmware hardware.
#   Default: false (boolean)
#
# [*keep_working_dir*]
#   Keep the working dir on disk after installation.
#   Default: false (boolean)
#
# [*prevent_downgrade*]
#   If the system has a version of the tools installed which is newer that what
#   is set in the version parameter, do not downgrade the tools.
#   Default: true (boolean)
#
# [*timesync*]
#   Should the node synchronise their system clock with the vSphere server?
#   Acceptable values are true, false (both literal booleans, NOT quoted
#   strings) or undef (literal). Booleans will either enable or disable
#   synchronisation, and undef will disable management of timesync altogether.
#   Default: undef (UNDEFINED)
#
# [*purge_packages_list*]
#   A list of packets to be removed.
#   Default: ['open-vm-tools', 'open-vm-dkms', 'vmware-tools-services', 'vmware-tools-foundation', 'open-vm-tools-desktop'] (array)
#
# [*purge_packages_mode*]
#   Specify the ensure value in the package provider for the purge_package_list.
#   The value purged  also removes the dependencies of the packages.
#   Acceptable values are absent or purged.
#   Default: absent
#
# == Actions:
#
# * Compares installed version with the configured version
# * Transfer the VMware Tools archive to the target agent (via Puppet or HTTP)
# * Untar the archive, run vmware-install-tools.pl
# * Removes open-vm-tools
#
# === Requires:
#
# * HTTP download script: wget, awk, md5sum
#
# === Sample Usage:
#
# To accept defaults:
#
#   include vmwaretools
#
# To specify a non-default version, working directory and HTTP URL:
#
#   class { 'vmwaretools':
#     version     => '8.6.5-621624',
#     working_dir => '/tmp/vmwaretools'
#     archive_url => 'http://server.local/my/dir',
#     archive_md5 => '9df56c317ecf466f954d91f6c5ce8a6f',
#   }
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
class vmwaretools (
  $version              = $::vmwaretools::params::version,
  $working_dir          = $::vmwaretools::params::working_dir,
  $redhat_install_devel = $::vmwaretools::params::redhat_install_devel,
  $redhat_devel_package = $::vmwaretools::params::redhat_devel_package,
  $awk_path             = $::vmwaretools::params::awk_path,
  $archive_url          = $::vmwaretools::params::archive_url,
  $archive_md5          = $::vmwaretools::params::archive_md5,
  $fail_on_non_vmware   = $::vmwaretools::params::fail_on_non_vmware,
  $keep_working_dir     = $::vmwaretools::params::keep_working_dir,
  $prevent_downgrade    = $::vmwaretools::params::prevent_downgrade,
  $timesync             = $::vmwaretools::params::timesync,
  $purge_package_list   = $::vmwaretools::params::purge_package_list,
  $purge_package_mode   = $::vmwaretools::params::purge_package_mode,
) inherits vmwaretools::params {

  validate_re($purge_package_mode, '^(purged|absent)$',
  "${ensure} is not supported for ensure.
  Allowed values are 'present' and 'absent'.")

  if $::vmwaretools_version == 'not installed' {
    # If nothing is installed, deploy.
    $deploy_files = true
  } else {

    # If tools are installed, are we handling downgrades?
    if $vmwaretools::prevent_downgrade {

      if versioncmp($::vmwaretools_version,$vmwaretools::version) < 0 {
        # Only deploy if the installed version is **lower than** the Puppet version
        $deploy_files = true
      } else {
        $deploy_files = false
      }

    } else {
      # If we're not handling downgrades, deploy on version mismatch
      $deploy_files = $::vmwaretools_version ? {
        $vmwaretools::version => false,
        default               => true,
      }
    }
  }

  # Puppet Lint gotcha -- facts are returned as strings, so we should ignore
  # the quoted-boolean warning here. Related links below:
  # https://tickets.puppetlabs.com/browse/FACT-151
  # https://projects.puppetlabs.com/issues/3704

  if $::is_virtual == 'true' and $::virtual == 'vmware' and $::kernel == 'Linux' {

    notify{$::vmwaretools_version: }
    if $::vmwaretools_version == undef {
      fail 'vmwaretools_version fact not present, please check your pluginsync configuraton.'
    }

    if (($archive_url == 'puppet') or ('puppet://' in $archive_url)) {
      $download_vmwaretools = false
    } else {
      $download_vmwaretools = true
    }

    if (($download_vmwaretools == true) and ($archive_md5 == '')) {
      fail 'MD5 not given for VMware Tools installer package'
    }

    if $::lsbdistcodename == 'raring' {
      fail 'Ubuntu 13.04 is not supported by this module'
    }

    include vmwaretools::install
    include vmwaretools::config
    include vmwaretools::config_tools

    if $timesync != undef {
      include vmwaretools::timesync
    }
  } elsif $fail_on_non_vmware == true and ($::is_virtual == 'false' or $::virtual != 'vmware') {
    fail 'Not a VMware platform.'
  }
}
