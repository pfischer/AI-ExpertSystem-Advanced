#
# AI::ExpertSystem::Advanced::Dictionary
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 20:06:22 CST 20:06:22
package AI::ExpertSystem::Advanced::Dictionary;

use Moose;

has 'stack' => (
        is => 'rw',
        isa => 'ArrayRef');

has 'stack_hash' => (
        is => 'ro',
        isa => 'HashRef[Str]');

has 'iterable_array' => (
        is => 'ro',
        isa => 'ArrayRef');

sub find {
    my ($self, $look_for, $find_by) = @_;

    if (!defined($find_by)) {
        $find_by = 'name';
    }

    if ($find_by eq 'id') {
        return defined $self->{$look_for};
    }

    foreach my $key (keys %{$self->{'stack_hash'}}) {
        if ($self->{'stack_hash'}->{$key}->{$find_by} eq $look_for) {
            return $key;
        }
    }
    return undef;
}

sub find_by_name {
    my ($self, $name) = @_;

    return $self->find($name, 'name');
}

sub get_sign {
    my ($self, $id) = @_;

    if (!defined $self->{'stack_hash'}->{$id}->{'sign'}) {
        warn "$id does not exist in this dictionary";
        return undef;
    }
    return $self->{'stack_hash'}->{$id}->{'sign'};
}

sub add {
    my ($self, $id, $name, $sign) = @_;
    
    $self->{'stack_hash'}->{$id} = {
        name => $name,
        sign => $sign
    };
    push(@{$self->{'stack'}}, $id);
}

sub remove {
    my ($self, $id) = @_;

    if (my $pos = $self->find($id)) {
        delete(@{$self->{'stack'}}[$id]);
        return 1;
    }
    return 0;
}

sub iterate {
    my ($self) = @_;

    return shift(@{$self->{'iterable_array'}});
}

sub populate_iterable_array {
    my ($self) = @_;

    @{$self->{'iterable_array'}} = keys %{$self->{'stack_hash'}};
}

sub reset_iteration {
    my ($self) = @_;

    $self->{'iteration_position'} = 0;
}

sub BUILD {
    my ($self) = @_;

    foreach (@{$self->{'stack'}}) {
        if (ref($_) eq 'ARRAY') {
            $self->{'stack_hash'}->{$_->[0]} = {
                name => $_->[0],
                sign => $_->[1]
            };
        } else {
            $self->{'stack_hash'}->{$_} = {
                name => $_,
                sign => '+'
            };
        }
    }
    $self->populate_iterable_array();
}

1;
