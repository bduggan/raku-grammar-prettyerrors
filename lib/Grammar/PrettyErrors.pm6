
use Terminal::ANSIColor;

class PrettyError {
    has $.parsed;
    has $.target;

	method generate-report($msg) {
		my @msg;
		@msg.push: "--errors--";
		unless $.parsed {
			@msg.push: "Rats, unable to parse anything, giving up.";
			@msg.push: $msg;
			return @msg;
		}
		my $line-no = $.parsed.lines.elems;
		my @lines = $.target.lines;
		my $first = ( ($line-no - 3) max 0 );
		my @near = @lines[ $first.. (($line-no + 3) min @lines-1) ];
		my $i = $line-no - 3 max 0;
		my $chars-so-far = @lines[0..^$first].join("\n").chars;
		my $error-position = $.parsed.chars;
		if %*ENV<NO_PRETTY_COLOR_ERRORS> {
			&color.wrap(-> | { "" });
		}
		for @near {
			$i++;
			if $i==$line-no {
				@msg.push: color('bold yellow') ~ $i.fmt("%3d") ~ " │▶"
						 ~ "$_" ~ color('reset') ~ "\n";
				@msg.push: "     " ~ '^'.indent($error-position - $chars-so-far);
			} else {
				@msg.push: color('green') ~ $i.fmt("%3d") ~ " │ " ~ color('reset') ~ $_;
				$chars-so-far += .chars;
				$chars-so-far++;
			}
		}
		@msg.push: "";
		@msg.push: "Uh oh, something went wrong around line $line-no.\n";
		@msg.push: "Unable to parse $*LASTRULE." if $*LASTRULE;
		return @msg;
	}

    method report($msg = '') {
        say self.generate-report($msg).join("\n");
    }
}

role Grammar::PrettyErrors {
    has $!error;
    has $.quiet;

    method new(|c) {
      return callsame unless self.defined;
      self.^find_method('ws').wrap: -> $self, |rest {
            say 'in wrap';
            $*HIGHWATER = $self.pos if $self.pos > $*HIGHWATER;
            $*LASTRULE = callframe(4).code.name;
            callsame;
      };
      callsame;
    }

    multi method report-error($msg) {
        self.report-error(self.target,$msg);
    }

    multi method report-error($target,$msg) {
        my $parsed = $target.substr(0, $*HIGHWATER).trim-trailing;
        $!error = PrettyError.new(:$parsed,:$target);
        $!error.report($msg) unless $.quiet;
    }

    method parse($target, |c) {
        my $*HIGHWATER = 0;
        my $*LASTRULE;
        my $match = callsame;
        self.report-error($target, "Parsing error.") unless $match;
        return $match;
    }
}
