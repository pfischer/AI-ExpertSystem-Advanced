#
# AI::ExpertSystem::Complex
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 18:28:30 CST 18:28:30
package AI::ExpertSystem::Complex;

=head1 NAME

AI::ExpertSystem::Complex - Expert System with complete algorithms

=head1 DESCRIPTION

Inspired in L<AI::ExpertSystem::Simple> but with additional features, such as:

=over 4

=item *

Uses backward, forward and mixed algorithms.

=item *

Offers different views, so user can interact with the expert system via a
terminal or with a friendly user interface.

=item *

The knowledge database can be stored in any format such as YAML, XML or
databases. You just need to select what driver to use and you are done.

=item *

Uses certainty factors.


=back

=cut
use Moose;
use AI::ExpertSystem::Complex::KnowledgeDB::Base;
use AI::ExpertSystem::Complex::Viewer::Base;
use AI::ExpertSystem::Complex::Viewer::Factory;
use AI::ExpertSystem::Complex::Dictionary;
use AI::ExpertSystem::Complex::AdvancedDictionary;
use Time::HiRes qw(gettimeofday);
use YAML::Syck qw(Dump);

=head1 Attributes

=over 4

=item B<initial_facts>

A list/set of initial facts the forward andd backward algorithms will start
using.

During the forward algorithm the task is to find a list of goals caused
by these initial facts (the only data we have at the moment).

Lets imagine your knowledge database is about symptoms and diseases. You need
to find what diseases are caused by the symptoms of a patient, these first
symptons are the initial facts.

=cut
has 'initial_facts' => (
        is => 'rw',
        isa => 'ArrayRef[Str]');

=item B<initial_facts_dict>

For making easier your job, L<AI::ExpertSystem::Complex> asks you only the name
of the C<initial_facts>. Once you provide these initial facts then a dictinary
is created.

This C<initial_facts_dict> dictionary basically provides a standard interface
to get the sign of the facts and to add new facts as we start finding new
goals (remember that once a goal is found all of its causes will be part of
the initial facts).

=cut
has 'initial_facts_dict' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::Dictionary');

=item B<goals_to_check>

When doing the C<backward()> algorithm it's needed to have at least one goal
(aka hypothesis).

This could be pretty similar to C<initial_facts>, with the difference that the
initial facts are used more with the causes of the rules and the goals, well,
with the goals of each rule (usually one).

From our example of symptoms and diseases lets imagine we have the hypothesis
that a patient has flu, we don't know the symptoms it has, we want the
expert system to keep asking us for them to make sure that our hypothesis
is correct.

=cut
has 'goals_to_check' => (
        is => 'rw',
        isa => 'ArrayRef[Str]');

=item B<goals_to_check_dict>

Very similar to C<goals_to_check> (and indeed of C<initial_facts_dict>). We
want to make the job easier at the moment of assigning goals and based on this
only the list of goals is needed, then a dictionary will be created with the
data found in C<goals_to_check>.

=cut
has 'goals_to_check_dict' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::Dictionary');

=item B<inference_facts>

Inference facts are basically the core of an expert system. These are facts
that are found and copied when the a set of facts (initial or inference)
match with the causes of a goal.

C<inference_facts> is a L<AI::ExpertSystem::Complex::AdvancedDictionary>, it
will store the name of the fact, the rule that caused these facts to be copied
to this dictionary, the sign and the algorithm that triggered the copy.

=cut
has 'inference_facts' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::AdvancedDictionary');
       
=item B<knowledge_db>

The object reference of the knowledge database L<AI::ExpertSystem::Complex>
is using.

=cut
has 'knowledge_db' => (
        is => 'rw',
        isa => 'AI::ExpertSystem::Complex::KnowledgeDB::Base',
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
        isa => 'AI::ExpertSystem::Complex::Dictionary');

=item B<visited_rules>

Keeps a record of all the rules the algorithms have visited/checked. Some of
these rules may have been shot or not.

=cut
has 'visited_rules' => (
        is => 'ro',
        isa => 'HashRef[Str]');

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

Is the object L<AI::ExpertSystem::Complex> will be using for printing what is
happening and for interacting with the user (such as asking the
C<asked_facts>).

This is practical if you want to use a viewer object that is not provided by
L<AI::ExpertSystem::Complex::Viewer::Factory>.

=cut
has 'viewer' => (
        is => 'rw',
        isa => 'AI::ExpertSystem::Complex::Viewer::Base');

=item B<viewer_class>

Is the the class name of the C<viewer>.

You can decide to use the viewers L<AI::ExpertSystem::Complex::Viewer::Factory>
offers, in this case you can pass the object or only the class name of your
favorite viewer.

=cut
has 'viewer_class' => (
        is => 'rw',
        isa => 'Str',
        default => 'terminal');

=item B<found_factor>

In your knowledge database you can give different *weights* to the facts of
each rule (eg to define what facts have more priority than others). During the
C<backward()> algorithm it will be checking what causes are found in the
C<inference_facts> and in the C<asked_facts> dictionaries, then the total
number of matches (or total number of certainity factors of each fact) will
be compared against the value of this factor, if it's higher or equal then the
rule will be triggered.

You can read the documentation of the C<backward()> algorithm to know the two
ways this factor can be used.

=cut
has 'found_factor' => (
        is => 'rw',
        isa => 'Float');

=item B<shot_rules>

All the rules that are shot are stored here. This is a hash, the key of each
item is the rule id while its value is the precision time when the rule was
shot.

The precision time is useful to know when a rule was shot and based on that
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
triggered.

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
                if ($self->is_initial_fact_negative($initial_fact)) {
                    $any_negation = 1;
                    last;
                }
            }
        }
        # so.. the fact is negative?
        # no, then perhaps we aksed the user for some hints?
        while(my $asked_fact = $self->{'asked_facts'}->iterate) {
            if ($asked_fact eq $caused_fact) {
                if ($self->is_asked_fact_negative($asked_fact)) {
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
    # we want the sign "char"
    my $sign = ($any_negation) ? FACT_SIGN_NEGATIVE : FACT_SIGN_POSITIVE;
    # Copy the goal(s) of this rule to our "initial facts"
    $self->copy_goals_to_initial_facts($rule_goals, $sign, $algorithm, $rule);
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
L<AI::ExpertSystem::Complex::Dictionary> will be returned.

=cut
sub get_goals_by_rule {
    my ($self, $rule) = @_;
    return $self->{'knowledge_db'}->rule_goals($rule);
}

=head2 B<get_causes_by_rule($rule)>

Will ask the C<knowledge_db> for the causes of the given C<$rule>. A
L<AI::ExpertSystem::Complex::Dictionary> will be returned.

=cut
sub get_causes_by_rule {
    my ($self, $rule) = @_;
    return $self->{'knowledge_db'}->rule_causes($rule);
}

=head2 B<is_initial_fact_negative($fact)>

Verifies if the given initial fact is negative.

=cut
sub is_initial_fact_negative {
    my ($self, $fact) = @_;

    my $sign = $self->{'initial_facts_dict'}->get_sign($fact);
    if (!defined $sign) {
        confess "This fact ($fact) does not exists!";
    }
    return $sign eq FACT_SIGN_NEGATIVE;
}

=head2 B<is_asked_fact_negative($fact)>

Verifies if the given asked fact is negative

=cut
sub is_asked_fact_negative {
    my ($self, $fact) = @_;

    my $sign = $self->{'asked_facts'}->get_sign($fact);
    if (!defined $sign) {
        confess "This fact ($fact) does not exists!";
    }
    return $sign eq FACT_SIGN_NEGATIVE;
}

=head2 B<copy_goals_to_initial_facts($goals, $sign, $algorithm, $rule)>

Copies the given C<$goals> (a dictionary) to the C<initial_facts_dict> and
C<inference_facts> dictionaries. All the given goals will be copied with
the given C<$sign>.

Additionally it will add the given C<$algorithm> and C<$rule> to the inference
facts.

=cut
sub copy_goals_to_initial_facts {
    my ($self, $goals, $sign, $algorithm, $rule) = @_;

    while(my $goal = $goals->iterate) {
        # we need to add the goal to our "inference/guessed" facts too 
        $self->{'inference_facts'}->add(
                $goal,
                $goal,
                $sign,
                0.0, # the factor
                $algorithm,
                $rule);
        # and now well, add it to initial facts
        $self->{'initial_facts_dict'}->add(
                $goal,
                $goal,
                $sign);
    }
}

=head2 B<compare_facts($dictionary_one, $dictionary_two)>

Returns true if B<all> the elements of C<$dictionary_two> exist
in C<$dictionary_one>, otherwise it returns false.

=cut
sub compare_facts {
    my ($self, $dictionary_one, $dictionary_two) = @_;

    my $size_two = scalar(@{$$dictionary_two->{'stack'}});
    my $match_counter = 0;
    foreach my $fact (@{$$dictionary_two->{'stack'}}) {
        if ($$dictionary_one->find($fact)) {
            $match_counter++
        }
    }
    return $match_counter eq $size_two;
}

=head2 B<forward()>

The forward chaining algorithm is one of the main methods used in Expert
Systems. It starts with a set of variables (known as initial facts) and reads
the available until it finds one or more goals.

It will be reading rule by rule and for every rule it will compare the causes
of each rule (usually a rule points to one goal) with the initial facts and
with the inference facts. If there's a complete match of causes with the
mentioned facts then the rule will be shoot and all of its goals will be
copied/converted to initial and inference facts.

If there's a match of causes and initial/inference facts then it will start
start reading the rules from the beginning (excluding those that are already
shot). If it goes to the last rule and there are no matches then it assumes
no goals could be found.

=cut
sub forward {
    my ($self) = @_;

    confess "Can't do forward algorithm with no initial facts" unless
        $self->{'initial_facts_dict'};

    my ($more_rules, $current_rule, $total_rules) = (
            1,
            0,
            scalar(@{$self->{'knowledge_db'}->rules})-1);
    while($more_rules) {
        $self->{'viewer'}->debug("Checking rule: $current_rule") if
            $self->{'verbose'};

        # Wait, we already shot this rule?
        if ($self->is_rule_shot($current_rule)) {
            $self->{'viewer'}->debug("We already shot rule: $current_rule")
                if $self->{'verbose'};
            $current_rule++;
            next;
        }

        # hmm.. we still have more rules to shot?
        if ($current_rule > $total_rules) {
            $self->{'viewer'}->debug("We are done with all the rules, bye")
                if $self->{'verbose'};
            $more_rules = 0;
            last;
        }

        $self->{'viewer'}->debug("Reading rule $current_rule of $total_rules")
            if $self->{'verbose'};
        $self->{'viewer'}->debug("More rules to check, checking...")
            if $self->{'verbose'};

        my $rule_causes = $self->get_causes_by_rule($current_rule);
        # any of our rule facts match with our facts to check?
        if ($self->compare_facts(\$self->{'initial_facts_dict'}, \$rule_causes)) {
            # shoot and start again
            $self->shoot($current_rule, 'forward');
            $current_rule = 1;
            next;
        }
        # nothing here, check the next one..
        $current_rule++
    }
}

=head2 B<backward()>

=cut
sub backward {
    my ($self) = @_;

    my ($more_goals, $current_goal, $total_goals) = (
            1,
            0,
            scalar(@{$self->{'goals_to_check'}}));
    
    while($more_goals) {
        while(my $goal = $self->{'goals_to_check_dict'}->iterate) {
            if ($self->is_goal_in_our_facts($goal)) {
                # Take out this goal so we don'tend with an infinite loop
                $self->{'goals_to_check_dict'}->remove($goal);
                # Update the iterator
                $self->{'goals_to_check_dict'}->populate_iterable_array();
                # How many items we have?
                if ($self->{'goals_to_check_dict'}->iterable_size() eq 0) {
                    # no more goals, what about rules?  
                    if (scalar(@{$self->{'visited_rules'}})) {
                        $self->{'viewer'}->debug("No more goals to read")
                            if $self->{'verbose'};
                        $more_goals = 0;
                        next;
                    }
                    # Take out the last visited rule and shoot it
                    my $last_rule = $self->remove_last_visited_rule();
                    $self->shoot($last_rule, 'backward');
                }
                # Re verify if there are more goals to check
                $more_goals = $self->more_goals_to_check();
                next;
            } else {
                # Ugh, the fact is not in our inference facts or asked facts,
                # well, lets find the rule where this fact belongs
                if (my $rule_of_goal = $self->get_rule_by_goal($goal)) {
                    # Causes of this rule
                    my $rule_causes = $self->get_causes_by_rule($rule_of_goal);
                    # Copy the causes of this rule to our goals to check
                    $self->copy_to_goals_to_check($rule_causes);
                    # We just *visited* this rule, lets check it
                    $self->visit_rule($rule_of_goal);
                    # and yes.. we have more goals to check!
                    $self->{'goals_to_check_dict'}->populate_iterable_array();
                    $more_goals = 1;
                    next;
                } else {
                    # Ooops, lets ask about this
                    # We usually get to this case when any of the copied causes
                    # does not exists as a goal in any of the rules
                    $self->ask_about($goal);
                    $more_goals = 1;
                    next;
                }
            }
        }
    }
}

sub summary {
    my ($self) = @_;

    use Data::Dumper;
    # any facts we found via inference?
    if (scalar @{$self->{'inference_facts'}->{'stack'}} eq 0) {
        $self->{'viewer'}->print_error("No inference was possible");
    } else {
        my $summary = {};
        # How the rules started being shot?
        print Dumper($self->{'shot_rules'});
        # So, what rules we shot?
        foreach my $shot_rule (sort(keys %{$self->{'shot_rules'}})) {
            $summary->{'rules'}->{$shot_rule} = {};
            # Get the causes and goals of this rule
            my $causes = $self->get_causes_by_rule($shot_rule);
            $causes->populate_iterable_array();
            while(my $cause = $causes->iterate) {
                # How we got to this cause? Is it an initial fact,
                # an inference fact? or by forward algorithm?
                my ($method, $sign);
                if ($self->{'inference_facts'}->find($cause)) {
                    $method = 'Inference';
                    $sign = $self->{'inference_facts'}->get_sign($cause);
                } elsif ($self->{'initial_facts_dict'}->find($cause)) {
                    $method = 'Initial';
                    $sign = $self->{'initial_facts_dict'}->get_sign($cause);
                } else {
                    $method = 'Forward';
                    $sign = $causes->get_sign($cause);
                }
                $summary->{'rules'}->{$shot_rule}->{'causes'}->{$cause} = {
                    method => $method,
                    sign => $sign
                };
            }

            my $goals = $self->get_goals_by_rule($shot_rule);
            $goals->populate_iterable_array();
            while(my $goal = $goals->iterate) {
                # We got to this goal by asking the user of it? or by
                # "natural" backward algorithm?
                my ($method, $sign);
                if ($self->{'asked_facts'}->find($goal)) {
                    $method = 'Question';
                    $sign = $self->{'asked_facts'}->get_sign($goal);
                } else {
                    $method = 'Backward';
                    $sign = $goals->get_sign($goal);
                }
                $summary->{'rules'}->{$shot_rule}->{'goals'}->{$goal} = {
                    method => $method,
                    sign => $sign,
                }
            }
        }
        print Dump($summary);
#        print Dumper($self->{'initial_facts_dict'});
#        print Dumper($self->{'inference_facts'});
    }
}

# No need to document this, this is an *internal* Moose method, used when an
# instance of the class has been created and all the verifications (of valid
# parameters) have been done.
sub BUILD {
    my ($self) = @_;

    if (!defined $self->{'viewer'}) {
        if (defined $self->{'viewer_class'}) { 
            $self->{'viewer'} = AI::ExpertSystem::Complex::Viewer::Factory->new(
                    $self->{'viewer_class'});
        } else {
            confess "Sorry, provide a viewer or a viewer_class";
        }
    }
    $self->{'initial_facts_dict'} = AI::ExpertSystem::Complex::Dictionary->new(
            stack => $self->{'initial_facts'});
    $self->{'inference_facts'} = AI::ExpertSystem::Complex::AdvancedDictionary->new;
    $self->{'asked_facts'} = AI::ExpertSystem::Complex::Dictionary->new;
    $self->{'goals_to_check_dict'} = AI::ExpertSystem::Complex::Dictionary->new(
            stack => $self->{'goals_to_check'});
}

1;

