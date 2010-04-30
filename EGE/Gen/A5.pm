package EGE::Gen::A5;

use strict;
use warnings;

use Bit::Vector;
use EGE::Random;
use EGE::Prog;

sub row {
    my $r = join '', map "<td>$_</td>", @_;
    "<tr>$r</tr>\n";
}

sub lang_row {
    my $prog = shift;
    row(map EGE::Prog::lang_names->{$_}, @_) .
    row(map '<pre>' . $prog->to_lang($_) . '</pre>', @_);
}

sub arith {

    my $v1 = rnd->in_range(1, 9);
    my $v2 = rnd->in_range(1, 9);
    my $v3 = rnd->in_range(2, 4);
    my $ab1 = rnd->pick('a', 'b');
    my @ab2 = rnd->shuffle('a', 'b');

    my $b = EGE::Prog::make_block([
        '=', 'a', \$v1,
        '=', $ab1, [ rnd->pick('+', '-'), 'a', \$v2 ],
        '=', 'b', [ '-', (rnd->coin ? 1 : ()), $ab1 ],
        '=', 'c', [ '+', [ '-', $ab2[0] ], [ '*', \$v3, $ab2[1] ] ],
    ]);

    my $q = q~
Определите значение переменной <i>c</i> после выполнения следующего
фрагмента программы:
<table border="1">
~;
    $q .=
        lang_row($b, 'Basic', 'Alg') .
        lang_row($b, 'Pascal', 'C') .
        "</table>\n";

    my $get_c = sub { $b->run_val('c', { @_ }) };

    my @errors;
    for my $var (\$v1, \$v2, \$v3) {
        $$var += 1;
        push @errors, $get_c->();
        $$var -= 2;
        push @errors, $get_c->();
        $$var += 1;
    }
    push @errors, $get_c->(_skip => $_) for 1 .. $b->count_ops;
    my $correct = $get_c->();
    my %seen = ($correct => 1);
    @errors = grep !$seen{$_}++, @errors;

    {
        question => $q,
        variants => [ $correct, rnd->pick_n(3, @errors) ],
        answer => 0,
        variants_order => 'random',
    };
}

sub div_mod_common {
    my ($q, $src, $get_fn) = @_;
    my $cc =
        ', вычисляющие результат деления нацело первого аргумента на второй '.
        'и остаток от деления соответственно';
    my $b = EGE::Prog::make_block([
        @$src,
        '#', {
            Basic => "</pre>\'\\ и MOD &mdash; операции$cc",
            Pascal => "</pre>{div и mod &mdash; операции$cc}",
            Alg => "</pre>|div и mod &mdash; функции$cc",
        },
    ]);

    my $get_v = sub {
        my $env = { @_ };
        $b->run($env);
        $get_fn->($env);
    };
    my $correct = $get_v->();
    $q .= q~ после выполнения следующего фрагмента программы:
<table border="1">
~ .
        lang_row($b, 'Basic', 'Pascal', 'Alg') .
        "</table>\n";

    my @errors;
    push @errors, $get_v->(_replace_op => $_),
        for { '%' => '//' }, { '//' => '%' }, { '%' => '//', '//' => '%' };
    push @errors, $get_v->(_skip => $_) for 1 .. $b->count_ops;

    my %seen = ($correct => 1);
    @errors = grep !$seen{$_}++, @errors;
    {
        question => $q,
        variants => [ $correct, rnd->pick_n(3, @errors) ],
        answer => 0,
        variants_order => 'random',
    };
}

sub div_mod_10 {
    my $v2 = rnd->in_range(2, 9);
    my $v3 = rnd->in_range(2, 9);
    return div_mod_common(
        'Определите значение целочисленных переменных <i>x</i> и <i>y</i>',
        [
            '=', 'x', [ '+', rnd->in_range(1, 9), [ '*', $v2, $v3 ] ],
            '=', 'y', [ '+', [ '%', 'x', 10 ], rnd->in_range(11, 19) ],
            '=', 'x', [ '+', [ '//', 'y', 10 ], rnd->in_range(1, 9) ],
        ],
        sub { "<i>x</i> = $_[0]->{x}, <i>y</i> = $_[0]->{y}" },
    );
}

sub div_mod_rotate {
    div_mod_common(
        'Переменные <i>x</i> и <i>y</i> описаны в программе как целочисленные. ' .
        'Определите значение переменной <i>x</i>',
        [
            '=', 'x', rnd->in_range(101, 999),
            '=', 'y', [ '//', 'x', 100 ],
            '=', 'x', [ '*', [ '%', 'x', 100 ], 10 ],
            '=', 'x', [ '+', 'x', 'y' ],
        ],
        sub { $_[0]->{x} },
    );
}

1;
