#!/usr/bin/perl
# Copyright (c) 2025 Jonas van den Berg and contributors.
# This file is licensed under the BSD 3-Clause License.

use strict;
use warnings;
use DynaLoader;
use File::Basename qw(basename);
use File::Spec;

my $framework_path = shift @ARGV
  or die "Framework path not provided\n";
my $framework = $framework_path;
if (-d $framework_path) {
  my $framework_name = basename($framework_path);
  $framework_name =~ s/\.framework$//
    or die "Provided path is not a framework: $framework_path\n";
  $framework = File::Spec->catfile($framework_path, $framework_name);
}
die "Framework not found at $framework\n" unless -e $framework;

my $handle = DynaLoader::dl_load_file($framework, 0)
  or die "Failed to load framework: $framework\n";
my $symbol = DynaLoader::dl_find_symbol($handle, "adapter_get_env")
  or die "Symbol 'adapter_get_env' not found in $framework\n";
DynaLoader::dl_install_xsub("main::get", $symbol);

get();
