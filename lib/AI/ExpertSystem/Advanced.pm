#
# AI::ExpertSystem::Advanced
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 18:28:30 CST 18:28:30
package AI::ExpertSystem::Advanced;

=head1 NAME

AI::ExpertSystem::Advanced - Expert System with backward, forward and mixed algorithms

=head1 DESCRIPTION

Inspired in L<AI::ExpertSystem::Simple> but with additional features:

=over 4

=item *

Uses backward, forward and mixed algorithms.

=item *

Offers different views, so user can interact with the expert system via a
terminal or with a friendly user interface.

=item *

The knowledge database can be stored in any format such as YAML, XML or
databases. You just need to choose what driver to use and you are done.

=item *

Uses certainty factors.

=back

=cut
use Moose;
use AI::ExpertSystem::Advanced::KnowledgeDB::Base;
use AI::ExpertSystem::Advanced::Viewer::Base;
use AI::ExpertSystem::Advanced::Viewer::Factory;
use AI::ExpertSystem::Advanced::Dictionary;
use Time::HiRes qw(gettimeofday);
use YAML::Syck qw(Dump);

our $VERSION = '0.02';

=head1 Attributes

=over 4

=item B<initial_facts>

A list/set of initial facts the algorithms start using.

During the forward algorithm the task is to find a list of goals caused
by these initial facts (the only data it has at that moment).

Lets imagine your knowledge database is about symptoms and diseases. You need
to find what diseases are caused by the symptoms of a patient, these first
symptons are the initial facts.

=cut
has 'initial_facts' => (
        is => 'rw',
        isa => 'ArrayRef[Str]',
        default => sub { return []; });

=item B<initial_facts_dict>

For making easier your job, L<AI::ExpertSystem::Advanced> asks you only the id
of the C<initial_facts>. Once you provide them then a dictinary is created.

This C<initial_facts_dict> dictionary basically provides a standard interface
to get the sign of the facts.

=cut
has 'initial_facts_dict' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Advanced::Dictionary');

=item B<goals_to_check>

When doing the C<backward()> algorithm it's needed to have at least one goal
(aka hypothesis).

This could be pretty similar to C<initial_facts>, with the difference that the
initial facts are used more with the causes of the rules, and this one with
the goals (usually one in a well defined knowledge database).

From our example of symptoms and diseases lets imagine we have the hypothesis
that a patient has flu, we don't know the symptoms it has, we want the
expert system to keep asking us for them to make sure that our hypothesis
is correct.

=cut
has 'goals_to_check' => (
        is => 'rw',
        isa => 'ArrayRef[Str]',
        default => sub { return []; });

=item B<goals_to_check_dict>

Very similar to C<goals_to_check> (and indeed of C<initial_facts_dict>). We
want to make the job easier at the moment of assigning goals and based on this
only the list of goals is needed, then a dictionary will be created with the
data of C<goals_to_check>.

=cut
has 'goals_to_check_dict' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Advanced::Dictionary');

=item B<inference_facts>

Inference facts are basically the core of an expert system. These are facts
that are found and copied when the a set of facts (initial, inference or
asked) match with the causes of a goal.

C<inference_facts> is a L<AI::ExpertSystem::Advanced::Dictionary>, it will
store the name of the fact, the rule that caused these facts to be copied to
this dictionary, the sign and the algorithm that triggered the copy.

=cut
has 'inference_facts' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Advanced::Dictionary');
       
=item B<knowledge_db>

The object reference of the knowledge database L<AI::ExpertSystem::Advanced> is
using.

=cut
has 'knowledge_db' => (
        is => 'rw',
        isa => 'AI::ExpertSystem::Advanced::KnowledgeDB::Base',
        required => 1);

=item B<asked_facts>

During the C<backward()> algorithm there will be cases when there's no clarity
if a fact exists. In these cases the C<backward()> will be asking the user
(via automation or real questions) if a fact exists.

Going back to the C<initial_facts> example of symptoms and diseases. Imagine
the algorithm is checking a rule, some of the facts of the rule make a match
with the ones of C<initial_facts> or C<inference_facts> but some wont, for
these I<unsure> facts the C<backward()> will ask the user if a symptom (a fact)
exists. All these asked facts will be stored here.

=cut
has 'asked_facts' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Advanced::Dictionary');

=item B<visited_rules>

Keeps a record of all the rules the algorithms have visited and also the number
of causes each rule has.

=cut
has 'visited_rules' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Advanced::Dictionary');

=item B<verbose>

By default this is turned off. If you want to know what happens behind the
scenes turn this on.

Everything that needs to be debugged will be passed to the C<debug()> method
of your C<viewer>.

=cut
has 'verbose' => (
        is => 'rw',
        isa => 'Bool',
        default => 0);

=item B<viewer>

Is the object L<AI::ExpertSystem::Advanced> will be using for printing what is
happening and for interacting with the user (such as asking the
C<asked_facts>).

This is practical if you want to use a viewer object that is not provided by
L<AI::ExpertSystem::Advanced::Viewer::Factory>.

=cut
has 'viewer' => (
        is => 'rw',
        isa => 'AI::ExpertSystem::Advanced::Viewer::Base');

=item B<viewer_class>

Is the the class name of the C<viewer>.

You can decide to use the viewers L<AI::ExpertSystem::Advanced::Viewer::Factory>
offers, in this case you can pass the object or only the name of your favorite
viewer.

=cut
has 'viewer_class' => (
        is => 'rw',
        isa => 'Str',
        default => 'terminal');

=item B<found_factor>

In your knowledge database you can give different *weights* to the facts of
each rule (eg to define what facts have more I<priority>). During the
C<mixed()> algorithm it will be checking what causes are found in the
C<inference_facts> and in the C<asked_facts> dictionaries, then the total
number of matches (or total number of certainity factors of each fact) will
be compared versus the value of this factor, if it's higher or equal then the
rule will be triggered.

You can read the documentation of the C<mixed()> algorithm to know the two
ways this factor can be used.

=cut
has 'found_factor' => (
        is => 'rw',
        isa => 'Num',
        default => '0.5');

=item B<shot_rules>

All the rules that are shot are stored here. This is a hash, the key of each
item is the rule id while its value is the precision time when the rule was
shot.

The precision time is useful for knowing when a rule was shot and based on that
you can know what steps it followed so you can compare (or reproduce) them.

=back

=cut
has 'shot_rules' => (
        is => 'ro',
        isa => 'HashRef[Str]');

=head1 Constants

=over 4

=item * B<FACT_SIGN_NEGATIVE>

Used when a fact is negative, aka, a fact doesn't happen.

=cut
use constant FACT_SIGN_NEGATIVE => '-';

=item * B<FACT_SIGN_POSITIVE>

Used for those facts that happen.

=cut
use constant FACT_SIGN_POSITIVE => '+';

=item * B<FACT_SIGN_UNSURE>

Used when there's no straight answer of a fact, eg, we don't know if an answer
will change the result.

=back

=cut
use constant FACT_SIGN_UNSURE   => '~';

=head1 Methods

=head2 B<shoot($rule, $algorithm)>

Shoots the given rule. It will do the following verifications:

=over 4

=item *

Each of the facts (causes) will be compared against the C<initial_facts_dict>
and C<asked_facts> (in this order).

=item *

If an initial or asked fact matches with a cause but it's negative then all of
its goals (usually only one by rule) will be copied to the C<initial_facts_dict>
and C<inference_facts> with a negative sign, otherwise a positive sign will be
used.

=item *

Will add the rule to the C<shot_rules> hash.

=back

=cut
sub shoot {
    my ($self, $rule, $algorithm) = @_;

    $self->{'shot_rules'}->{$rule} = gettimeofday;

    my $rule_causes = $self->get_causes_by_rule($rule);
    my $rule_goals = $self->get_goals_by_rule($rule);
    my $any_negation = 0;
    $rule_causes->populate_iterable_array();
    while(my $caused_fact = $rule_causes->iterate) {
        # Now, from the current rule fact, any of the facts were marked
        # as *negative* from the initial facts? (read: user gave a list of
        # initial facts to work with but he also knows of certain facts
        # that should be excluded or facts that he knows should not modify
        # the final result)
        $any_negation = 0;
        while(my $initial_fact = $self->{'initial_facts_dict'}->iterate) {
            if ($initial_fact eq $caused_fact) {
                if ($self->is_fact_negative(
                            'initial_facts_dict',
                            $initial_fact)) {
                    $any_negation = 1;
                    last;
                }
            }
        }
        # so.. the fact is negative?
        # no, then perhaps we asked the user about it?
        while(my $asked_fact = $self->{'asked_facts'}->iterate) {
            if ($asked_fact eq $caused_fact) {
                if ($self->is_fact_negative(
                            'asked_facts',
                            $asked_fact)) {
                    $any_negation = 1;
                    last;
                }
            }
        }
        # anything negative?
        if ($any_negation) {
            last;
        }
    }
    my $sign = ($any_negation) ? FACT_SIGN_NEGATIVE : FACT_SIGN_POSITIVE;
    # Copy the goal(s) of this rule to our "initial facts"
    $self->copy_to_inference_facts($rule_goals, $sign, $algorithm, $rule);
}

=head2 B<is_rule_shot($rule)>

Verifies if the given C<$rule> has been shot.

=cut
sub is_rule_shot {
    my ($self, $rule) = @_;

    return defined $self->{'shot_rules'}->{$rule};
}

=head2 B<get_goals_by_rule($rule)>

Will ask the C<knowledge_db> for the goals of the given C<$rule>. A
L<AI::ExpertSystem::Advanced::Dictionary> will be returned.

=cut
sub get_goals_by_rule {
    my ($self, $rule) = @_;
    return $self->{'knowledge_db'}->rule_goals($rule);
}

=head2 B<get_causes_by_rule($rule)>

Will ask the C<knowledge_db> for the causes of the given C<$rule>. A
L<AI::ExpertSystem::Advanced::Dictionary> will be returned.

=cut
sub get_causes_by_rule {
    my ($self, $rule) = @_;
    return $self->{'knowledge_db'}->rule_causes($rule);
}

=head2 B<is_fact_negative($dict_name, $fact)>

Will check if the given C<$fact> of the given dictionary (C<$dict_name>) is
negative.

=cut
sub is_fact_negative {
    my ($self, $dict_name, $fact) = @_;

    my $sign = $self->{$dict_name}->get_value($fact, 'sign');
    if (!defined $sign) {
        confess "This fact ($fact) does not exists!";
    }
    return $sign eq FACT_SIGN_NEGATIVE;
}

=head2 B<copy_to_inference_facts($facts, $sign, $algorithm, $rule)>

Copies the given C<$facts> (a dictionary, usually goal(s) of a rule) to the
C<inference_facts> dictionary. All the given goals will be copied with the
given C<$sign>.

Additionally it will add the given C<$algorithm> and C<$rule> to the inference
facts. So later we can know how we got to a certain inference fact.

=cut
sub copy_to_inference_facts {
    my ($self, $facts, $sign, $algorithm, $rule) = @_;

    while(my $fact = $facts->iterate) {
        $self->{'inference_facts'}->append(
                $fact,
                {
                    name => $fact,
                    sign => $sign,
                    factor => 0.0,
                    algorithm => $algorithm,
                    rule => $rule
                });
    }
}

=head2 B<compare_causes_with_facts($rule)>

Compares the causes of the given C<$rule> with:

=over 4

=item *

Initial facts

=item *

Inference facts

=item *

Asked facts

=back

It will be couting the matches of all of the above dictionaries, so for example
if we have four causes, two make match with initial facts, other with inference
and the remaining one with the asked facts, then it will evaluate to true since
we have a match of the four causes.

=cut
sub compare_causes_with_facts {
    my ($self, $rule) = @_;
    
    my $causes = $self->get_causes_by_rule($rule);
    my $match_counter = 0;
    my $causes_total = $causes->size();
    
    while (my $cause = $causes->iterate) {
        foreach my $dict (qw(initial_facts_dict inference_facts asked_facts)) {
            if ($self->{$dict}->find($cause)) {
                $match_counter++;
            }
        }
    }
    return $match_counter eq $causes_total;
}

=head2 B<get_causes_match_factor($rule)>

Similar to C<compare_causes_with_facts()> but with the difference that it will
count the I<match factor> of each matched cause and return the total of this
weight.

The match factor is used by the C<mixed()> algorithm and is useful to know if
a certain rule should be shoot or not.

The I<match factor> is calculated in two ways:

=over 4

=item *

Will do a sum of the weight for each matched cause. Please note that if only
one cause of a rule has a specified weight then the remaining causes will 
default to the total weight minus 1 and then divided with the total number
of causes (matched or not) that don't have a weight.

=item *

If no weight is found with all the causes of the given rule, then the total
number of matches will be divided by the total number of causes.

=back

=cut
sub get_causes_match_factor {
    my ($self, $rule) = @_;

    my $causes = $self->get_causes_by_rule($rule);
    my $causes_total = $causes->size();

    my ($factor_counter, $missing_factor, $match_counter, $nonfactor_match) =
        (0, 0, 0, 0);
    
    while (my $cause = $causes->iterate) {
        my $factor = $causes->get_value($cause, 'factor');
        if (!defined $factor) {
            $missing_factor++;
        }
        foreach my $dict (qw(initial_facts_dict inference_facts asked_facts)) {
            if ($self->{$dict}->find($cause)) {
                $match_counter++;
                if (defined $factor) {
                    $factor_counter = $factor_counter + $factor;
                } else {
                    $nonfactor_match++;
                }
            }
        }
    }
    # No matches?
    if ($match_counter eq 0) {
        return 0;
    }
    # None of the causes (matched or not) have a factor
    if ($causes_total eq $missing_factor) {
        return $match_counter / $causes_total;
    } else { # Some factors found
       if ($missing_factor) { # Oh, but some causes don't have it
           return $factor_counter + ($nonfactor_match / $causes_total);
       } else {
           return $factor_counter;
       }
    }
}

=head2 B<is_goal_in_our_facts($goal)>

Checks if the given C<$goal> is in:

=over 4

=item *

The asked facts

=item *

The inference facts

=back

=cut
sub is_goal_in_our_facts {
    my ($self, $goal) = @_;

    foreach my $dict (qw(asked_facts inference_facts)) {
        if (my $fact = $self->{$dict}->find($goal)) {
            return 1;
        }
    }
    return undef;
}

=head2 B<remove_last_ivisited_rule()>

Removes the last visited rule and return its number.

=cut
sub remove_last_visited_rule {
    my ($self) = @_;

    my $last = $self->{'visited_rules'}->iterate;
    if (defined $last) {
        $self->{'visited_rules'}->remove($last);
        $self->{'visited_rules'}->populate_iterable_array();
    }
    return $last;
}

=head2 B<visit_rule($rule, $total_causes)>

Adds the given C<$rule> to the end of the C<visited_rules>.

=cut
sub visit_rule {
    my ($self, $rule, $total_causes) = @_;

    $self->{'visited_rules'}->prepend($rule,
            {
                causes_total => $total_causes,
                causes_pending => $total_causes
            });
    $self->{'visited_rules'}->populate_iterable_array();
}

=head2 B<copy_to_goals_to_check($rule, $facts)>

Copies a list of facts (usually a list of causes of a rule) to
<goals_to_check_dict>.

The rule of the goals that are being copied is stored also in the hash.

=cut
sub copy_to_goals_to_check {
    my ($self, $rule, $facts) = @_;

    while(my $fact = $facts->iterate_reverse) {
        $self->{'goals_to_check_dict'}->prepend(
                $fact,
                {
                    name => $fact,
                    sign => $facts->get_value($fact, 'sign'),
                    rule => $rule
                });
    }
}

=head2 B<ask_about($fact)>

Uses C<viewer> to ask the user for the existence of the given C<fact>.

The valid answers are:

=over 4

=item B<+> or C<FACT_SIGN_POSITIVE>

In case user knows of it.

=item B<-> or C<FACT_SIGN_NEGATIVE>

In case user doesn't knows of it.

=item B<~> or C<FACT_SIGN_UNSURE>

In case user doesn't have any clue about the given fact.

=back

=cut
sub ask_about {
    my ($self, $fact) = @_;

    # The knowledge db has questions for this fact?
    my $question = $self->{'knowledge_db'}->get_question($fact);
    if (!defined $question) {
        $question = "Do you have $fact?";
    }
    my @options = qw(Y N U);
    my $answer = $self->{'viewer'}->ask($question, @options);
    return $answer;
}

=head2 B<get_rule_by_goal($goal)>

Looks in the C<knowledge_db> for the rule that has the given goal. If a rule
is found its number is returned, otherwise undef.

=cut
sub get_rule_by_goal {
    my ($self, $goal) = @_;

    return $self->{'knowledge_db'}->find_rule_by_goal($goal);
}

=head2 B<forward()>

The forward chaining algorithm is one of the main methods used in Expert
Systems. It starts with a set of variables (known as initial facts) and reads
the available rules.

It will be reading rule by rule and for each one it will compare its causes
with the initial facts and with the inference facts. If all of these causes
are in our facts then the rule will be shoot and all of its goals will be
copied/converted to inference facts and will restart reading from the first
rule.

=cut
sub forward {
    my ($self) = @_;

    confess "Can't do forward algorithm with no initial facts" unless
        $self->{'initial_facts_dict'};

    my ($more_rules, $current_rule) = (1, undef);
    while($more_rules) {
        $current_rule = $self->{'knowledge_db'}->get_next_rule($current_rule);

        # No more rules?
        if (!defined $current_rule) {
            $self->{'viewer'}->debug("We are done with all the rules, bye")
                if $self->{'verbose'};
            $more_rules = 0;
            last;
        }

        $self->{'viewer'}->debug("Checking rule: $current_rule") if
            $self->{'verbose'};
        
        if ($self->is_rule_shot($current_rule)) {
            $self->{'viewer'}->debug("We already shot rule: $current_rule")
                if $self->{'verbose'};
            next;
        }

        $self->{'viewer'}->debug("Reading rule $current_rule")
            if $self->{'verbose'};
        $self->{'viewer'}->debug("More rules to check, checking...")
            if $self->{'verbose'};

        my $rule_causes = $self->get_causes_by_rule($current_rule);
        # any of our rule facts match with our facts to check?
        if ($self->compare_causes_with_facts($current_rule)) {
            # shoot and start again
            $self->shoot($current_rule, 'forward');
            # Undef to start reading from the first rule.
            $current_rule = undef;
            next;
        }
    }
    return 1;
}

=head2 B<backward()>

The backward algorithm starts with a set of I<assumed> goals (facts). It will
start reading goal by goal. For each goal it will check if it exists in the
C<asked_facts> and C<inference_facts>.

=over 4

=item *

If the goal exist then it will be removed from the dictionary, it will also
verify if there are more visited rules to shoot.

If there are still more visited rules to shoot then it will take the last one
and remove it. Then this visited rule will be shoot. Once the rule is shoot
it verifies if there are still still more goals to check, if this is the case
then it starts reading from the first goal (at this time the
C<goals_to_check_dict> is reduced by 1. However if there are no more goals to
check then it will finish, making the end of the algorithm.

In case there are no more visited rules to shoot then it will finish making
the end of the algorithm.

=item *

If the goal doesn't exist in the C<asked_facts> or C<inference_facts> then the
goal will be searched in the list of goals of all the rules.

In case it finds the rule that has the goal, this rule will be marked (added)
to the list of visited rules (C<visited_rules>). Also all of the causes of this
rule will be added to the top of the C<goals_to_check_dict>. Once this is done
it will start reading again all of the goals to check.

If there's the case where the goal doesn't exist as a goal in our rules then
it will ask the user (via C<ask_about>) for the existence of it. If user is not
sure about it then the algorithm ends.

=back

=cut
sub backward {
    my ($self) = @_;

    my ($more_goals, $current_goal, $total_goals) = (
            1,
            0,
            scalar(@{$self->{'goals_to_check'}}));
    
    WAIT_FOR_MORE_GOALS: while($more_goals) {
        READ_GOAL: while(my $goal = $self->{'goals_to_check_dict'}->iterate) {
            if ($self->is_goal_in_our_facts($goal)) {
                $self->{'viewer'}->debug("The goal $goal is in our facts")
                    if $self->{'debug'};
                # Matches with any visiited rule?
                my $rule_no = $self->{'goals_to_check_dict'}->get_value(
                        $goal, 'rule');
                # Take out this goal so we don't end with an infinite loop
                $self->{'viwer'}->debug("Removing $goal from goals to check")
                    if $self->{'debug'};
                $self->{'goals_to_check_dict'}->remove($goal);
                # Update the iterator
                $self->{'goals_to_check_dict'}->populate_iterable_array();
                # no more goals, what about rules?  
                if ($self->{'visited_rules'}->size() eq 0) {
                    $self->{'viewer'}->debug("No more goals to read")
                        if $self->{'verbose'};
                    $more_goals = 0;
                    next WAIT_FOR_MORE_GOALS;
                }
                if (defined $rule_no) {
                    my $causes_total = $self->{'visited_rules'}->get_value(
                            $rule_no, 'causes_total');
                    my $causes_pending = $self->{'visited_rules'}->get_value(
                            $rule_no, 'causes_pending');
                    if (defined $causes_total and defined $causes_pending) {
                        # No more pending causes for this rule, lets shoot it
                        if ($causes_pending-1 le 0) {
                            my $last_rule = $self->remove_last_visited_rule();
                            if ($last_rule eq $rule_no) {
                                $self->{'viewer'}->debug("Going to shoot $last_rule")
                                    if $self->{'debug'};
                                $self->shoot($last_rule, 'backward');
                            } else {
                                $self->{'viewer'}->print_error(
                                        "Seems the rule ($rule_no) of goal " .
                                        "$goal is not the same as the last " .
                                        "visited rule ($last_rule)");
                                $more_goals = 0;
                                next WAIT_FOR_MORE_GOALS;
                            }
                        } else {
                            $self->{'visited_rules'}->update($rule_no,
                                    {
                                        causes_pending => $causes_pending-1
                                    });
                        }
                    }
                }
                # How many objetives we have? if we are zero then we are done
                if ($self->{'goals_to_check_dict'}->size() lt 0) {
                    $more_goals = 0;
                } else {
                    $more_goals = 1;
                }
                # Re verify if there are more goals to check
                next WAIT_FOR_MORE_GOALS;
            } else {
                # Ugh, the fact is not in our inference facts or asked facts,
                # well, lets find the rule where this fact belongs
                my $rule_of_goal =  $self->get_rule_by_goal($goal);
                if (defined $rule_of_goal) {
                    $self->{'viewer'}->debug("Found a rule with $goal as a goal")
                        if $self->{'debug'};
                    # Causes of this rule
                    my $rule_causes = $self->get_causes_by_rule($rule_of_goal);
                    # Copy the causes of this rule to our goals to check
                    $self->copy_to_goals_to_check($rule_of_goal, $rule_causes);
                    # We just *visited* this rule, lets check it
                    $self->visit_rule($rule_of_goal, $rule_causes->size());
                    # and yes.. we have more goals to check!
                    $self->{'goals_to_check_dict'}->populate_iterable_array();
                    $more_goals = 1;
                    next WAIT_FOR_MORE_GOALS;
                } else {
                    # Ooops, lets ask about this
                    # We usually get to this case when any of the copied causes
                    # does not exists as a goal in any of the rules
                    my $answer = $self->ask_about($goal);
                    if (
                            $answer eq FACT_SIGN_POSITIVE or
                            $answer eq FACT_SIGN_NEGATIVE) {
                        $self->{'asked_facts'}->append($goal,
                                {
                                    name => $goal,
                                    sign => $answer,
                                    algorithm => 'backward'
                                });
                    } else {
                        $self->{'viewer'}->debug(
                                "Don't know of $goal, nothing else to check"
                                );
                        return 0;
                    }
                    $self->{'goals_to_check_dict'}->populate_iterable_array();
                    $more_goals = 1;
                    next WAIT_FOR_MORE_GOALS;
                }
            }
        }
    }
    return 1;
}

=head2 B<mixed()>

As its name says, it's a mix of C<forward()> and C<backward()> algorithms, it
requires to have at least one initial fact.

The first thing it does is to run the C<forward()> algorithm (hence the need of
at least one initial fact). If the algorithm fails then the mixed algorithm
also ends unsuccessfully.

Once the first I<run> of C<forward()> algorithm happens it starts looking for
any positive inference fact, if only one is found then this ends the algorithm
with the assumption it knows what's happening.

In case no positive inference fact was found then it will start reading the
rules and creating a list of intuitive facts.

For each rule it will get a I<certainty factor> of its causes versus the
C<initial_facts_dict>, C<inference_facts> and C<asked_facts>. In case the
certainity factor is greater or equal than C<found_factor> then all of its
goals will be copied to the intuitive facts (eg, read it as: it assumes the
goals have something to do with our first initial facts).

Once all the rules are read then it verifies for any intuitive fact, if no
facts are found then it ends with the intuition, otherwise it will run the
C<backward()> algorithm for each one of these facts (eg, each fact will
be converted to a goal). After each I<run> of the C<backward()> algorithm
it will verify for any positive inference fact, if just one is found then
the algorithm ends.

At the end (if there are still no positive inference facts) it will run
the C<forward()> algorithm and restarts (by looking again for any
positive inference fact).

A good example to understand how this algorithm is useful is: imagine you are
a doctor and know some of the symptoms and diseases of a patient. Then the
algorithm will start looking for any additional disease you could be missing.
Then once it ends looking for diseases it will check if we know what the
disease is (by looking for the positive fact). If there's still no clue then
it starts looking in I<viceversa>, now knowing a list of possible diseases and
also a list of symptoms. It repeats all the process until a positive
I<inference> fact is found.

=cut
sub mixed {
    my ($self) = @_;

    if (!$self->forward()) {
        $self->{'viewer'}->print_error("The first execution of forward failed");
        return 0;
    }

    while(1) {
        # We are satisfied if only one inference fact is positive (eg, means we
        # got to our result)
        while(my $fact = $self->{'inference_facts'}->iterate) {
            my $sign = $self->{'inference_facts'}->get_value($fact, 'sign');
            if ($sign eq FACT_SIGN_POSITIVE) {
                $self->{'viewer'}->debug(
                        "We are done, a positive fact was found"
                        );
                return 1;
            }
        }

#        my $intuitive_facts_array = [];
        my $intuitive_facts = AI::ExpertSystem::Advanced::Dictionary->new(
                stack => []);

        my ($more_rules, $current_rule) = (1, undef);
        while($more_rules) {
            $current_rule = $self->{'knowledge_db'}->get_next_rule($current_rule);

            # No more rules?
            if (!defined $current_rule) {
                $self->{'viewer'}->debug("We are done with all the rules, bye")
                    if $self->{'verbose'};
                $more_rules = 0;
                last;
            }

            # Wait, we already shot this rule?
            if ($self->is_rule_shot($current_rule)) {
                $self->{'viewer'}->debug("We already shot rule: $current_rule")
                    if $self->{'verbose'};
                next;
            }

            my $factor = $self->get_causes_match_factor($current_rule);
            if ($factor ge $self->{'found_factor'} && $factor lt 1.0) {
                # Copy all of the goals (usually only one) of the current rule to
                # the intuitive facts
                my $goals = $self->get_goals_by_rule($current_rule);
                while(my $goal = $goals->iterate_reverse) {
                   $intuitive_facts->append($goal,
                           {
                               name => $goal,
                               sign => $goals->get_value($goal, 'sign')
                           });
               }
            }
        }
        if ($intuitive_facts->size() eq 0) {
            $self->{'viewer'}->debug("Done with intuition") if
                $self->{'verbose'};
            return 1;
        }
        
        $intuitive_facts->populate_iterable_array();

        # now each intuitive fact will be a goal
        while(my $fact = $intuitive_facts->iterate) {
            $self->{'goals_to_check_dict'}->append(
                    $fact,
                    {
                        name => $fact,
                        sign => $intuitive_facts->get_value($fact, 'sign')
                    });
            $self->{'goals_to_check_dict'}->populate_iterable_array();
            if (!$self->backward()) {
                $self->{'viewer'}->debug("Backward exited");
            }
            # Now we have inference facts, anything positive?
            $self->{'inference_facts'}->populate_iterable_array();
            while(my $inference_fact = $self->{'inference_facts'}->iterate) {
                my $sign = $self->{'inference_facts'}->get_value(
                        $inference_fact, 'sign');
                if ($sign eq FACT_SIGN_POSITIVE) {
                    $self->{'viewer'}->print(
                            "Done, a positive inference fact found"
                            );
                    return 1;
                }
            }
        }
        $self->forward();
    }
}

=head2 B<summary($return)>

The main purpose of any expert system is the ability to explain: what is
happening, how it got to a result, what assumption it required to make,
which facts it excluded and which used.

This method will use the C<viewer> (or return the result) in YAML format of all
the rules that were shot. It will explain how it got to each one of the causes
so a better explanation can be done by the C<viewer>.

If C<$return> is defined (eg, it got any parameter) then the result wont be
passed to the C<viewer>, instead it will be returned as a string.

=cut
sub summary {
    my ($self, $return) = @_;

    # any facts we found via inference?
    if (scalar @{$self->{'inference_facts'}->{'stack'}} eq 0) {
        $self->{'viewer'}->print_error("No inference was possible");
    } else {
        my $summary = {};
        # How the rules started being shot?
        my $order = 1;
        # So, what rules we shot?
        foreach my $shot_rule (sort(keys %{$self->{'shot_rules'}})) {
            $summary->{'rules'}->{$shot_rule} = {
                order => $order,
            };
            $order++;
            # Get the causes and goals of this rule
            my $causes = $self->get_causes_by_rule($shot_rule);
            $causes->populate_iterable_array();
            while(my $cause = $causes->iterate) {
                # How we got to this cause? Is it an initial fact,
                # an inference fact? or by forward algorithm?
                my ($method, $sign, $algorithm);
                if ($self->{'asked_facts'}->find($cause)) {
                    $method = 'Question';
                    $sign = $self->{'asked_facts'}->get_value($cause, 'sign');
                    $algorithm = $self->{'asked_facts'}->get_value($cause, 'algorithm');
                } elsif ($self->{'inference_facts'}->find($cause)) {
                    $method = 'Inference';
                    $sign = $self->{'inference_facts'}->get_value($cause, 'sign');
                    $algorithm = $self->{'inference_facts'}->get_value($cause, 'algorithm');
                } elsif ($self->{'initial_facts_dict'}->find($cause)) {
                    $method = 'Initial';
                    $sign = $self->{'initial_facts_dict'}->get_value($cause, 'sign');
                } else {
                    $method = 'Forward';
                    $sign = $causes->get_value($cause, 'sign');
                }
                $summary->{'rules'}->{$shot_rule}->{'causes'}->{$cause} = {
                    method => $method,
                    sign => $sign,
                    algorithm => $algorithm,
                };
            }

            my $goals = $self->get_goals_by_rule($shot_rule);
            $goals->populate_iterable_array();
            while(my $goal = $goals->iterate) {
                # We got to this goal by asking the user of it? or by
                # "natural" backward algorithm?
                my ($method, $sign, $algorithm);
                if ($self->{'asked_facts'}->find($goal)) {
                    $method = 'Question';
                    $sign = $self->{'asked_facts'}->get_value($goal, 'sign');
                } elsif ($self->{'inference_facts'}->find($goal)) {
                    $method = 'Inference';
                    $sign = $self->{'inference_facts'}->get_value($goal, 'sign');
                    $algorithm = $self->{'inference_facts'}->get_value($goal, 'algorithm');
                } else {
                    $method = 'Backward';
                    $sign = $goals->get_value($goal, 'sign');
                }
                $summary->{'rules'}->{$shot_rule}->{'goals'}->{$goal} = {
                    method => $method,
                    sign => $sign,
                    algorithm => $algorithm,
                }
            }
        }
        my $yaml_summary = Dump($summary);
        if (defined $return) {
            return $yaml_summary;
        } else {
            $self->{'viewer'}->explain($yaml_summary);
        }
    }
}

# No need to document this, this is an *internal* Moose method, used when an
# instance of the class has been created and all the verifications (of valid
# parameters) have been done.
sub BUILD {
    my ($self) = @_;

    if (!defined $self->{'viewer'}) {
        if (defined $self->{'viewer_class'}) { 
            $self->{'viewer'} = AI::ExpertSystem::Advanced::Viewer::Factory->new(
                    $self->{'viewer_class'});
        } else {
            confess "Sorry, provide a viewer or a viewer_class";
        }
    }
    $self->{'initial_facts_dict'} = AI::ExpertSystem::Advanced::Dictionary->new(
            stack => $self->{'initial_facts'});
    $self->{'inference_facts'} = AI::ExpertSystem::Advanced::Dictionary->new;
    $self->{'asked_facts'} = AI::ExpertSystem::Advanced::Dictionary->new;
    $self->{'goals_to_check_dict'} = AI::ExpertSystem::Advanced::Dictionary->new(
            stack => $self->{'goals_to_check'});
    $self->{'visited_rules'} = AI::ExpertSystem::Advanced::Dictionary->new(
            stack => []);
}

=head1 SEE ALSO

Take a look L<AI::ExpertSystem::Simple> too.

=head1 AUTHOR
 
Pablo Fischer (pablo@pablo.com.mx).

=head1 COPYRIGHT
 
Copyright (C) 2010 by Pablo Fischer.
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

