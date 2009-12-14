#
# AI::ExpertSystem::Complex
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 18:28:30 CST 18:28:30
package AI::ExpertSystem::Complex;

=head1 NAME

AI::ExpertSystem::Complex - Expert System system with complex algorithms

=head1 DESCRIPTION

Inspired in L<AI::ExpertSystem::Simple> but with additional features, such as:

=over 4

=item *

Uses backward, forward and mixed algorithms.

=item *

Offers different views, so user can interact with the expert system via a
terminal or with a friendly user interface.

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

=back

=cut
has 'initial_facts' => (
        is => 'rw',
        isa => 'ArrayRef[Str]');

has 'initial_facts_dict' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::Dictionary');

has 'inference_facts' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::AdvancedDictionary');
       
has 'effects' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::Dictionary');

has 'knowledge_db' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::KnowledgeDB::Base',
        required => 1);

has 'asked_facts' => (
        is => 'ro',
        isa => 'AI::ExpertSystem::Complex::Dictionary');

has 'visited_rules' => (
        is => 'ro',
        isa => 'HashRef[Str]');

has 'verbose' => (
        is => 'rw',
        isa => 'Bool',
        default => 0);

has 'viewer' => (
        is => 'rw',
        isa => 'AI::ExpertSystem::Complex::Viewer::Base');

has 'viewer_class' => (
        is => 'rw',
        isa => 'Str',
        default => 'terminal');

has 'found_factor' => (
        is => 'rw',
        isa => 'Float');

has 'shot_rules' => (
        is => 'ro',
        isa => 'HashRef[Str]');

use constant FACT_SIGN_NEGATIVE => '-';
use constant FACT_SIGN_POSITIVE => '+';
use constant FACT_SIGN_UNSURE   => '~';

sub shoot {
    my ($self, $rule, $algorithm) = @_;

    $self->{'shot_rules'}->{$rule} = gettimeofday;

    my $rule_causes = $self->get_causes_by_rule($rule);
    my $rule_effects = $self->get_effects_by_rule($rule);
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
    # Copy the effects of this rule to our "initial facts"
    $self->copy_effects_to_initial_facts($rule_effects, $sign, $algorithm, $rule);
}

sub is_rule_shot {
    my ($self, $rule) = @_;

    return defined $self->{'shot_rules'}->{$rule};
}

sub get_effects_by_rule {
    my ($self, $rule) = @_;
    return $self->{'knowledge_db'}->rule_effects($rule);
}

sub get_causes_by_rule {
    my ($self, $rule) = @_;
    return $self->{'knowledge_db'}->rule_causes($rule);
}

sub is_initial_fact_negative {
    my ($self, $fact) = @_;

    my $sign = $self->{'initial_facts_dict'}->get_sign($fact);
    if (!defined $sign) {
        confess "This fact ($fact) does not exists!";
    }
    return $sign eq FACT_SIGN_NEGATIVE;
}

sub is_asked_fact_negative {
    my ($self, $fact) = @_;

    my $sign = $self->{'asked_facts'}->get_sign($fact);
    if (!defined $sign) {
        confess "This fact ($fact) does not exists!";
    }
    return $sign eq FACT_SIGN_NEGATIVE;
}

sub copy_effects_to_initial_facts {
    my ($self, $effects, $sign, $algorithm, $rule) = @_;

    while(my $effect = $effects->iterate) {
        # we need to add the effect to our "inference/guessed" facts too 
        $self->{'inference_facts'}->add(
                $effect,
                $effect,
                $sign,
                0.0, # the factor
                $algorithm,
                $rule);
        # and now well, add it to initial facts
        $self->{'initial_facts_dict'}->add(
                $effect,
                $effect,
                $sign);
    }
}

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

sub backward {
    my ($self) = @_;

    confess "Can't do backward algorithm with no initial facts" unless
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
            $self->shoot($current_rule, 'backward');
            $current_rule = 1;
            next;
        }
        # nothing here, check the next one..
        $current_rule++
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
            # Get the causes and effects of this rule
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

            my $effects = $self->get_effects_by_rule($shot_rule);
            $effects->populate_iterable_array();
            while(my $effect = $effects->iterate) {
                # We got to this effect by asking the user of it? or by
                # "natural" backward algorithm?
                my ($method, $sign);
                if ($self->{'asked_facts'}->find($effect)) {
                    $method = 'Question';
                    $sign = $self->{'asked_facts'}->get_sign($effect);
                } else {
                    $method = 'Backward';
                    $sign = $effects->get_sign($effect);
                }
                $summary->{'rules'}->{$shot_rule}->{'effects'}->{$effect} = {
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
}

#

1;

