#
# AI::ExpertSystem::Advanced::KnowledgeDB::Base
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 19:14:28 PST 19:14:28
package AI::ExpertSystem::Advanced::KnowledgeDB::Base;

use Moose;
use AI::ExpertSystem::Advanced::Dictionary;

has 'rules' => (
        is => 'ro',
        isa => 'HashRef');

sub read {
    confess "You can't call KnowedgeDB::Base! (abstract method)";
}

sub rule_goals {
    my ($self, $rule) = @_;

    if (!defined $self->{'rules'}->[$rule]) {
        confess "Rule $rule does not exist";
    }
    my @facts;
    # Get all the facts of this goal (usually only one)
    foreach (@{$self->{'rules'}->[$rule]->{'goals'}}) {
        push(@facts, $_);
    }
    my $goals_dict = AI::ExpertSystem::Advanced::Dictionary->new(
            stack => \@facts);
    return $goals_dict;
}


sub rule_causes {
    my ($self, $rule) = @_;

    if (!defined $self->{'rules'}->[$rule]) {
        confess "Rule $rule does not exist";
    }
    my @facts;
    # Get all the facts of this cause
    foreach (@{$self->{'rules'}->[$rule]->{'causes'}}) {
        push(@facts, $_->{'name'});
    }
    my $causes_dict = AI::ExpertSystem::Advanced::Dictionary->new(
            stack => \@facts);
    return $causes_dict;
}
1;

