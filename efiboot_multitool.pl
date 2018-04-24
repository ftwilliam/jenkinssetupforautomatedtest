#!/usr/bin/perl
use strict;
use warnings;

use constant NOHW_CODE => "99e275e7-75a0-4b37-a2e6-c5385e6c00cb";
use constant NOGPT_CODE  => "DEADCAFEBEEF";

# this is a wrapper for efibootmgr.  This allows a more simple interface
# where you don't have to worry about things AS much.  There are some
# limitations where you can't modifiy EFI settings if there's 2 with the
# same name.  This might get fixed in the future though


# things needed, boot number, if active, name, if available
# not in the system -> Boot0000* ubuntu-16.04	VenHw(99e275e7-75a0-4b37-a2e6-c5385e6c00cb)
# is in the system  -> Boot0001* ubuntu-18.04	HD(1,GPT,509eebc0-1e33-4d4f-a748-b166c429edb7,0x800,0x100000)/File(\EFI\UBUNTU\SHIMX64.EFI)
# first input
#	ref to array of lines outputted from efibootmgr -v
# second input
#	ref to array of hashes used for boot entries
# third input
#	ref of hash used for storing general efibootmgr data
sub parse_efi_list {
	my $efi_raw      = shift;
	my $efi_parsed   = shift;
	my $efi_settings = shift;

# used for ref
#	my $settings = {
#		'boot_curr'  => '',
#		'boot_next'  => '',
#		'boot_order' => '',
#		'time_out'   => '',
#	};

	foreach my $line (@{$efi_raw}) {
		chomp($line);
		if ($line =~ m/^BootCurrent/) {
			my ($trash, $curr) = split(/: /, $line);
			$efi_settings->{'boot_curr'} = $curr;
		} elsif ($line =~ m/^BootNext/) {
			my ($trash, $next) = split(/: /, $line);
			$efi_settings->{'boot_next'} = $next;
		} elsif ($line =~ m/^BootOrder/) {
			my ($trash, $order) = split(/: /, $line);
			$efi_settings->{'boot_order'} = $order;
		} elsif ($line =~ m/^Timeout/) {
			my ($trash, $time) = split(/: /, $line);
			$efi_settings->{'time_out'} = $time;
		} else {
			my $entry = {
				'boot_num' => '',
				'active'   => '',
				'name'     => '',
				'avail'    => '',
				'part-uuid'  => '',
				'file'     => '',
			};
			#print "$line\n";
			my ($boot, $rest) = split(/ /, $line, 2);
			my ($name, $info) = split(/\t/, $rest, 2);
			$boot =~ s/^Boot//;
			my @gpt_line = ($info =~ m/\((.*?)\)/);
			@gpt_line = split(',', $gpt_line[0]);
			my $gpt_entry = $gpt_line[0] eq "1" ? $gpt_line[2] : NOGPT_CODE;
			my @file_line = ($info =~ m/File\((.*?)\)/);
			my $file = (defined $file_line[0]) ? $file_line[0] : "" ;
			#print "boot: $boot\n";
			#print "name: $name\n";
			#print "info: $info\n";
			#print "gpt:  $gpt_entry\n";
			#print "file: $file\n";


			$entry->{'active'}    = ($boot =~ m/\*$/) ? 1 : 0;
			($entry->{'boot_num'} = $boot) =~ s/\*$//;
			$entry->{'name'}      = $name;
			$entry->{'avail'}     = ($info =~ m/^VenHw/) ? 0 : 1;
			$entry->{'part-uuid'}   = $gpt_entry;
			$entry->{'file'}      = $file;

			push(@{$efi_parsed}, $entry);
		}
	}
}

sub print_help {
	print STDERR "Use for $0 is:\n";
	print STDERR "$0 <cmd> <argv(s)>\n";
	print STDERR "where:\n";
	print STDERR "\tcmd -> push, argv -> <efi entry>\n";
	print STDERR "\t\tpushes <efi entry> to the top of the boot order\n";
	print STDERR "\tcmd -> pop, argv -> <efi entry>\n";
	print STDERR "\t\tpops <efi entry> off of the boot order\n";
	print STDERR "\tcmd -> delete, argv -> <efi entry>\n";
	print STDERR "\t\tdeletes <efi entry>, the entry can either be a name or bootnumber\n";
	#TODO: the below
	#print STDERR "\tcmd -> delete_all, argv -> <efi entry>\n";
	#print STDERR "\t\tdeletes <efi entry> and any other entries on that partition\n";
	print STDERR "\tcmd -> add, argv -> <efi info csv>\n";
	print STDERR "\t\tadds name,efi_partition,efi_path_on_partition as a boot entry\n";
	print STDERR "\tcmd -> list\n";
	print STDERR "\t\tlists the efi boot entries\n";
}

sub cmd_push {
	my $entry = shift;

	my @efi_raw;
	my @efi_bootlist;
	my %efi_settings;

	@efi_raw = `efibootmgr -v`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	# find and check entry index
	my $entry_in = -1;
	for (my $i = 0; $i <=$#efi_bootlist ; $i++) {
		if ( $efi_bootlist[$i]->{'name'} eq "$entry" ) {
			$entry_in = $i;
			last;
		}
	}
	if ($entry_in < 0) {
		die "can't find entry in list\n";
	}

	# checks to make sure it's available and active
	unless ($efi_bootlist[$entry_in]->{'avail'}) {
		die "entry not available\n";
	}
	unless ($efi_bootlist[$entry_in]->{'active'}) {
		die "entry not active\n";
	}

	my $new_order = $efi_settings{'boot_order'};
	# unless first, update it
	unless ($new_order =~ m/^0*$efi_bootlist[$entry_in]->{'boot_num'}/) {
		$new_order =~ s/,?0*$efi_bootlist[$entry_in]->{'boot_num'}//;
		$new_order = "$efi_bootlist[$entry_in]->{'boot_num'},".$new_order;
	}

	@efi_raw = `efibootmgr -v -o $new_order`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	if ($new_order ne $efi_settings{'boot_order'}) {
		die "updated boot order and currect boot order don't match\n"
	}
}

sub cmd_pop {
	my $entry = shift;

	my @efi_raw;
	my @efi_bootlist;
	my %efi_settings;

	my $new_order;

	@efi_raw = `efibootmgr -v`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	if (defined($entry)) {
		# find and check entry index
		my $entry_in = -1;
		for (my $i = 0; $i <=$#efi_bootlist ; $i++) {
			if ( $efi_bootlist[$i]->{'name'} eq "$entry" ) {
				$entry_in = $i;
				last;
			}
		}
		if ($entry_in < 0) {
			die "can't find entry in list\n";
		}

		#get boot order and remove entry
		$new_order = $efi_settings{'boot_order'};
		if ($new_order =~ m/$efi_bootlist[$entry_in]->{'boot_num'}/) {
			if ($new_order =~ m/^0*$efi_bootlist[$entry_in]->{'boot_num'}/) {
				$new_order =~ s/^0*$efi_bootlist[$entry_in]->{'boot_num'},?//;
			} else {
				$new_order =~ s/,?0*$efi_bootlist[$entry_in]->{'boot_num'}//;
			}
		}
	#just remove the top entry
	} else {
		$new_order = $efi_settings{'boot_order'};
		$new_order =~ s/^\d+,?//;
	}

	@efi_raw = `efibootmgr -v -o $new_order`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	if ($new_order ne $efi_settings{'boot_order'}) {
		die "updated boot order and currect boot order don't match\n"
	}
}

sub cmd_delete {
	my $entry = shift;

	my @efi_raw;
	my @efi_bootlist;
	my %efi_settings;

	@efi_raw = `efibootmgr -v`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	# find and check entry index
	my $entry_in = -1;
	for (my $i = 0; $i <=$#efi_bootlist ; $i++) {
		if ( $efi_bootlist[$i]->{'name'} eq "$entry" ) {
			$entry_in = $i;
			last;
		}
	}
	if ($entry_in < 0) {
		die "can't find entry in list\n";
	}

	my $rv = system("efibootmgr -b $efi_bootlist[$entry_in]->{'boot_num'} boot_num  -B > /dev/null 2>&1");

	if ($rv != 0) {
		print("deleting entry might have failed\n");
		return 1;
	}
}

sub cmd_add {
	my $entry = shift;

	my @efi_raw;
	my @efi_bootlist;
	my %efi_settings;

	my ($efi_name, $efi_dev, $efi_path) = split(',', $entry);

	@efi_raw = `efibootmgr -v`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	# find and check entry index
	#my $entry_in = -1;
	for (my $i = 0; $i <=$#efi_bootlist ; $i++) {
		if ( $efi_bootlist[$i]->{'name'} eq "$entry" ) {
			print "found an efi with the same name, exiting\n";
			return 1;
		}
	}

	my $dev_base;
	my $dev_par;
	#/dev/by-id/X-partY
	if ($efi_dev =~ m/\/dev\/disk\/by-id\//) {
		($dev_base = $efi_dev) =~ s/-part\d+$//;
		($dev_par = $efi_dev) =~ s/^.*-part//;
	#/dev/sdXY
	} elsif ($efi_dev =~ m/\/dev\/sd/) {
		($dev_base = $efi_dev) =~ s/\d+$//;
		($dev_par = $efi_dev) =~ s/^\D+//;
	#/dev/nvmeXn1pY
	} elsif ($efi_dev =~ m/\/dev\/nvme/) {
		($dev_base = $efi_dev) =~ s/p\d+$//;
		($dev_par = $efi_dev) =~ s/^.*\/nvme\d+n\d+p//;
	} else {
		print "can't parse efi device given, exiting\n";
		return 1;
	}

	#test path
	if ($efi_path !~ m/\\/) {
		print "can't find any \\s in the efi path, exiting\n";
		return 1;
	}

	my $rv = system("efibootmgr -c -d $dev_base  -p $dev_par -L \"$efi_name\"  -l \"$efi_path\" > /dev/null 2>&1");
	#my $rv = 0;

	if ($rv != 0) {
		print("adding entry might have failed\n");
		return 1;
	}

	#efibootmgr places the new entry at the top of the boot	order,
	#remove it
	cmd_pop($efi_name);
}

sub cmd_list {
	my $entry = shift;

	my @efi_raw;
	my @efi_bootlist;
	my %efi_settings;

	@efi_raw = `efibootmgr -v`;
	parse_efi_list(\@efi_raw, \@efi_bootlist, \%efi_settings);

	#print efi settings
	foreach my $name (sort keys %efi_settings) {
		print "$name = $efi_settings{$name}\n";
	}

	for (my $i = 0; $i<=$#efi_bootlist; $i++) {
		print "bootnum=$efi_bootlist[$i]->{'boot_num'}\n";
		print "\tname=$efi_bootlist[$i]->{'name'}\n";
		print ($efi_bootlist[$i]->{'active'} ? "\tactive=yes\n" : "\tactive=no\n");
		print ($efi_bootlist[$i]->{'avail'} ? "\tavailable=yes\n" : "\tavailable=no\n");
		#print ($efi_bootlist[$i]->{'part-uuid'} eq NGPT );
		if ($efi_bootlist[$i]->{'part-uuid'} eq NOGPT_CODE) {
			print "\tpart-UUID=\n";
		} elsif ($efi_bootlist[$i]->{'part-uuid'} eq NOHW_CODE) {
			print "\tpart-UUID=\n";
		} else {
			print "\tpart-UUID=$efi_bootlist[$i]->{'part-uuid'}\n";
		}
		print ($efi_bootlist[$i]->{'file'} eq "" ? "\tpath=\n" : "\tpath=$efi_bootlist[$i]->{'file'}\n");
	}
}

# start up argc checking
my ($cmd, $argv, $trash) = @ARGV;

my %func_hash = (
	"push" => \&cmd_push,
	"pop" => \&cmd_pop,
	"delete" => \&cmd_delete,
	"add" => \&cmd_add,
	"list" => \&cmd_list,
);

if (!defined($func_hash{$cmd})) {
	print_help();
	exit 1;
}

my $rv = $func_hash{$cmd}($argv);

exit $rv;
