package Carp::Always::WithRefs;
use 5.006;
use strict;
use warnings;

use Carp qw(verbose);
use Scalar::Util qw(blessed);
use overload ();

our $VERSION = '0.001000';
$VERSION = eval $VERSION;

$Carp::Internal{+__PACKAGE__}++;
our %HaveTrace;
$HaveTrace{'Throwable::Error'}++;

sub _warn {
  warn _convert(@_);
}
sub _die {
  die _convert(@_);
}

my $pack_suffix = 'A000';
sub _convert {
  if (my $class = blessed $_[0]) {
    if (
      grep {
        $HaveTrace{$_}
        && $class->isa($_)
        || ($class->can('DOES') && $class->DOES($_))
      } keys %HaveTrace
    ) {
      die $_[0];
    }
    my $ex = $_[0];
    my $post = '__ANON_' . $pack_suffix++ . '__';
    my $newclass = __PACKAGE__ . "::$post";
    my $message = Carp::longmess();
    $message =~ s/\.?$/./m;
    my $stringify = overload::Method($ex, '""');
    my $string_call = $stringify ? '$stringify' : 'overload::StrVal';
    eval qq{
      package $newclass;
      our \@ISA = (\$class);
      use overload '""' => sub {
        bless \$_[0], \$class;
        my \$out = \$_[0] . \$message;
        bless \$_[0], \$newclass;
        return \$out;
      };
      sub DESTROY {
        no strict 'refs';
        delete \${'Carp::Always::WithRefs::'}{\$post};
        goto &${class}::DESTROY
          if defined &${class}::DESTROY;
        ();
      }
    };
    bless $ex, $newclass;
    $ex;
  }
  elsif (ref $_[0]) {
    # TODO
    @_;
  }
  elsif ((caller(1))[0] eq 'Carp') {
    @_;
  }
  else {
    my $message = Carp::longmess();
    $message =~ s/.*?\n//s;
    join('', @_, $message);
  }
}

my %OLD_SIG;

BEGIN {
  @OLD_SIG{qw(__DIE__ __WARN__)} = @SIG{qw(__DIE__ __WARN__)};
  $SIG{__DIE__} = \&_die;
  $SIG{__WARN__} = \&_warn;
}

END {
  @SIG{qw(__DIE__ __WARN__)} = @OLD_SIG{qw(__DIE__ __WARN__)};
}

1;
__END__

=encoding utf8

=head1 NAME

Carp::Always::WithRefs - Warns and dies noisily with stack backtraces

=head1 SYNOPSIS

  use Carp::Always::WithRefs;

makes every C<warn()> and C<die()> complains loudly in the calling package 
and elsewhere. More often used on the command line:

  perl -MCarp::Always::WithRefs script.pl

=head1 DESCRIPTION

This module is meant as a debugging aid. It can be
used to make a script complain loudly with stack backtraces
when warn()ing or die()ing.

Here are how stack backtraces produced by this module
looks:

  # it works for explicit die's and warn's
  $ perl -MCarp::Always::WithRefs -e 'sub f { die "arghh" }; sub g { f }; g'
  arghh at -e line 1
          main::f() called at -e line 1
          main::g() called at -e line 1

  # it works for interpreter-thrown failures
  $ perl -MCarp::Always::WithRefs -w -e 'sub f { $a = shift; @a = @$a };' \
                           -e 'sub g { f(undef) }; g'
  Use of uninitialized value in array dereference at -e line 1
          main::f('undef') called at -e line 2
          main::g() called at -e line 2

In the implementation, the C<Carp> module does
the heavy work, through C<longmess()>. The
actual implementation sets the signal hooks
C<$SIG{__WARN__}> and C<$SIG{__DIE__}> to
emit the stack backtraces.

Oh, by the way, C<carp> and C<croak> when requiring/using
the C<Carp> module are also made verbose, behaving
like C<cluck> and C<confess>, respectively.

Stack traces will also be included for exception objects.

Currently, stack traces are not included for non-object references
thrown as exceptions.

=head2 EXPORT

Nothing at all is exported.

=head1 ACKNOWLEDGMENTS

The idea, part of the code, and most of the documentation are taken
from L<Carp::Always>.

=head1 SEE ALSO

=over 4

=item *

L<Carp::Always>

=item *

L<Carp>

=item *

L<Acme::JavaTrace> and L<Devel::SimpleTrace>

=item *

L<Carp::Always::Color>

=item *

L<Carp::Source::Always>

=back

Please report bugs via CPAN RT 
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Carp-Always-WithRefs.

=head1 BUGS

This module uses several ugly tricks to do its work and surely has bugs.

=over 4

=item *

This module does not play well with other modules which fusses
around with C<warn>, C<die>, C<$SIG{'__WARN__'}>,
C<$SIG{'__DIE__'}>.

=back

=head1 AUTHORS

=item *

Graham Knop, E<lt>haarg@haarg.orgE<gt>

=item *

Adriano Ferreira, E<lt>ferreira@cpan.orgE<gt>

=back

=head1 CONTRIBUTORS

None yet.

=head1 COPYRIGHT

Copyright (c) 2005-2013 the L</AUTHORS> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<http://dev.perl.org/licenses/>.

=cut
