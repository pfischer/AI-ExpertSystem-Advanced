#
# AI::ExpertSystem::Complex::KnowledgeDB::Base
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 19:14:28 PST 19:14:28
package AI::ExpertSystem::Complex::KnowledgeDB::Base;

use Moose;
use AI::ExpertSystem::Complex::Dictionary;

has 'rules' => (
        is => 'ro',
        isa => 'HashRef');

sub read {
    confess "You can't call KnowedgeDB::Base! (abstract method)";
}

sub rule_effects {
    my ($self, $rule) = @_;

    if (!defined $self->{'rules'}->[$rule]) {
        confess "Rule $rule does not exist";
    }
    my @facts;
    # Get all the facts of this effect (usually only one)
    foreach (@{$self->{'rules'}->[$rule]->{'effects'}}) {
        push(@facts, $_);
    }
    my $effects_dict = AI::ExpertSystem::Complex::Dictionary->new(
            stack => \@facts);
    return $effects_dict;
}


sub rule_causes {
    my ($self, $rule) = @_;

    if (!defined $self->{'rules'}->[$rule]) {
        confess "Rule $rule does not exist";
    }
    my @facts;
    # Get all the facts of this cause
    foreach (@{$self->{'rules'}->[$rule]->{'causes'}}) {
        push(@facts, $_->{'fact'});
    }
    my $causes_dict = AI::ExpertSystem::Complex::Dictionary->new(
            stack => \@facts);
    return $causes_dict;
}
1;

