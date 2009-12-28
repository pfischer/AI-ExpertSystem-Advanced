#
# AI::ExpertSystem::Advanced::AdvancedDictionary
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 20:06:22 CST 20:06:22
package AI::ExpertSystem::Advanced::AdvancedDictionary;

use Moose;
extends 'AI::ExpertSystem::Advanced::Dictionary';

sub add {
    my ($self, $id, $name, $sign, $factor, $algorithm, $rule) = @_;

    $self->{'stack_hash'}->{$id} = {
        name => $name,
        sign => $sign,
        factor => $factor,
        algorithm => $algorithm,
        rule => $rule
    };
    push(@{$self->{'stack'}}, $id);
}

1;
