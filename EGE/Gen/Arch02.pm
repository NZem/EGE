# Copyright © 2013 Natalia D. Zemlyannikova
# Licensed under GPL version 2 or later.
# http://github.com/NZem/EGE
package EGE::Gen::Arch02;
use base 'EGE::GenBase::MultipleChoice';

use strict;
use warnings;
use utf8;

use EGE::Random;
use EGE::Asm::Processor;
use EGE::Asm::AsmCodeGenerate;

sub flags_value_add {
	my $self = shift;
	$self->flags_value('add');
}

sub flags_value_logic {
	my $self = shift;
	$self->flags_value('logic');
}

sub flags_value_shift {
	my $self = shift;
	$self->flags_value('shift');
}

sub flags_value {
	my ($self, $type) = @_;
	my ($reg, $format) = cgen->generate_simple_code($type);
	proc->run_code(cgen->{code});
	my $code_txt = cgen->get_code_txt($format);
	$self->{text} = <<QUESTION
В результате выполнения кода $code_txt будут установлены флаги:
QUESTION
;
	my @flags = keys %{proc->{eflags}};
	$self->variants(@flags);
	$self->{correct} = [ map proc->{eflags}->{$_}, @flags ];
	$self->flags_value($type) if !(grep $_, @{$self->{correct}});
}

1;
