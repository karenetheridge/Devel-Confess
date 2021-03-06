package Devel::Confess::_Util;
use 5.006;
use strict;
use warnings FATAL => 'all';
no warnings 'once';

use base 'Exporter';

our @EXPORT = qw(blessed refaddr weaken longmess _str_val);

use Carp ();
use Carp::Heavy ();
use Scalar::Util qw(blessed refaddr reftype);

# fake weaken if it isn't available.  will cause leaks, but this
# is a brute force debugging tool, so we can deal with it.
*weaken = defined &Scalar::Util::weaken
  ? \&Scalar::Util::weaken
  : sub ($) { 0 };

*longmess = !Carp->VERSION ? eval q{
  package
    Carp;
  our (%CarpInternal, %Internal, $CarpLevel);
  $CarpInternal{Carp}++;
  $CarpInternal{warnings}++;
  $Internal{Exporter}++;
  $Internal{'Exporter::Heavy'}++;
  sub {
    my $level = 0;
    while (1) {
      my $p = (caller($level))[0] || last;
      last
        unless $CarpInternal{$p} || $Internal{$p};
      $level++;
    }
    local $CarpLevel = $CarpLevel + $level;
    &longmess;
  };
} : Carp->VERSION <= 1.04 ? eval q{
  package
    Carp;
  our ($CarpLevel);
  sub {
    local $INC{'Carp/Heavy.pm'} = $INC{'Carp/Heavy.pm'} || 1;
    &longmess;
  };
} : \&Carp::longmess;

if (defined &Carp::format_arg && $Carp::VERSION < 1.32) {
  my $format_arg = \&Carp::format_arg;
  eval q{
    package
      Carp;
    our $in_recurse;
    $format_arg; # capture
    no warnings 'redefine';
    sub format_arg {
      if (! $in_recurse) {
        local $SIG{__DIE__} = sub {};
        local $in_recurse = 1;
        local $@;

        my $arg;
        if (
          Scalar::Util::blessed($_[0])
          && eval { $_[0]->can('CARP_TRACE') }
        ) {
          return $_[0]->CARP_TRACE;
        }
        elsif (
          ref $_[0]
          and our $RefArgFormatter
          and eval { $arg = $RefArgFormatter->(@_); 1 }
        ) {
          return $arg;
        }
      }
      $format_arg->(@_);
    }
  } or die $@;
}

*_str_val = eval q{
  sub {
    no overloading;
    "$_[0]";
  };
} || eval q{
  sub {
    my $class = blessed($_[0]);
    return "$_[0]" unless defined $class;
    return sprintf("%s=%s(0x%x)", &blessed, &reftype, &refaddr);
  };
};

{
  if (defined ${^GLOBAL_PHASE}) {
    eval q{
      sub _global_destruction () { ${^GLOBAL_PHASE} eq q[DESTRUCT] };
      1;
    } or die $@;
  }
  else {
    eval q{
      our $gd;
      sub _global_destruction () {
        if (!$gd) {
          local $SIG{__WARN__} = sub { $gd = $_[0] =~ /global destruction\.\n\z/ };
          warn 1;
        }
        $gd;
      }
      1;
    } or die $@;
  }
}

1;
