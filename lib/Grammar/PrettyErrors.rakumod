use v6.d;
unit module Grammar::PrettyErrors;

use Terminal::ANSIColor;

class X::Grammar::PrettyError is Exception {
  has $.parsed;
  has $.target;
  has $!report;
  has Bool $.colors = True;
  has $.line = 0;
  has $.column = 0;
  has $.lastrule;

  method !generate-report($msg) {
    my @msg;
    @msg.push: "--errors--";
    unless $.parsed {
      @msg.push: "Rats, unable to parse anything, giving up.";
      @msg.push: $msg;
      return @msg;
    }
    my $line-no = $!line = $.parsed.lines.elems;
    my @lines = $.target.lines;
    my $first = ( ($line-no - 3) max 0 );
    my @near = @lines[ $first.. (($line-no + 3) min @lines-1) ];
    my $i = $line-no - 3 max 0;
    my $chars-so-far = @lines[0..^$first].join("\n").chars;
    my $error-position = $.parsed.chars;
    unless self and self.colors {
      &color.wrap(-> | { "" });
    }
    for @near {
      $i++;
      if $i==$line-no {
        $!column = $error-position - $chars-so-far;
        @msg.push: color('bold yellow') ~ $i.fmt("%3d") ~ " │▶" ~ "$_" ~ color('reset');
        @msg.push: "     " ~ '^'.indent($!column);
      } else {
        @msg.push: color('green') ~ $i.fmt("%3d") ~ " │ " ~ color('reset') ~ $_;
        $chars-so-far += .chars;
        $chars-so-far++;
      }
    }
    @msg.push: "";
    @msg.push: "Uh oh, something went wrong around line $line-no.";
    @msg.push: "Unable to parse $*LASTRULE." if $*LASTRULE;
    $!lastrule = ~$*LASTRULE;
    return @msg;
  }

  method report($msg = '') {
    $!report //= self!generate-report($msg).join("\n") ~ "\n";
    $!report;
  }

  method message {
    $!report;
  }
}

role Grammar::PrettyErrors[$ws = 'ws'] {
  has $.error;
  has $.quiet;
  has Bool $.colors = True;

  method new(|c) {
    return callsame unless self.defined;
    unless self.^find_method($ws).^name ~~ / 'Regex' / {
      if $ws eq 'ws' {
        my regex whitespace { <!ww> \s* }
        self.^add_method('ws', &whitespace );
        self.^compose;
      } else {
        die "Could not find rule $ws in grammar";
      }
    }
    self.^find_method($ws).wrap: -> $match, |rest {
       my $pos = $match.pos + 1;
       $*HIGHWATER = $pos if $pos > $*HIGHWATER;
       my $bt = Backtrace.new;
       my $rule = $bt[$bt.next-interesting-index(:named)].code.name;
       $*LASTRULE = $rule unless $rule eq 'enter';
       callsame;
    }
    callsame;
  }

  multi method report-error($msg) {
      self.report-error(self.target,$msg);
  }

  multi method report-error($target,$msg) is hidden-from-backtrace {
      my $parsed = $target.substr(0, $*HIGHWATER);
      my $colors = so (self.defined and self.colors);
      my $error = X::Grammar::PrettyError.new(:$parsed,:$target,:$colors);
      $error.report($msg);
      $!error = $error if self.defined;
      $error;
  }

  method parse( $target, |c) is hidden-from-backtrace {
      return self.new.parse($target, |c) without self;
      my $*HIGHWATER = 0;
      my $*LASTRULE;
      my $match = callsame;
      return $match if $match;
      my $failure = self.report-error($target, "Parsing error.");
      fail $failure unless $!quiet;
      Nil;
  }
}
