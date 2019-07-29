# A library for managing timeouts (wrappers around Promise.in)

enum RetryMode is export <
    immediate
    constant linear exponential fibonacci polynomial custom>;
enum RetryRandom is export <none always increasing first>;

class X::RetryLimit is Exception is export {
    has $.factor; #= Limiting factor that was exceeded
    has $.cause; #= Description of retry limit cause

    method message() {
        "{$!cause}: end of retries"
    }
}

class Retry is export {
    has RetryMode $.mode = RetryMode::constant;   #= See RetryMode
    has RetryRandom $.random = RetryRandom::none; #= Randomness?
    has $.max-attempts = Nil;                     #= Max calls to pause
    has $.max-elapsed = Nil;                      #= Max time units elapsed
    has $.scale;                                  #= Scaling applied
    has $.basis;                                  #= mode-dependent constant
    has @.sequence;                               #= Custom sequence

    # No user-serviceable parts, here:
    has $!last = 0;
    has $!counter = 0;
    has $!elapsed = 0;

    submethod BUILD(
        :$mode, :$random,
        :$!max-attempts=Nil,
        :$!max-elapsed=Nil,
        :$!basis=2,
        :$!scale=1,
        :@!sequence=()) {
        if $mode {
            $!mode = $mode ~~ RetryMode ?? $mode !! ::("RetryMode::$mode");
        }
        if $random {
            $!random = $random ~~ RetryRandom ??
                    $random !!
                    ::("RetryRandom::$random");
        }
    }

    method elapsed(Retry:D:) { $!elapsed }

    #= Return the amount of time to pause before next retry
    method pause(Retry:D: $current=$!last) {
        return 0 if self.mode eqv RetryMode::immediate;
        if $!counter == 0 {
            if self.mode eqv RetryMode::fibonacci {
                @!sequence = 1, 1, *+* ... *; # For RetryMode::fibonacci
                $!mode = RetryMode::custom;
            } elsif self.mode eqv RetryMode::custom and not @!sequence {
                die "No sequence available for custom retry mode";
            }
        }
        if self.max-attempts and $!counter >= self.max {
            fail X::RetryLimit.new(
                factor => 'attempts',
                cause => "Retry limit {self.max-attempts} reached");
        }
        $!elapsed += $current;
        my $pause = do given self.mode {
            when RetryMode::constant { self.basis }
            when RetryMode::linear { self.basis * ($!counter+1) }
            when RetryMode::custom {
                if self.sequence[$!counter].defined {
                    self.sequence[$!counter]
                } else {
                    fail X::RetryLimit.new(
                        factor => 'attempts',
                        cause => "End of custom retry reached");
                }
            }
            when RetryMode::exponential { self.basis ** ($!counter+1) }
            when RetryMode::polynomial { ($!counter+1) ** self.basis }
            default { die "Unknown retry mode $_" }
        }
        my $is-random = do given self.random {
            when RetryRandom::always { True }
            when RetryRandom::increasing { True }
            when RetryRandom::first { not $!counter }
            when RetryRandom::none { False }
            default { die "Unknown retry random mode $_" }
        }
        $pause *= self.scale;
        if $is-random {
            if self.random eqv RetryRandom::increasing {
                die "Increasing pause too small" if $pause < $current;
                $pause = rand * ($pause - $current) + $current;
            } else {
                $pause *= rand;
            }
        }
        if self.mode !eqv RetryMode::custom {
            $pause = $current if $pause < $current;
            $pause = self.basis*self.scale if $pause == 0;
        }
        if self.max-elapsed.defined and $!elapsed + $pause > self.max-elapsed {
            die X::RetryLimit.new(
                factor => 'elapsed',
                cause =>
                    "Max elapsed time {self.max-elapsed} would be exceeded " ~
                    "by pause {$pause}")
        }
        $!counter++;
        return $!last = $pause;
    }

    #= Results of self.pause as a Seq
    method Seq(Retry:D:) { {self.pause} ... * }
    #= self.pause as an Int
    method Int(Retry:D:) { self.pause.Int }
    #= self.pause as Num
    method Num(Retry:D:) { self.pause.Num }
    #= sleep self.pause seconds
    method sleep(Retry:D:) { sleep self.pause }

    #= Given a pause return value, does it represent a retry limit?
    method ran-out($value) {
        $value ~~ Failure and $value.exception ~~ X::RetryLimit;
    }

    method gist() {
        "'{self.mode} {self.WHAT.perl}' basis=$!basis, elapsed=$!elapsed, last=$!last"
    }
}

class Timeout is export {
    has Retry $.retry;
    has $.timeout;
    has $.signal;
    has &.code;

    multi method new(&code, :$retry is copy, :$timeout=1, :$signal='HUP') {
        if $retry ~~ Retry {
            # Nothing to do
        } elsif not $retry {
            $retry = Retry;
        } elsif $retry ~~ Str or $retry ~~ RetryMode {
            $retry = Retry.new(:mode($retry));
        } else {
            $retry = Retry.new(|$retry); # good luck?
        }

        self.bless(:&code, :$retry, :$timeout, :$signal);
    }

    method await(Timeout:D:) { await self.start }

    method start(Timeout:D:) {
        my $codepromise = start {&!code()};
        my $timepromise = $!timeout.defined ?? Promise.in($!timeout)
            !! Promise.new;

        sub retry($result) {
            if $!retry {
                my $pause = $!retry.pause;
                return $pause if Retry.ran-out($pause);
                sleep $pause;
                # Fingers crossed for tail recursion...
                return self.await;
            } else {
                return $result;
            }
        }

        Promise.anyof($codepromise, $timepromise).then({
            if $codepromise.status eqv PromiseStatus::Kept {
                if not $codepromise.result {
                    retry($codepromise.result);
                } else {
                    # XXX This fails. There does not appear to be a way
                    # to force the execution of a thread to stop...
                    # So much for timeouts!
                    $codepromise.kill($!signal);
                    $codepromise.result;
                }
            } else {
                retry(Nil);
            }
        });
    }
}

sub timeout(&code, :$timeout, :$retry, :$signal='HUP') is export {
    Timeout.new(&code, :$timeout, :$retry, :$signal).await;
}
