#
# AI::ExpertSystem::Advanced::Viewer::Factory
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/29/2009 19:12:25 PST 19:12:25
package AI::ExpertSystem::Advanced::Viewer::Factory;

use strict;
use warnings;
use Class::Factory;
use base qw(Class::Factory);

sub new {
    my ($pkg, $type, @params) = @_;
    my $class = $pkg->get_factory_class($type);
    return undef unless ($class);
    my $self = "$class"->new(@params);
    return $self;
}

__PACKAGE__->register_factory_type(terminal =>
        'AI::ExpertSystem::Advanced::Viewer::Terminal');

1;

