# Copyright © 2013 Natalia D. Zemlyannikova
# Licensed under GPL version 2 or later.
# http://github.com/NZem/EGE
package EGE::Asm::AsmCodeGenerate;

use strict;
use warnings;

use EGE::Random;
use POSIX qw/ceil/;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(cgen);

my $cgen;

sub cgen {
    $cgen ||= EGE::Asm::AsmCodeGenerate->new;
}

sub new {
    my $self = { code => [] };
    bless $self, shift;
    $self;
}

sub generate_command {
	my ($self, $type, $reg, $lo, $hi) = @_;
	my ($cmd, $arg);
	$arg = defined $hi ? rnd->in_range($lo, $hi) : $lo;
	if ($type eq 'mov') {
		$arg = rnd->in_range(1, 255) if (!defined $lo);
		$cmd = 'mov';
	}
	if ($type eq 'add') {
		$arg = rnd->in_range(65, 255) if (!defined $lo);
		$cmd = rnd->pick('add', 'sub', 'adc', 'sbb', 'neg');
	}
	if ($type eq 'logic') {
		$arg = rnd->in_range(1, 255) if (!defined $lo);
		$cmd = rnd->pick('and', 'or', 'xor', 'test', 'not');
	}
	if ($type eq 'shift') {
		$arg = rnd->in_range(1, 3) if (!defined $lo);
		$cmd = rnd->pick('shl', 'shr', 'sal', 'sar', 'rol', 'ror', 'rcl', 'rcr');
	}
	if ($type eq 'convert') {
		$arg = rnd->in_range(1, 255) if (!defined $lo);
		$cmd = rnd->pick('movzx', 'movsx');
	}
	$self->add_command(rnd->pick('stc', 'clc')) if $self->use_cf($cmd);
	$arg = '' if $self->single_arg($cmd);
	$self->add_command($cmd, $reg, $arg);
}

sub add_command {
	my $self = shift;
	push @{$self->{code}}, [ @_ ];
}

sub get_code_txt {
	my ($self, $num_format) = @_;
	my $res = '<br></br><div id=\'code\'><code>';
	for my $str (@{$self->{code}}) {
		my $i=0;
		for (grep {!($_ eq '')} @$str) {
			$res .= $i == 0 ? '' : $i == 1 ? ' ' : ', ';
			$res .= (m/^-?(\d*)$/) ? sprintf $num_format, $_ : sprintf '%s', $_;
			$i++;
		}
		$res .= '<br></br>';
	}
	$res .= '</code></div>';
	$res;
}

sub get_reg {
	my ($self, $size, $not_ecx) = @_;
	my $letter = $not_ecx ? rnd->pick('a', 'b', 'd') : rnd->pick('a'..'d');
	sprintf { 32 => 'e%sx', 16 => '%sx', 8 => '%s'.rnd->pick('h', 'l') }->{$size}, $letter;
}

sub get_regs {
	my $self = shift;
	my @sizes = @_;
	my @letters = rnd->pick_n($#sizes+1, ('a'..'d'));
	my @res;
	for my $i (0..$#letters) {
		push @res, sprintf { 32 => 'e%sx', 16 => '%sx', 8 => '%s'.rnd->pick('h', 'l') }->{$sizes[$i]}, $letters[$i];
	}
	@res;
}

sub single_arg {
	my ($self, $cmd) = @_;
	{ not => 1, neg => 1 }->{$cmd};
}

sub use_cf {
	my ($self, $cmd) = @_;
	{ adc => 1, sbb => 1, rcl => 1, rcr => 1 }->{$cmd};
}

sub get_hex_args {
	my($self, $type) = @_;
	no strict 'refs';
	&{"get_hex_args_".$type}();
}

sub get_hex_args_add {
	my ($arg1, $arg2) = (0, 0);
	for (1..7) {
		my $sum = rnd->in_range(0, 15);
		my $n = rnd->in_range(ceil($sum/2), $sum);
		$arg1 = $arg1*16 + $n;
		$arg2 = $arg2*16 + $sum - $n;
	}
	$_ += rnd->in_range(0, 15) * 16**7 for ($arg1, $arg2);
	($arg1, $arg2);
}

sub get_hex_args_logic {
	my @arr = (0, 0);
	for (1..8) {
		my $n1 = rnd->pick(0, 15);
		my $n2 = rnd->in_range(0, 15);
		my ($i, $j) = rnd->pick_n(2, (0, 1));
		$arr[$i] = $arr[$i]*16 + $n1;
		$arr[$j] = $arr[$j]*16 + $n2;
	}
	@arr;
}

sub get_hex_args_shift {
	my $arg = 0;
	$arg = $arg*16 + rnd->in_range(1, 15) for (1..8);
	($arg, rnd->pick(4, 8, 12));
}

sub swap_commands {
	my ($self, $id1, $id2) = @_;
	my $c = $self->{code}->[$id1];
	$self->{code}->[$id1] = $self->{code}->[$id2];
	$self->{code}->[$id2] = $c;
	$self;
}

sub move_command {
	my ($self, $from, $to) = @_;
	my $c = $self->{code}->[$from];
	my $i = $from;
	while ($i != $to) {
		($self->{code}->[$i], $i) = $from < $to ? ($self->{code}->[$i+1], $i+1) : ($self->{code}->[$i-1], $i-1);
	}
	$self->{code}->[$to] = $c;
	$self;
}

sub remove_command {
	my ($self, $id) = @_;
	$self->{code}->[$_] = $self->{code}->[$_+1] for ($id..$#{$self->{code}}-1);
	pop @{$self->{code}};
	$self;
}

sub generate_simple_code {
	my ($self, $type) = @_;
	my ($format, $n) = (rnd->pick(0,1)) ? ('%s', 8) : ('%08Xh', 32);
	my $reg = $self->get_reg($n);
	$self->{code} = [];
	if ($n == 8) {
		$self->generate_command('mov', $reg);
		$self->generate_command($type, $reg);
		$self->{code}->[0]->[2] = rnd->in_range(1, 15) * 16 + rnd->in_range(1, 15) if ($type eq 'shift');
	}
	else {
		my ($arg1, $arg2) = $self->get_hex_args($type);
		$self->generate_command('mov', $reg, $arg1);
		$self->generate_command($type, $reg, $arg2);
	}
	($reg, $format, $n, cgen->{code}->[0]->[2]);
}

1;
